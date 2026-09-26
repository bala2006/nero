import { expect, it } from 'vitest'
import { AttachmentId, AttachmentError, AttachmentStore } from '@nero/nero-attachment'
import type { ImageAttachmentLimits, ImageAttachmentRef, SaveImageAttachment } from '@nero/nero-attachment'
import { Context } from '@nero/cordis'
import SystemPrompt from '@nero/nero-system-prompt'
import { createScope } from '@nero/nero-scope'
import ToolRuntime from '@nero/nero-tools'
import * as plugin from '../src/index.ts'
import type { SidebarBrowserResult } from '../src/control.ts'

/** Loads the hosting plugin on a real tool runtime, as the Web bundle does. */
async function setup(): Promise<Context> {
  const ctx = new Context()
  // The registry injects the prompt service, which the composition root loads
  // beside it; this package only publishes tools.
  await ctx.plugin(SystemPrompt)
  await ctx.plugin(ToolRuntime)
  // Applied directly, as a composition root does: `ctx.plugin` would nest the
  // scope this package publishes its service on.
  plugin.apply(ctx)
  return ctx
}

/** The image policy one deployment advertises; only the media-type list is read here. */
const LIMITS: ImageAttachmentLimits = {
  maxImageBytes: 1024 * 1024, maxImagesPerMessage: 8, maxMessageImageBytes: 4 * 1024 * 1024,
  maxImagePixels: 16_777_216, maxImageDimension: 8192, mediaTypes: ['image/png', 'image/jpeg', 'image/webp'],
}

/** A durable image store that records what it committed, or refuses to commit anything. */
class RecordingImages extends AttachmentStore {
  readonly imageLimits = LIMITS
  readonly saves: SaveImageAttachment[] = []

  constructor(ctx: Context, private readonly refusal?: string) {
    super(ctx)
  }

  async validateImage(): Promise<void> {}

  async saveImage(input: SaveImageAttachment): Promise<ImageAttachmentRef> {
    if (this.refusal !== undefined) throw new AttachmentError(this.refusal, 'ATTACHMENT_WRITE_FAILED')
    this.saves.push(input)
    return {
      attachmentId: AttachmentId('capture-1'), mediaType: input.mediaType,
      bytes: input.data.byteLength, width: 800, height: 600,
    }
  }

  readImage(): Promise<never> {
    return Promise.reject(new Error('the Browser tools never read images back'))
  }
}

it('publishes the Browser control service beside the tool registry', async () => {
  const ctx = await setup()
  expect(ctx.sidebarBrowser).toBeInstanceOf(plugin.SidebarBrowserService)
  expect(plugin.name).toBe('ui-sidebar-browser')
})

it('refuses a request that carries no calling agent', async () => {
  const ctx = await setup()
  await expect(ctx.sidebarBrowser.request({ command: { kind: 'list' }, agent: undefined }))
    .rejects.toThrow('requires the calling agent')
})

it('keeps the host entry inert without a tool registry', () => {
  const ctx = new Context()
  expect(() => { plugin.apply(ctx) }).not.toThrow()
  expect(ctx.sidebarBrowser).toBeInstanceOf(plugin.SidebarBrowserService)
})

/** The seven fields every reported tab carries, as a client projects them. */
const TAB = {
  tabId: 'tab1', sessionId: 'session-1', url: 'http://127.0.0.1:8000/', title: 'KYOTO — OPEN CITY',
  loading: false, canGoBack: false, canGoForward: false,
}

/**
 * Answer the Browser waterfall on `agent`'s scope with one canned result, then
 * run `browser_tab` through the real registry: the value a client returns must
 * survive the registered output contract, or the tool reports an output error
 * instead of the page it observed.
 * @param result - the result an answering client would return.
 * @param images - an image store to mount on the host when one is needed.
 * @returns the executed tool call as the client records it.
 */
async function runBrowserTool(result: SidebarBrowserResult, images?: RecordingImages) {
  const ctx = await setup()
  if (images !== undefined) ctx.effect(() => ctx.reflect.provide('attachments', images))
  const agent = { id: 'agent-1', ctx: ctx.extend() }
  const scope = createScope(ctx, agent)
  scope.ctx.on('sidebar-browser/request', () => Promise.resolve(result))
  const executed = await ctx.tools.execute({
    signal: new AbortController().signal,
    callId: 'call-1' as never,
    name: 'browser_tab',
    arguments: { command: 'screenshot' },
    agent: agent as never,
  })
  return executed
}

/** One capture answer, as a client that owns a capturable pane returns it. */
const CAPTURED: SidebarBrowserResult = {
  ok: true,
  tabs: [TAB],
  tab: TAB,
  capabilities: { snapshot: true, evaluate: true, screenshot: true, console: true },
  image: { mimeType: 'image/png', dataBase64: 'AAAA' },
  console: [{ level: 'log', message: 'ready', sourceId: 'app.js', line: 12 }],
}

/** The text blocks of one executed call, in order. */
function textOf(content: readonly { type: string; text?: string }[]): string {
  return content.filter(block => block.type === 'text').map(block => block.text ?? '').join('')
}

it('accepts console records and reports a capture no store accepted', async () => {
  const executed = await runBrowserTool(CAPTURED)
  expect(executed.isError).toBe(false)
  const text = textOf(executed.content)
  expect(text).toContain('which this deployment could not store for you to see')
  expect(text).toContain('console (1 records)')
  expect(text).toContain('log: ready (app.js:12)')
  expect(executed.content.some(block => block.type === 'image')).toBe(false)
})

it('commits a capture so the model receives the page as an image', async () => {
  const images = new RecordingImages(new Context())
  const executed = await runBrowserTool(CAPTURED, images)
  expect(executed.isError).toBe(false)
  expect(images.saves[0]).toMatchObject({ mediaType: 'image/png', name: 'browser-pane.png' })
  expect([...images.saves[0]!.data]).toEqual([0, 0, 0])
  expect(textOf(executed.content)).toContain('attached below for you to look at')
  expect(executed.content.find(block => block.type === 'image')).toMatchObject({
    attachment: { attachmentId: 'capture-1', mediaType: 'image/png', width: 800, height: 600 },
  })
})

it('reports a capture the store refused instead of claiming a page the model cannot see', async () => {
  const images = new RecordingImages(new Context(), 'storage is full')
  const executed = await runBrowserTool(CAPTURED, images)
  expect(executed.isError).toBe(false)
  const text = textOf(executed.content)
  expect(text).toContain('FAILED: the captured page was not stored for you to see: storage is full')
  expect(executed.content.some(block => block.type === 'image')).toBe(false)
})
