/** Carrier-neutral page navigation and observable state. */
import type { HostObservable } from '@nero/nero-client-ui-slots'
import type { BrowserTarget } from './url.ts'

/**
 * Which page capabilities a carrier can actually expose. A carrier reports
 * `false` for what its platform withholds rather than answering an empty
 * result, so a caller can tell "nothing to read" apart from "cannot read".
 */
export interface BrowserControlCapabilities {
  /** Structured text view of the live document is available. */
  readonly snapshot: boolean
  /** Caller-supplied JavaScript can run in the page. */
  readonly evaluate: boolean
  /** A raster image of the visible page is available. */
  readonly screenshot: boolean
  /** Page console output observed by the carrier is available. */
  readonly console: boolean
}

/** One console record observed by a carrier. */
export interface BrowserConsoleRecord {
  /** Console level as reported by the carrier, for example `error` or `log`. */
  readonly level: string
  /** Rendered message text; the carrier does not evaluate format specifiers. */
  readonly message: string
  /** Optional source URL or module id reported with the record. */
  readonly sourceId?: string
  /** Optional one-based source line. */
  readonly line?: number
}

/** A raster capture of the page, carried as base64 to stay JSON-compatible. */
export interface BrowserCaptureImage {
  /** Image media type, for example `image/png`. */
  readonly mimeType: string
  /** Base64 payload without a data-URL prefix. */
  readonly dataBase64: string
}

/**
 * Carrier-level page inspection, absent when a carrier withholds page access.
 * Every method reports its own availability through {@link capabilities}:
 * callers must check the flags instead of inferring support from a rejection.
 */
export interface BrowserFrameControl {
  /** Capabilities of this carrier for the currently loaded page. */
  readonly capabilities: BrowserControlCapabilities
  /** @returns a structured text view of the live document. */
  snapshot(): Promise<string>
  /** @param script - JavaScript source evaluated in the page. @returns its JSON-compatible completion value. */
  evaluate(script: string): Promise<unknown>
  /** @returns a raster image of the page as the carrier rendered it. */
  capture(): Promise<BrowserCaptureImage>
  /** @returns console records observed since the current page was created, oldest first. */
  consoleRecords(): readonly BrowserConsoleRecord[]
}

/** A loading failure, optionally carrying the underlying browser's diagnostic. */
export interface BrowserLoadError {
  readonly code: number | undefined
  readonly description: string | undefined
}

/** State consumed by common browser chrome, without DOM or carrier identifiers. */
export interface BrowserFrameState {
  readonly target: BrowserTarget | undefined
  readonly address: 'empty' | 'requested' | 'observed' | 'unknown'
  readonly loading: boolean
  readonly canGoBack: boolean
  readonly canGoForward: boolean
  readonly error: BrowserLoadError | undefined
  /** Undefined when this provider does not expose a sandbox control. */
  readonly sandboxEnabled: boolean | undefined
}

/** Optional iframe policy control, not an Electron process-sandbox switch. */
export interface BrowserSandboxControl {
  /** @param enabled - whether the provider's embedding sandbox is enforced. */
  setEnabled(enabled: boolean): void
}

/** Navigation owns page lifetime; mounting and hiding belong to BrowserPresentation. */
export interface BrowserFrame extends HostObservable<BrowserFrameState> {
  readonly sandbox?: BrowserSandboxControl
  /**
   * Page inspection and script execution, or undefined when this carrier never
   * exposes page access — an iframe over an arbitrary origin, for instance.
   */
  readonly control?: BrowserFrameControl
  /** @param target - validated HTTP(S) address; loading failures are published in state. */
  loadUrl(target: BrowserTarget): void
  /** Move backward when the provider reports an available entry. */
  goBack(): void
  /** Move forward when the provider reports an available entry. */
  goForward(): void
  /** Reload the current address without creating a new history entry. */
  reload(): void
  /** @returns after the page, listeners and pending initialization have been released; repeated calls join disposal. */
  dispose(): Promise<void>
}

/**
 * Create idle navigation state without a page target.
 * @returns state before any page has been requested.
 */
export function emptyBrowserFrame(): BrowserFrameState {
  return { target: undefined, address: 'empty', loading: false, canGoBack: false, canGoForward: false,
    error: undefined, sandboxEnabled: undefined }
}
