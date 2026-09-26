/**
 * Agent-facing operations over one live Browser tab.
 *
 * This module owns no transport and no DOM: a caller resolves the tab's
 * {@link BrowserFrame} (or reports that no tab exists) and receives plain data
 * describing what happened. Carriers that cannot inspect a page answer with
 * `unsupported` instead of an empty result, so a caller never mistakes
 * "nothing to read" for "cannot read".
 */
import type {
  BrowserCaptureImage, BrowserConsoleRecord, BrowserControlCapabilities, BrowserFrame, BrowserFrameControl,
} from './BrowserFrame.ts'
import { extractDocument, formatSnapshot } from './snapshot.ts'
import { parseBrowserAddress } from './url.ts'

/** Operations a caller may request against a Browser tab. */
export type BrowserInspectCommand =
  | 'state' | 'snapshot' | 'screenshot' | 'console' | 'evaluate' | 'navigate' | 'back' | 'forward' | 'reload'

/** One requested operation; every field beyond `command` is command-specific. */
export interface BrowserInspectRequest {
  /** Operation to perform. */
  readonly command: BrowserInspectCommand
  /** Target HTTP(S) address, required by `navigate`. */
  readonly url?: string
  /** JavaScript source, required by `evaluate`. */
  readonly script?: string
}

/** Reported identity and navigation state of one Browser tab. */
export interface BrowserInspectTab {
  /** Layout identity of the tab. */
  readonly tabId: string
  /** Session that owns the tab. */
  readonly sessionId: string
  /** Current address, when the carrier has observed one. */
  readonly url?: string
  /** Observed document title. */
  readonly title?: string
  /** Whether the carrier reports an in-flight load. */
  readonly loading: boolean
  /** Whether backward history is available. */
  readonly canGoBack: boolean
  /** Whether forward history is available. */
  readonly canGoForward: boolean
}

/** Outcome of one operation. */
export interface BrowserInspectResult {
  /** The operation this result answers. */
  readonly command: BrowserInspectCommand
  /** Tab the operation ran against; absent only when no tab could be resolved. */
  readonly tab?: BrowserInspectTab
  /** Page capabilities of the carrier that owns this tab. */
  readonly capabilities: BrowserControlCapabilities
  /** Structured page text for `snapshot`. */
  readonly text?: string
  /** Raster page image for `screenshot`. */
  readonly image?: BrowserCaptureImage
  /** Observed console records for `console`. */
  readonly console?: readonly BrowserConsoleRecord[]
  /** JSON text of an `evaluate` completion value. */
  readonly value?: string
  /** Why the operation could not run here, when it could not. */
  readonly unsupported?: string
}

/** No carrier can inspect a page, so every page-reading capability is denied. */
const NO_PAGE_ACCESS: BrowserControlCapabilities = {
  snapshot: false, evaluate: false, screenshot: false, console: false,
}

/** Capabilities of a frame's optional control face, or the fully denied set. */
function capabilitiesOf(frame: BrowserFrame): BrowserControlCapabilities {
  return frame.control?.capabilities ?? NO_PAGE_ACCESS
}

/**
 * Render an arbitrary completion value as JSON text.
 * @param value - value returned by an evaluated script.
 * @returns JSON text, or a string rendering when the value is not JSON-compatible.
 */
function jsonText(value: unknown): string {
  if (value === undefined) return 'null'
  try {
    return JSON.stringify(value) ?? String(value)
  } catch {
    return String(value)
  }
}

/** Whether a request carries the field its command requires. */
function missingField(command: BrowserInspectCommand, request: BrowserInspectRequest): string | undefined {
  if (command === 'navigate' && (request.url ?? '') === '') return 'navigate requires a url'
  if (command === 'evaluate' && (request.script ?? '') === '') return 'evaluate requires a script'
  return undefined
}

/**
 * Describe a tab from its navigation state.
 * @param frame - the tab's live frame.
 * @param tabId - layout identity of the tab.
 * @param sessionId - Session that owns the tab.
 * @returns reported identity and navigation state.
 */
export function inspectTab(frame: BrowserFrame, tabId: string, sessionId: string): BrowserInspectTab {
  const state = frame.getSnapshot()
  const target = state.target
  return {
    tabId,
    sessionId,
    ...target === undefined ? {} : { url: target.url, title: target.title },
    loading: state.loading,
    canGoBack: state.canGoBack,
    canGoForward: state.canGoForward,
  }
}

