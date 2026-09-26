import { Context } from '@nero/cordis'
import type { Agent } from '@nero/nero-agent'
import AgentLoop from '@nero/nero-agent-loop'
import { mountAgentLoopTestDependencies } from '@nero/nero-agent-loop-testkit'
import LocalFileSystem from '@nero/nero-fs-local'
import * as FsPolicy from '@nero/nero-fs-observation-policy'
import * as ToolFs from '@nero/nero-tool-fs'
import * as LlmNero from '@nero/nero-llm-nero'

/**
 * Build the real fs-tool stack for with-key e2e tests. Agents have no session
 * cwd, so `fsCwd` is their workspace; `persona` configures the deployment prompt.
 * This helper lives outside the e2e glob so imports do not register tests.
 */
export async function fsHarness(fsCwd: string, persona = ''): Promise<Context> {
  const ctx = new Context()
  await mountAgentLoopTestDependencies(ctx, { systemPrompt: { personaPrefix: persona } })
  await ctx.plugin(AgentLoop, { agents: [] })
  await ctx.plugin(LlmNero)
  await ctx.plugin(LocalFileSystem, { cwd: fsCwd })
  await ctx.plugin(FsPolicy)
  await ctx.plugin(ToolFs)
  return ctx
}

export function waitForIdle(ctx: Context, agent: Agent): Promise<void> {
  return new Promise((resolve) => {
    const dispose = ctx.on('agent/status', ({ agent: subject, status }) => {
      if (subject === agent && status === 'idle') {
        dispose()
        resolve()
      }
    })
  })
}
