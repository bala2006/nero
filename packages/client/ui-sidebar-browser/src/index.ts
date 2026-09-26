/**
 * Host half of the Sidebar Browser plugin: the model-facing side of the tabs a
 * user already has open.
 *
 * The pane itself lives in the client (an iframe on Web, an Electron guest on
 * Desktop), so every command travels over the forwarded
 * `sidebar-browser/request` waterfall and the connected client executes it
 * against the tab it owns. Nothing is launched here: the target is always the
 * page already beside the Session.
 *
 * @module @nero/nero-client-ui-sidebar-browser
 */
import { Context, Service } from '@nero/cordis'
import type { ImageAttachmentRef, ImageMediaType } from '@nero/nero-attachment'
import { defineTool } from '@nero/nero-tools'
import { scopeTarget } from '@nero/nero-scope'
import type { Agent } from '@nero/nero-agent/types'
import type {} from './control.ts'
import type {
  SidebarBrowserCommand, SidebarBrowserRequestEvent, SidebarBrowserResult,
} from './control.ts'

export type {
  SidebarBrowserCapabilities, SidebarBrowserCommand, SidebarBrowserConsoleRecord, SidebarBrowserImage,
  SidebarBrowserRequestEvent, SidebarBrowserResult, SidebarBrowserTabState,
} from './control.ts'

declare module '@nero/cordis' {
  interface Context {
    sidebarBrowser: SidebarBrowserService
  }
}

/** Stable plugin name. */
export const name = 'ui-sidebar-browser'

/** Required Host services: the tool registry owns the model-facing surface. */
export const inject = ['tools']

/** Refusal used when no connected client owns the calling Session's tabs. */
function noClient(): Promise<SidebarBrowserResult> {
  return Promise.reject(new Error(
    'no browser pane answered this request: the Web or Desktop client is not connected, '
    + 'or it has no Browser tab for this Session',
  ))
}

/** `ctx.sidebarBrowser`: one forwarded request per Browser command. */
export class SidebarBrowserService extends Service {
  constructor(ctx: Context) {
    super(ctx, 'sidebarBrowser')
  }

  /**
   * Run one command against the calling agent's open Browser tabs.
   *
   * The request is dispatched on the agent's own scope, so a client answers
   * only for that Session's panes; a deployment with no Browser tab connected
   * rejects instead of reporting an empty world.
   * @param request - command and the calling agent whose Session owns the tabs.
   * @returns what the answering client observed.
   * @throws when no client accepted the request.
   */
  async request(request: {
    readonly command: SidebarBrowserCommand
    readonly agent: Agent | undefined
    readonly signal?: AbortSignal
  }): Promise<SidebarBrowserResult> {
    const agent = request.agent
    if (agent === undefined) {
      throw new Error('sidebar Browser control requires the calling agent to own a Session')
    }
    const event: SidebarBrowserRequestEvent = {
      command: request.command,
      agent,
      ...request.signal === undefined ? {} : { signal: request.signal },
    }
    return await this.ctx.waterfall(scopeTarget(agent, agent), 'sidebar-browser/request', event, noClient)
  }
}

const TAB_ID_DESCRIPTION = 'Optional Browser tab id from browser_tab_list; defaults to the Session\'s newest tab.'

/**
 * One capture as this Host reports it.
 *
 * A deployment with a durable image store replaces the inline bytes with an
 * attachment reference, so the model receives the pixels as an image and the
 * session log keeps a reference instead of base64 text.
 */
interface SidebarBrowserCapture {
  /** Media type the carrier captured. */
  readonly mimeType: string
  /** Inline bytes, present only while no durable image store accepted them. */
  readonly dataBase64?: string
  /** Durable image the Host committed for the model. */
  readonly attachment?: ImageAttachmentRef
}

/** One tool result as the Host returns it, after any capture has been committed. */
interface SidebarBrowserValue extends Omit<SidebarBrowserResult, 'image'> {
  /** The capture this command produced, when it produced one. */
  readonly image?: SidebarBrowserCapture
}

/** Display name of a committed capture in the durable image store. */
const CAPTURE_NAME = 'browser-pane.png'

/** Media types the durable image store accepts from a carrier. */
function captureMediaType(mimeType: string): ImageMediaType | undefined {
  return mimeType === 'image/png' || mimeType === 'image/jpeg' || mimeType === 'image/webp'
    || mimeType === 'image/gif' ? mimeType : undefined
}

/**
 * Decode canonical base64 into the bytes an image store accepts.
 * @param value - base64 payload without a data-URL prefix.
 * @returns the decoded bytes.
 */
function decodeBase64(value: string): Uint8Array {
  const binary = atob(value)
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index)
  return bytes
}