/**
 * Explain what the pane's carrier can do, so a denied command names its remedy
 * instead of reading as a broken app.
 *
 * The Desktop app's guest reads, scripts, observes, and captures any page the
 * pane loaded; the Web client renders the pane in a sandboxed iframe, which
 * reaches only a document on the app's own origin and cannot rasterize it.
 * @param control - the frame's control face, absent while no page is attached.
 * @param capabilities - what that face currently exposes.
 * @returns a suffix for the denial, or '' when the carrier is fully capable.
 */
function pageAccessNote(control: BrowserFrameControl | undefined, capabilities: BrowserControlCapabilities): string {
  if (control === undefined) return ' (no page is attached to this Browser tab yet; retry)'
  if (!capabilities.snapshot && !capabilities.screenshot) {
    return ": the Web client renders this pane in a sandboxed iframe, which reaches only a page on the app's own "
      + 'origin; the Desktop app reads, scripts, captures, and reports console output for any page in this pane'
  }
  if (!capabilities.screenshot) {
    return ': a Web pane cannot rasterize the frame it embeds; the Desktop app captures this same pane, so open '
      + 'this Browser tab there to capture it'
  }
  return ''
}

/**
 * Run one operation against a resolved tab.
 *
 * Navigation is always available because every carrier navigates; the
 * page-reading commands are gated on the carrier's own capabilities and answer
 * `unsupported` when the platform withholds access.
 * @param frame - the tab's live frame.
 * @param identity - tab and Session the operation is reported against.
 * @param request - requested operation.
 * @returns the outcome, including what the carrier cannot do here.
 */
export async function runInspect(frame: BrowserFrame,
  identity: {
    readonly tabId: string
    readonly sessionId: string
    readonly applicationOrigin: string
  },
  request: BrowserInspectRequest): Promise<BrowserInspectResult> {
  const capabilities = capabilitiesOf(frame)
  const base = { command: request.command, tab: inspectTab(frame, identity.tabId, identity.sessionId), capabilities }
  const missing = missingField(request.command, request)
  if (missing !== undefined) return { ...base, unsupported: missing }
  const control = frame.control
  try {
    switch (request.command) {
      case 'state':
      case 'back':
      case 'forward':
      case 'reload':
        if (request.command === 'back') frame.goBack()
        if (request.command === 'forward') frame.goForward()
        if (request.command === 'reload') frame.reload()
        return base
      case 'navigate': {
        // The agent's address goes through the address bar's own validation.
        const parsed = parseBrowserAddress(request.url as string, identity.applicationOrigin)
        if (!parsed.ok) return { ...base, unsupported: `the address was rejected (${parsed.reason})` }
        frame.loadUrl(parsed.target)
        return base
      }
      case 'snapshot': {
        if (control === undefined || !capabilities.snapshot) {
          return { ...base, unsupported: 'this carrier cannot read the page' + pageAccessNote(control, capabilities) }
        }
        return { ...base, text: await control.snapshot() }
      }
      case 'evaluate': {
        if (control === undefined || !capabilities.evaluate) {
          return { ...base, unsupported: 'this carrier cannot run scripts in the page' + pageAccessNote(control, capabilities) }
        }
        return { ...base, value: jsonText(await control.evaluate(request.script as string)) }
      }
      case 'screenshot': {
        if (control === undefined || !capabilities.screenshot) {
          return { ...base, unsupported: 'this carrier cannot capture the page' + pageAccessNote(control, capabilities) }
        }
        return { ...base, image: await control.capture() }
      }
      case 'console': {
        if (control === undefined || !capabilities.console) {
          return { ...base, unsupported: 'this carrier cannot observe page console output' + pageAccessNote(control, capabilities) }
        }
        return { ...base, console: [...control.consoleRecords()] }
      }
      default:
        return { ...base, unsupported: `unsupported command ${String(request.command)}` }
    }
  } catch (error) {
    return { ...base, unsupported: error instanceof Error ? error.message : String(error) }
  }
}

/**
 * Read a driver-provided document through the standard snapshot rendering.
 * @param document - document a carrier established as readable.
 * @returns the snapshot text a caller receives.
 */
export function readDocument(document: Document): string {
  return formatSnapshot(extractDocument(document))
}
