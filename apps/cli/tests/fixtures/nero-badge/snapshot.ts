import { fileURLToPath } from 'node:url'
import { agentEvents, type Agent } from '@nero/nero-agent'
import { ToolCallId } from '@nero/nero-llm'
import { boot, loadOverlayPatches } from '@nero/nero-app-boot'
import { SessionId } from '@nero/nero-session'
import type {} from '@nero/nero-skill'
import type {} from '@nero/nero-tools'
import { unsupportedInbox } from '@nero/nero-agent-loop-testkit'

const overlayPath = process.argv[2]
if (overlayPath === undefined) throw new Error('nero-badge snapshot requires an overlay path')
const rootConfigPath = fileURLToPath(new URL('../../../../../packages/bundle/base/tests/fixtures/root.cordis.yml', import.meta.url))
const basePatchPath = fileURLToPath(new URL('../../../../../packages/bundle/base/cordis.patch.yml', import.meta.url))
const ctx = await boot('nero-badge-snapshot', rootConfigPath, [
  ...loadOverlayPatches('nero-badge-snapshot', basePatchPath),
  ...loadOverlayPatches('nero-badge-snapshot', overlayPath),
])

try {
  const agentId = SessionId('nero-badge-snapshot')
  const session = ctx.sessions.create(agentId, { meta: { cwd: process.cwd() } })
  const agent: Agent = {
    ctx,
    id: agentId,
    options: {},
    session,
    inbox: unsupportedInbox(),
    status: 'idle',
    send: () => {},
    followup: () => {},
    steer: () => {},
    inject: () => { throw new Error('nero-badge snapshot must receive the catalog at the step boundary') },
    cancel: () => {},
    runMaintenance: job => job(new AbortController().signal),
    whenIdle: () => Promise.resolve(),
  }
  const decision = await agentEvents(ctx, agent).waterfall(
    'agent/pre-step',
    { messages: [], turn: 1, step: 1, signal: new AbortController().signal },
    () => Promise.resolve({ kind: 'enter' as const, messages: [] }),
  )
  const catalog = decision.kind === 'enter'
    ? decision.messages.find(message => message.role === 'user'
      && message.source.kind === 'skill-catalog')?.content
    : undefined
  const summary = (await ctx.skills.list()).find(skill => skill.name === 'nero-badge')
  const result = await ctx.tools.execute({
    callId: ToolCallId('nero-badge-snapshot'),
    name: 'skill',
    arguments: { name: 'nero-badge' },
    signal: new AbortController().signal,
  })
  process.stdout.write(`${JSON.stringify({ catalog: catalog ?? null, summary: summary ?? null, result })}\n`)
} finally {
  await ctx.fiber.dispose()
}