/**
 * Commit one carrier capture so the model can see the page the pane rendered.
 *
 * A model cannot read inline base64 and durable history must not carry pixels,
 * so a mounted image store receives the bytes before the result is recorded.
 * Without one the capture stays inline, which the rendering then reports as
 * bytes the model cannot see.
 * @param ctx - Host context providing the optional image store.
 * @param result - the answering client's result.
 * @returns the result to record, with its capture committed when possible.
 */
async function admitCapture(ctx: Context, result: SidebarBrowserResult): Promise<SidebarBrowserValue> {
  const image = result.image
  const attachments = ctx.get('attachments')
  const mediaType = image === undefined ? undefined : captureMediaType(image.mimeType)
  if (image === undefined || attachments === undefined || mediaType === undefined) return result
  try {
    const attachment = await attachments.saveImage({
      data: decodeBase64(image.dataBase64), mediaType, name: CAPTURE_NAME,
    })
    return { ...result, image: { mimeType: image.mimeType, attachment } }
  } catch (error: unknown) {
    // A capture the model cannot see is not a capture: reporting success would
    // read as a page it inspected, so the failure travels as the result.
    return {
      ...result,
      ok: false,
      error: `the captured page was not stored for you to see: ${error instanceof Error ? error.message : String(error)}`,
      image: { mimeType: image.mimeType },
    }
  }
}

/** Render one result as the content a model reads, including any capture it can see. */
function renderResult(result: SidebarBrowserValue): { type: 'text'; text: string }[] |
  ({ type: 'text'; text: string } | { type: 'image'; attachment: ImageAttachmentRef })[] {
  const lines: string[] = []
  if (!result.ok) lines.push(`FAILED: ${result.error ?? 'unknown error'}`)
  for (const tab of result.tabs) {
    const marker = tab.tabId === result.tab?.tabId ? '* ' : '  '
    lines.push(`${marker}${tab.tabId} ${tab.title ?? '(untitled)'} ${tab.url ?? ''}${tab.loading ? ' [loading]' : ''}`)
  }
  if (result.capabilities !== undefined) {
    const denied = Object.entries(result.capabilities).filter(([, enabled]) => !enabled).map(([name]) => name)
    lines.push(`capabilities: ${denied.length === 0 ? 'all' : `without ${denied.join(', ')}`}`)
  }
  if (result.text !== undefined) lines.push('', result.text)
  if (result.value !== undefined) lines.push('', `evaluate → ${result.value}`)
  if (result.console !== undefined) {
    lines.push('', `console (${String(result.console.length)} records)`)
    for (const record of result.console) {
      lines.push(`${record.level}: ${record.message}${record.sourceId === undefined ? '' : ` (${record.sourceId}${record.line === undefined ? '' : `:${String(record.line)}`})`}`)
    }
  }
  const image = result.image
  if (image !== undefined) {
    lines.push('', image.attachment === undefined
      ? `captured a ${image.mimeType} image of ${String(image.dataBase64?.length ?? 0)} base64 characters, which this deployment could not store for you to see`
      : `captured the page as a ${image.mimeType} image, attached below for you to look at`)
  }
  const text = { type: 'text' as const, text: lines.join('\n') }
  return image?.attachment === undefined ? [text] : [text, { type: 'image' as const, attachment: image.attachment }]
}

/** Fields of one reported Browser tab, shared by the list and the target tab. */
const TAB_PROPERTIES = {
  tabId: { type: 'string', required: true },
  sessionId: { type: 'string', required: true },
  url: { type: 'string' },
  title: { type: 'string' },
  loading: { type: 'boolean', required: true },
  canGoBack: { type: 'boolean', required: true },
  canGoForward: { type: 'boolean', required: true },
} as const

/** Fields of one durable image reference the Host committed from a capture. */
const ATTACHMENT_PROPERTIES = {
  attachmentId: { type: 'string', required: true },
  mediaType: { type: 'string', required: true },
  bytes: { type: 'integer', required: true },
  width: { type: 'integer', required: true },
  height: { type: 'integer', required: true },
  name: { type: 'string' },
  originalDimensions: {
    type: 'object',
    additionalProperties: false,
    properties: {
      width: { type: 'integer', required: true },
      height: { type: 'integer', required: true },
    },
  },
} as const

/**
 * Fields of one raster capture: its media type, the inline bytes while no store
 * accepted them, and the durable reference once the model can see it.
 */
const IMAGE_PROPERTIES = {
  mimeType: { type: 'string', required: true },
  dataBase64: { type: 'string' },
  attachment: { type: 'object', additionalProperties: false, properties: ATTACHMENT_PROPERTIES },
} as const

/** Fields of one console record a client observed. */
const CONSOLE_RECORD_PROPERTIES = {
  level: { type: 'string', required: true },
  message: { type: 'string', required: true },
  sourceId: { type: 'string' },
  line: { type: 'integer' },
} as const

