/**
 * Desktop-only AI browser: a host-owned Chromium the Agent drives directly.
 *
 * The shipped Desktop composition mounts no browser row, so the Agent browses
 * the right-Sidebar pane a person can watch instead. This module remains for a
 * deployment that needs a browser no person watches.
 */

import { existsSync } from 'node:fs'
import { join } from 'node:path'
import type { Context } from '@nero/cordis'
import BrowserUse from '@nero/nero-browser-use'
import * as playwrightMcp from '@nero/nero-experimental-browser-use-playwright-mcp'

/** Loader identity for the application-owned AI browser composition. */
export const name = 'desktop-browser'

/** Application-selected browser executable and window visibility. */
export interface Config {
  /** Chromium-based executable to drive; a resolved installation is used when omitted. */
  readonly executablePath?: string
  /** Whether the browser runs without a visible window. */
  readonly headless?: boolean
}

/** Installed Chromium-based executables by platform, most likely first. */
const CHROMIUM_EXECUTABLES: Readonly<Record<string, readonly string[]>> = {
  win32: [
    join(process.env['ProgramFiles'] ?? 'C:\\Program Files', 'Google/Chrome/Application/chrome.exe'),
    join(process.env['ProgramFiles(x86)'] ?? 'C:\\Program Files (x86)', 'Google/Chrome/Application/chrome.exe'),
    join(process.env['LocalAppData'] ?? 'C:\\Users\\Default\\AppData\\Local', 'Google/Chrome/Application/chrome.exe'),
    join(process.env['ProgramFiles(x86)'] ?? 'C:\\Program Files (x86)', 'Microsoft/Edge/Application/msedge.exe'),
  ],
  darwin: [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  ],
  linux: [
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ],
}

/**
 * Locate a Chromium-based executable the pinned MCP server can drive.
 * @returns the first installed executable, or undefined so the MCP server
 * resolves the browser it manages itself.
 */
export function installedChromium(): string | undefined {
  for (const candidate of CHROMIUM_EXECUTABLES[process.platform] ?? []) {
    if (existsSync(candidate)) return candidate
  }
  return undefined
}

/**
 * Give each live Session a host-owned browser the Agent operates directly.
 *
 * The Desktop process owns this Chromium, so browsing, screenshots, and page
 * reads never depend on a connected Client, a Sidebar Browser pane, or the tab
 * a person happens to have open. Mount before any Session is created or
 * resumed: the provider does not adopt Sessions that are already active.
 *
 * A composition that already mounted browser use owns that choice, so this
 * application default never contests a profile's own browser provider.
 * @param ctx - Profile scope; the provider declares its own service requirements.
 * @param config - executable override and window visibility.
 */
export async function apply(ctx: Context, config: Config = {}): Promise<void> {
  // Read through reflect: an unprovided service is undefined here, while a
  // property read outside `inject` would throw before this decision is made.
  if (ctx.reflect.get('browserUse') !== undefined) return
  const executablePath = config.executablePath ?? installedChromium()
  await ctx.plugin(BrowserUse)
  await ctx.plugin(playwrightMcp, {
    mode: 'launch',
    headless: config.headless ?? true,
    ...executablePath === undefined ? {} : { executablePath },
  })
}
