/** Desktop AI browser ownership in the shipped Desktop composition. */

import { existsSync } from 'node:fs'
import { Context } from '@nero/cordis'
import AgentRegistry from '@nero/nero-agent'
import AgentLoop from '@nero/nero-agent-loop'
import BrowserUse from '@nero/nero-browser-use'
import Llm from '@nero/nero-llm'
import Projections from '@nero/nero-session-projection'
import Sessions from '@nero/nero-session'
import SystemPrompt from '@nero/nero-system-prompt'
import ToolRuntime from '@nero/nero-tools'
import { expect, it } from 'vitest'
import * as desktopBrowser from '../src/browser.ts'

it('never reports a Chromium executable that is not installed', () => {
  const executable = desktopBrowser.installedChromium()
  if (executable !== undefined) expect(existsSync(executable)).toBe(true)
})

/** Load the services the browser provider declares it needs. */
async function sessionServices(ctx: Context): Promise<void> {
  await ctx.plugin(SystemPrompt)
  await ctx.plugin(ToolRuntime)
  await ctx.plugin(Llm)
  await ctx.plugin(Sessions)
  await ctx.plugin(AgentRegistry)
  await ctx.plugin(AgentLoop, { agents: [] })
  await ctx.plugin(Projections)
}

it('mounts a host-owned browser when the composition mounted none', async () => {
  const ctx = new Context()
  try {
    await sessionServices(ctx)
    expect(ctx.browserUse).toBeUndefined()
    await ctx.plugin(desktopBrowser, {})
    // The provider claims the single browser slot, so an Agent reaches a real
    // browser the Desktop process owns rather than a pane in a connected Client.
    expect(ctx.browserUse.providerName).toBe('playwright-mcp')
  } finally {
    await ctx.fiber.dispose()
  }
})

it('leaves a browser chosen by the composition alone', async () => {
  const ctx = new Context()
  try {
    await sessionServices(ctx)
    await ctx.plugin(BrowserUse)
    await ctx.plugin(desktopBrowser, {})
    expect(ctx.browserUse.providerName).toBeUndefined()
  } finally {
    await ctx.fiber.dispose()
  }
})
