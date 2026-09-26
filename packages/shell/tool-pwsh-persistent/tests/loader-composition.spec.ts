import { spawnSync } from 'node:child_process'
import { mkdtemp, realpath, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { Context } from '@nero/cordis'
import Loader from '@nero/cordis-plugin-loader'
import Include from '@nero/cordis-plugin-include'
import { ToolCallId } from '@nero/nero-llm'
import { SESSION_FORMAT_VERSION, Session, SessionId } from '@nero/nero-session'
import AgentRegistry from '@nero/nero-agent'
import SessionProjectionRegistry from '@nero/nero-session-projection'
import type { Agent } from '@nero/nero-agent'
import TerminalSessionService from '@nero/nero-terminal'
import type { TerminalWaitReason } from '@nero/nero-terminal'
import * as TerminalBash from '@nero/nero-terminal-bash'
import SandboxProvider from '@nero/nero-sandbox'
import type { ConfinedArgv, SandboxPolicy } from '@nero/nero-sandbox'
import SandboxPolicyService from '@nero/nero-sandbox-policy'
import LocalSubprocessService from '@nero/nero-subprocess-local'
import { resolvePwshPath } from '@nero/nero-pwsh-local/src/resolve.ts'
import SystemPrompt from '@nero/nero-system-prompt'
import ToolRegistry from '@nero/nero-tools'
import * as ToolPwshPersistent from '@nero/nero-tool-pwsh-persistent'
import { unsupportedInbox } from '@nero/nero-agent-loop-testkit'

const hasPwsh = spawnSync(
  resolvePwshPath(), ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', '$true'],
  { encoding: 'utf8' },
).status === 0

let root: string | undefined
let context: Context | undefined

afterEach(async () => {
  await context?.fiber.dispose()
  context = undefined
  if (root !== undefined) await rm(root, { recursive: true, force: true })
  root = undefined
})

class PassthroughSandbox extends SandboxProvider {
  async confine(argv: readonly string[], _policy: SandboxPolicy): Promise<ConfinedArgv> {
    return { argv: [...argv], enforcement: 'full', denialSignatures: [], runnerFailureRules: [] }
  }
}

async function agent(ctx: Context, cwd: string): Promise<Agent> {
  const id = SessionId('persistent-pwsh-loader-agent')
  const scope = ctx.plugin(() => {})
  const session = Session.create(id, [], {
    version: SESSION_FORMAT_VERSION, id, createdAt: 0, cwd, isSeeded: false,
  })
  const value: Agent = {
    id,
    options: {},
    session,
    inbox: unsupportedInbox(),
    status: 'idle',
    ctx: scope.ctx,
    send: () => {},
    followup: () => {},
    steer: () => ({ outcome: Promise.resolve({ status: 'rejected' as const }) }),
    inject: () => {},
    cancel() {},
    runMaintenance: task => task(new AbortController().signal),
    whenIdle: () => Promise.resolve(),
  }
  await ctx.agents.register(value)
  return value
}

function text(result: { content: { type: string; text?: string }[] }): string {
  return result.content.filter(block => block.type === 'text').map(block => block.text).join('')
}

describe.skipIf(!hasPwsh)('persistent pwsh through a real cordis.yml Loader composition', () => {
  it('preserves cwd and environment across calls', async () => {
    root = await realpath(await mkdtemp(join(tmpdir(), 'nero-persistent-pwsh-loader-')))
    const configPath = join(root, 'cordis.yml')
    await writeFile(configPath, [
      "- name: '@nero/nero-agent'",
      "- name: '@nero/nero-system-prompt'",
      "- name: '@nero/nero-tools'",
      "- name: '@nero/nero-terminal'",
      "- name: '@nero/nero-test-sandbox'",
      "- name: '@nero/nero-session-projection'",
      "- name: '@nero/nero-sandbox-policy'",
      '  config:',
      '    mode: danger-full-access',
      `    workspaceRoot: ${JSON.stringify(root)}`,
      "- name: '@nero/nero-subprocess-local'",
      "- name: '@nero/nero-terminal-bash'",
      '  config:',
      '    shellDialect: pwsh',
      '    pollIntervalMs: 10',
      '    exactProbeAfterMs: 20',
      // The silence tier keeps its product default; the case body records each
      // send's wait reason, which pins the controlled-prompt fast path directly
      // instead of relying on how long silence would take to settle.
      '    handoffGraceMs: 300',
      '    scrollbackLines: 20000',
      // The first call pays the full pwsh cold-start latency (spawn + .NET +
      // PSReadLine + Defender) inside the tool deadline; a 60s bound on the
      // fully loaded self-hosted Windows pool is exceeded often enough to
      // reset the session mid-test (2026-09-01, two runs ~62s each). 300s
      // matches the nero-tool-pwsh-persistent product default; the
      // nero-terminal-bash value bounds one send plus the complete startup
      // sequence, so it covers the same cold start (its 30s product default
      // would not).
      '    timeoutMs: 300000',
      '    disposeGraceMs: 500',
      "- name: '@nero/nero-tool-pwsh-persistent'",
      '  config:',
      '    timeoutMs: 300000',
      '',
    ].join('\n'))

    context = new Context()
    context.baseUrl = pathToFileURL(root).href + '/'
    await context.plugin(Loader)
    context.loader.builtins.include = Include
    const modules = new Map<string, unknown>([
      ['@nero/nero-agent', AgentRegistry],
      ['@nero/nero-system-prompt', SystemPrompt],
      ['@nero/nero-tools', ToolRegistry],
      ['@nero/nero-terminal', TerminalSessionService],
      ['@nero/nero-test-sandbox', PassthroughSandbox],
      ['@nero/nero-session-projection', SessionProjectionRegistry],
      ['@nero/nero-sandbox-policy', SandboxPolicyService],
      ['@nero/nero-subprocess-local', LocalSubprocessService],
      ['@nero/nero-terminal-bash', TerminalBash],
      ['@nero/nero-tool-pwsh-persistent', ToolPwshPersistent],
    ])
    context.loader.internal = {
      version: 'v2',
      async import(specifier: string) {
        if (!modules.has(specifier)) throw new Error(`unexpected Loader import: ${specifier}`)
        return modules.get(specifier)
      },
    } as unknown as NonNullable<typeof context.loader.internal>
    await context.loader.create({ name: 'cordis:include', config: { path: pathToFileURL(configPath).href } })
    await context.loader.await()

    const terminals = context.terminals
    const startSend = terminals.startSend.bind(terminals)
    // A send that lost the controlled-prompt fast path settles as inferred_idle
    // after the silence tier, so recording why every send settled detects that
    // regression immediately instead of through accumulated wall-clock.
    const settleReasons: TerminalWaitReason[] = []
    vi.spyOn(terminals, 'startSend').mockImplementation((owner, id, request) => {
      const operation = startSend(owner, id, request)
      void operation.done.then(
        (settled) => { settleReasons.push(settled.waitReason) },
        // A rejected send is the tool's error path, not a settle reason.
        () => {},
      )
      return operation
    })

    const owner = await agent(context, root)
    const signal = new AbortController().signal
    const execute = (id: string, command: string) => context!.tools.execute({
      signal,
      callId: ToolCallId(id),
      name: 'pwsh',
      arguments: { command },
      agent: owner,
    })

    expect(context.tools.schemas().map(schema => schema.name)).toEqual(['pwsh'])
    await execute('state', '$env:KEEP = "loader"; New-Item -ItemType Directory -Force -Path nested | Out-Null; Set-Location nested')
    const observed = text(await execute('observe', 'Write-Output "cwd=$PWD keep=$env:KEEP"'))
    expect(observed).toContain(`cwd=${join(root, 'nested')} keep=loader`)
    expect(observed).not.toContain('NERO_PERSISTENT_PWSH')

    const multiline = text(await execute(
      'multiline',
      '$value = "line one"\nWrite-Output "${value}:it\'s fine"',
    ))
    expect(multiline).toBe("line one:it's fine")
    expect(multiline).not.toContain('NERO_PERSISTENT_PWSH')

    const hereString = text(await execute(
      'here-string',
      "$h = @'\nalpha\nbeta\n'@\nWrite-Output $h",
    ))
    expect(hereString).toBe('alpha\nbeta')

    const large = text(await execute('large-output', '1..12050 | ForEach-Object { $_ }'))
    expect(large.startsWith('1\n2\n3\n')).toBe(true)
    expect(large).toContain('<response clipped>')
    expect(large).not.toContain('beginning of this command output was dropped')

    const exited = text(await execute('exit', 'exit'))
    expect(exited).toContain('next pwsh call starts from the workspace')
    expect(text(await execute('after-exit', 'Write-Output "$PWD"'))).toBe(root)

    // Six commands settle on the controlled prompt; no send may fall back to the
    // silence tier, which is the 3.5 s-per-call degradation this suite pins.
    expect(settleReasons.filter(reason => reason === 'stdin_read').length).toBeGreaterThanOrEqual(6)
    expect(settleReasons).not.toContain('inferred_idle')
  }, 120_000)
})