/** Output schema shared by the Browser tools: one plain-data result object. */
const RESULT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    ok: { type: 'boolean', required: true },
    error: { type: 'string' },
    tabs: {
      type: 'array',
      required: true,
      items: { type: 'object', additionalProperties: false, properties: TAB_PROPERTIES },
    },
    tab: { type: 'object', additionalProperties: false, properties: TAB_PROPERTIES },
    capabilities: {
      type: 'object',
      additionalProperties: false,
      properties: {
        snapshot: { type: 'boolean', required: true },
        evaluate: { type: 'boolean', required: true },
        screenshot: { type: 'boolean', required: true },
        console: { type: 'boolean', required: true },
      },
    },
    text: { type: 'string' },
    value: { type: 'string' },
    image: { type: 'object', additionalProperties: false, properties: IMAGE_PROPERTIES },
    console: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, properties: CONSOLE_RECORD_PROPERTIES },
    },
  },
} as const

/** Share one result rendering across the Browser tools. */
const RESULT_OUTPUT = {
  schema: RESULT_SCHEMA,
  render: (_args: unknown, value: unknown) => renderResult(value as SidebarBrowserValue),
}

/** Register the model-facing Browser tools. */
export function apply(ctx: Context): void {
  const service = new SidebarBrowserService(ctx)
  ctx.inject(['tools'], (scope) => {
    // One tool per verb keeps each schema small enough for a model to fill in
    // confidently, while every verb still lands on the shared service.
    scope.effect(() => scope.tools.register(defineTool({
      name: 'browser_tab_open',
      description: 'Open a new Browser tab in the right sidebar at an HTTP(S) URL and return it, so you can then read, '
        + 'operate, and inspect that page. The tab renders beside the conversation where the user watches it, so use '
        + 'this to test your own work in a real browser instead of launching one of your own.',
      parameters: {
        url: { type: 'string', required: true, description: 'HTTP(S) address to open, including loopback services.' },
      },
      output: RESULT_OUTPUT,
      async execute(args, exec) {
        return await admitCapture(ctx,
          await service.request({ command: { kind: 'open', url: args.url }, agent: exec.agent, signal: exec.signal }))
      },
    })), 'ui-sidebar-browser.tool-open')
    scope.effect(() => scope.tools.register(defineTool({
      name: 'browser_tab_list',
      description: 'List the Browser tabs open in the right sidebar, with each tab\'s address, title, load state, '
        + 'and history availability.',
      parameters: {},
      output: RESULT_OUTPUT,
      async execute(_args, exec) {
        return await admitCapture(ctx,
          await service.request({ command: { kind: 'list' }, agent: exec.agent, signal: exec.signal }))
      },
    })), 'ui-sidebar-browser.tool-list')
    scope.effect(() => scope.tools.register(defineTool({
      name: 'browser_tab',
      description: 'Operate one Browser tab in the right sidebar: navigate it, use its history, read a structured '
        + 'snapshot of the page, run JavaScript in it, capture an image of it, or read its console output. '
        + 'A tab renders where the user can see it, so this never opens a second browser; `screenshot` returns '
        + 'the page as an image you can look at yourself.',
      parameters: {
        command: {
          type: 'string',
          required: true,
          description: 'One of: navigate, back, forward, reload, snapshot, evaluate, screenshot, console.',
        },
        url: { type: 'string', description: 'Required by navigate: the HTTP(S) address to load.' },
        script: { type: 'string', description: 'Required by evaluate: JavaScript whose completion value is returned.' },
        tab_id: { type: 'string', description: TAB_ID_DESCRIPTION },
      },
      output: RESULT_OUTPUT,
      async execute(args, exec) {
        return await admitCapture(ctx,
          await service.request({ command: commandOf(args), agent: exec.agent, signal: exec.signal }))
      },
    })), 'ui-sidebar-browser.tool-control')
  })
}

/** Map one tool call onto a protocol command. */
function commandOf(args: {
  readonly command: string
  readonly url?: string
  readonly script?: string
  readonly tab_id?: string
}): SidebarBrowserCommand {
  const tabId = args.tab_id
  const tab = tabId === undefined ? {} : { tabId }
  switch (args.command) {
    case 'navigate': return { kind: 'navigate', url: args.url ?? '', ...tab }
    case 'evaluate': return { kind: 'evaluate', script: args.script ?? '', ...tab }
    case 'back':
    case 'forward':
    case 'reload':
    case 'snapshot':
    case 'screenshot':
    case 'console': return { kind: args.command, ...tab }
    default: throw new Error(`unsupported browser_tab command ${JSON.stringify(args.command)}`)
  }
}
