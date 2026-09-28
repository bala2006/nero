// Keyless assembled-browser coverage for the opt-in Agent Teams bundle
// over the real Host Typert Remote flow.
import { fileURLToPath } from 'node:url'
import { join } from 'node:path'
import { readFileSync } from 'node:fs'
import type { Browser, Page } from 'playwright'
import { chromium } from 'playwright'
import { afterAll, beforeAll, describe, expect, it, onTestFailed } from 'vitest'
import * as yaml from 'js-yaml'
import { entryListSchema } from '@nero/cordis-plugin-include'
import type {} from '@nero/nero-experimental-agent-team'
import { createMessage, createUserMessage } from '@nero/nero-llm'
import {
  assertFixtureInventory, captureStableAria, compareOrRefreshGolden,
  launchWebScaffold, watchConsole, webSnapshotMode, type WebScaffold,
} from './scaffold.ts'
import { connectFreshWorkspace, newEnglishPage, saveFailureShot } from './support.ts'

const SNAPSHOT_DIR = fileURLToPath(new URL('./snapshots/agent-team-panel', import.meta.url))
const PANEL_EXPECTED = join(SNAPSHOT_DIR, 'task.expected.md')
const OVERLAY = fileURLToPath(new URL('./agent-team-panel.overlay.yml', import.meta.url))
const TEAM_PATCH = fileURLToPath(new URL('../../../packages/experimental/agent-team-profile/cordis.patch.yml', import.meta.url))
const INSTALL_ANCHORS = [
  fileURLToPath(new URL('../../../packages/experimental/agent-team-profile/package.json', import.meta.url)),
]
const MODE = webSnapshotMode()

function profileEntries(path: string): unknown[] {
  const parsed = yaml.load(readFileSync(path, 'utf8'), { schema: entryListSchema })
  if (!Array.isArray(parsed)) throw new Error(`profile layer at ${path} must be a list`)
  return parsed
}

describe('Agent Teams panel overlay', () => {
  it('matches the shipped Agent Teams bundle', () => {
    expect(profileEntries(OVERLAY)).toEqual(profileEntries(TEAM_PATCH))
  })
})

describe('web e2e: Agent Teams panel', () => {
  let scaffold: WebScaffold
  let browser: Browser
  let page: Page
  let tripwire: ReturnType<typeof watchConsole>

  beforeAll(async () => {
    scaffold = await launchWebScaffold({ extraOverlayPath: OVERLAY, extraInstallAnchors: INSTALL_ANCHORS })
    browser = await chromium.launch()
    page = await newEnglishPage(browser)
    tripwire = watchConsole(page)
    await page.goto(scaffold.authenticatedUrl, { waitUntil: 'load' })
    await page.waitForSelector('[class*="frame"]', { timeout: 30_000 })
    await connectFreshWorkspace(page, scaffold.workspaceCwd)
    const agent = scaffold.ctx.agents.list()[0]
    if (agent === undefined) throw new Error('connected Team workspace did not create an Agent')
    agent.session.append('turn/start', { turn: 1 })
    agent.session.append('user/message', createUserMessage({
      content: [{ type: 'text', text: 'Open the Agent Team controls.' }],
      source: { kind: 'user' },
    }), { surfaceOp: 'append' })
    agent.session.append('step/start', { turn: 1, step: 1 })
    agent.session.append('assistant/message', {
      stream: [],
      turn: 1,
      step: 1,
      message: createMessage({
        role: 'assistant',
        content: [{ type: 'text', text: 'Ready.' }],
        source: { kind: 'model', provider: 'fixture', model: 'fixture' },
      }),
    }, { surfaceOp: 'append' })
    agent.session.append('step/end', { turn: 1, step: 1 })
    agent.session.append('turn/end', { turn: 1, reason: { kind: 'completed' } })
    await scaffold.ctx.sessions.flush(agent.session)
    await page.getByText('Ready.').waitFor({ timeout: 10_000 })
  }, 120_000)

  afterAll(async () => {
    await browser?.close()
    await scaffold?.close()
  })

  it('opens the Agent Canvas from one transcript box and reads the roster', async () => {
    onTestFailed(() => saveFailureShot(page, 'web-e2e-agent-team-panel'))
    const box = page.locator('[data-agent-swarm]').getByRole('button')
    await box.click()
    const canvas = page.locator('[data-team-panel]')
    await canvas.waitFor()
    await canvas.locator('[data-agent-node="lead"]').waitFor()
    await canvas.getByRole('button', { name: 'Refresh Team' }).waitFor()
    expect(await canvas.locator('[data-agent-node]').count()).toBe(1)

    const snapshot = await captureStableAria(page, '[data-team-panel]', scaffold.workspaceCwd)
    await compareOrRefreshGolden(PANEL_EXPECTED, snapshot, MODE)
    expect(tripwire.pageErrors).toEqual([])
    expect(tripwire.warnings).toEqual([])
  }, 60_000)

  it('pans the canvas and opens one node mini chat', async () => {
    onTestFailed(() => saveFailureShot(page, 'web-e2e-agent-team-panel-keyboard'))
    const canvas = page.locator('[data-team-panel]')
    await canvas.locator('[data-agent-node="lead"]').waitFor()
    const ground = canvas.locator('[data-agent-canvas]')
    const box = await ground.boundingBox()
    if (box === null) throw new Error('Agent Canvas has no box')
    const graph = ground.locator('[class*="graph"]')
    const before = await graph.evaluate(element => getComputedStyle(element).transform)
    await page.mouse.move(box.x + 40, box.y + box.height - 20)
    await page.mouse.down()
    await page.mouse.move(box.x + 120, box.y + box.height - 60, { steps: 5 })
    await page.mouse.up()
    await expect.poll(() => graph.evaluate(element => getComputedStyle(element).transform)).not.toBe(before)
    await ground.dblclick({ position: { x: 40, y: box.height - 20 } })
    await expect.poll(() => graph.evaluate(element => getComputedStyle(element).transform)).toBe(before)

    await canvas.locator('[data-agent-node="lead"]').click()
    const mini = canvas.locator('[data-agent-mini-chat="lead"]')
    await mini.waitFor()
    expect(await mini.getByRole('tab').allTextContents()).toEqual(['Edit Agent', 'Chat', 'Trajectory'])
    await mini.getByLabel('Chat ID').waitFor()
    await mini.getByRole('tab', { name: 'Chat' }).click()
    // The mini chat sends through the embedded conversation's own composer.
    await mini.getByPlaceholder('Message or run a task, / commands, @ files or sessions').waitFor()
    await mini.getByRole('button', { name: 'Close' }).click()
    await mini.waitFor({ state: 'detached' })
  })

  it.skipIf(MODE === 'record')('keeps the fixture inventory closed', async () => {
    await assertFixtureInventory(SNAPSHOT_DIR, ['task.expected.md'])
  })
})
