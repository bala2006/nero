import { mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'
import { afterEach, describe, expect, it } from 'vitest'
import { Context } from '@nero/cordis'
import Loader from '@nero/cordis-plugin-loader'
import Include from '@nero/cordis-plugin-include'
import { ToolCallId } from '@nero/nero-llm'
import { Session, SessionId } from '@nero/nero-session'
import AgentRegistry from '@nero/nero-agent'
import type { Agent } from '@nero/nero-agent'
import SystemPrompt from '@nero/nero-system-prompt'
import ToolRuntime from '@nero/nero-tools'
import TerminalSessionService from '@nero/nero-terminal'
import SandboxProvider from '@nero/nero-sandbox'
import type { ConfinedArgv, SandboxPolicy } from '@nero/nero-sandbox'
import SandboxPolicyService from '@nero/nero-sandbox-policy'
import SessionProjectionRegistry from '@nero/nero-session-projection'
import LocalSubprocessRuntime from '@nero/nero-subprocess-local'
import * as TerminalLocal from '@nero/nero-terminal-bash'
import * as ToolPty from '@nero/nero-tool-terminal'
import { unsupportedInbox } from '@nero/nero-agent-loop-testkit'

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

async function agent(ctx: Context): Promise<Agent> {
  const scope = ctx.plugin(() => {})
  const id = SessionId('pty-loader-agent')
  const session = Session.create(id)
  const value: Agent = {
    id, options: {}, session, inbox: unsupportedInbox(),
    status: 'idle',
    ctx: scope.ctx,
    send: () => {},
    followup: () => {}, steer: () => {}, inject: () => {}, cancel() {},
    runMaintenance: job => job(new AbortController().signal),
    whenIdle: () => Promise.resolve(),
  }
  await ctx.agents.register(value)
  return value
}

function resultText(result: { content: { type: string; text?: string }[] }): string {
  return result.content.filter(block => block.type === 'text').map(block => block.text).join('')
}

const suite = process.platform === 'linux' || process.platform === 'darwin' ? describe : describe.skip

suite('terminal real Loader composition through cordis.yml', () => {
  it('boots cordis.yml and preserves shell state across real tool calls', async () => {
    root = await mkdtemp(join(tmpdir(), 'nero-pty-loader-'))
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
      '    pollIntervalMs: 10',
      '    exactProbeAfterMs: 20',
      '    idleSilenceMs: 250',
      '    handoffGraceMs: 250',
      '    timeoutMs: 2000',
      '    disposeGraceMs: 500',
      "- name: '@nero/nero-tool-terminal'",
      '',
    ].join('\n'))

    context = new Context()
    context.baseUrl = pathToFileURL(root).href + '/'
    await context.plugin(Loader)
    context.loader.builtins.include = Include
    const modules = new Map<string, unknown>([
      ['@nero/nero-agent', AgentRegistry],
      ['@nero/nero-system-prompt', SystemPrompt],
      ['@nero/nero-tools', ToolRuntime],
      ['@nero/nero-terminal', TerminalSessionService],
      ['@nero/nero-test-sandbox', PassthroughSandbox],
      ['@nero/nero-session-projection', SessionProjectionRegistry],
      ['@nero/nero-sandbox-policy', SandboxPolicyService],
      ['@nero/nero-subprocess-local', LocalSubprocessRuntime],
      ['@nero/nero-terminal-bash', TerminalLocal],
      ['@nero/nero-tool-terminal', ToolPty],
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

    const owner = await agent(context)
    const signal = new AbortController().signal
    const spawn = await context.tools.execute({
      signal, callId: ToolCallId('spawn'), name: 'terminal_open', arguments: { type: 'shell', name: 'main', cwd: root }, agent: owner,
    })
    expect(resultText(spawn)).toContain('started terminal session pty-1 (main)')

    await context.tools.execute({
      signal, callId: ToolCallId('state'), name: 'terminal_send', arguments: { sessionId: 'pty-1', text: 'export KEEP=loader; cd /' }, agent: owner,
    })
    const read = await context.tools.execute({
      signal, callId: ToolCallId('read'), name: 'terminal_send', arguments: { sessionId: 'pty-1', text: 'printf "cwd=%s keep=%s\\n" "$PWD" "$KEEP"' }, agent: owner,
    })
    expect(resultText(read)).toContain('cwd=/ keep=loader')
    expect(context.terminals.list(owner)).toHaveLength(1)
  }, 15_000)
})
