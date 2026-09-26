/**
 * Client-safe protocol for driving the Browser tabs a user already has open.
 *
 * The Host forwards one waterfall event; every live client answers for its own
 * Session's tabs. Payloads stay plain data because they cross the Remote
 * boundary, and a carrier that cannot read a page says so through
 * {@link SidebarBrowserCapabilities} instead of answering with empty content.
 *
 * @module @nero/nero-client-ui-sidebar-browser/control
 */
import type { Scoped } from '@nero/nero-scope'
import type { Agent } from '@nero/nero-agent/types'

/** Browser tabs are identified by their Session and layout identity. */
export type SidebarBrowserCommand =
  | { readonly kind: 'list' }
  | { readonly kind: 'open'; readonly url: string }
  | { readonly kind: 'navigate'; readonly url: string; readonly tabId?: string }
  | { readonly kind: 'back' | 'forward' | 'reload'; readonly tabId?: string }
  | { readonly kind: 'snapshot' | 'screenshot' | 'console'; readonly tabId?: string }
  | { readonly kind: 'evaluate'; readonly script: string; readonly tabId?: string }

/** What the carrier that owns a tab can expose for it. */
export interface SidebarBrowserCapabilities {
  /** A structured text view of the page is available. */
  readonly snapshot: boolean
  /** Caller-supplied JavaScript can run in the page. */
  readonly evaluate: boolean
  /** A raster image of the page is available. */
  readonly screenshot: boolean
  /** Page console output is available. */
  readonly console: boolean
}

/** One reported console record. */
export interface SidebarBrowserConsoleRecord {
  /** Console level, for example `error`. */
  readonly level: string
  /** Rendered message text. */
  readonly message: string
  /** Optional source URL or module id. */
  readonly sourceId?: string
  /** Optional one-based source line. */
  readonly line?: number
}

/** Reported identity and navigation state of one Browser tab. */
export interface SidebarBrowserTabState {
  /** Layout identity of the tab. */
  readonly tabId: string
  /** Session that owns the tab. */
  readonly sessionId: string
  /** Current address, when the carrier has observed one. */
  readonly url?: string
  /** Observed document title. */
  readonly title?: string
  /** Whether a load is in flight. */
  readonly loading: boolean
  /** Whether backward history is available. */
  readonly canGoBack: boolean
  /** Whether forward history is available. */
  readonly canGoForward: boolean
}

/** A raster capture carried as base64 so the whole result stays JSON data. */
export interface SidebarBrowserImage {
  /** Image media type, for example `image/png`. */
  readonly mimeType: string
  /** Base64 payload without a data-URL prefix. */
  readonly dataBase64: string
}

/** Outcome of one Browser control request. */
export interface SidebarBrowserResult {
  /** Whether the command ran; `error` explains a refusal. */
  readonly ok: boolean
  /** Why the command could not run, when it could not. */
  readonly error?: string
  /** Every Browser tab the answering client owns. */
  readonly tabs: SidebarBrowserTabState[]
  /** The tab this command ran against, when one was resolved. */
  readonly tab?: SidebarBrowserTabState
  /** Capabilities of the carrier that owns `tab`. */
  readonly capabilities?: SidebarBrowserCapabilities
  /** Snapshot text for `snapshot`. */
  readonly text?: string
  /** Capture for `screenshot`. */
  readonly image?: SidebarBrowserImage
  /** Records for `console`. */
  readonly console?: SidebarBrowserConsoleRecord[]
  /** JSON text of an `evaluate` completion value. */
  readonly value?: string
}

/** Payload declared for the Browser control waterfall. */
export interface SidebarBrowserRequestEvent {
  /** Command to run against the calling Session's Browser tabs. */
  readonly command: SidebarBrowserCommand
  /** Agent identity projected to the corresponding Client Context in transit. */
  readonly agent?: Agent
  /** Cancellation lifetime of the pending request. */
  readonly signal?: AbortSignal
}

declare module '@nero/cordis' {
  interface Events {
    /**
     * Ask connected clients to operate the Browser tabs of the calling
     * Session. A client answers for its own tabs, or calls `next()` to
     * delegate; with no client connected the Host reports that refusal.
     * Scope-filtered dispatch (`@nero/nero-scope`): agent-scoped listeners
     * receive only that agent.
     * @param request - Browser control command and its Agent.
     * @mode waterfall
     */
    'sidebar-browser/request'(
      this: Scoped<Agent>,
      request: SidebarBrowserRequestEvent,
      next: () => Promise<SidebarBrowserResult>,
    ): Promise<SidebarBrowserResult>
  }
}
