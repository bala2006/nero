/** Iframe navigation provider with bounded application-known history. */
import { createSnapshotStore, type SnapshotStore } from '@nero/nero-client-store'
import type { IframePresentation } from '../view/IframePresentation.ts'
import { emptyBrowserFrame, type BrowserFrame, type BrowserFrameControl, type BrowserFrameState, type BrowserLoadError, type BrowserSandboxControl } from './BrowserFrame.ts'
import { createWindowControl } from './document-control.ts'
import type { BrowserPageOptions } from './BrowserPage.ts'
import { BrowserNavigation } from './BrowserNavigation.ts'
import type { BrowserTarget } from './url.ts'

/** Owns iframe navigation; the view reports loads without reading cross-origin content. */
export class IframeImpl implements BrowserFrame {
  readonly sandbox: BrowserSandboxControl = { setEnabled: (enabled) => { this.setSandbox(enabled) } }
  private readonly navigation: BrowserNavigation
  private readonly store: SnapshotStore<BrowserFrameState>
  private sandboxed = true
  private error: BrowserLoadError | undefined
  private disposed = false
  private disposal: Promise<void> | undefined
  private controlFace: BrowserFrameControl | undefined

  /** @param options - initial checkpoint and persistence writer. @param presentation - iframe DOM adapter. */
  constructor(private readonly options: BrowserPageOptions, private readonly presentation: IframePresentation) {
    this.navigation = new BrowserNavigation(options.initial)
    this.store = createSnapshotStore({ ...emptyBrowserFrame(), sandboxEnabled: this.sandboxed })
  }

  /**
   * Record a controlled load or a later navigation to an unreadable address.
   * @param revision - document generation whose iframe emitted load.
   */
  handleLoaded(revision: number): void {
    if (this.disposed) return
    this.navigation.frameLoaded(revision)
    this.publish()
  }

  /**
   * Publish a failure only for the current document generation.
   * @param revision - document generation whose iframe reported failure.
   */
  handleLoadFailed(revision: number): void {
    if (this.disposed || this.navigation.snapshot.request?.revision !== revision) return
    this.error = { code: undefined, description: undefined }
    this.publish()
  }

  /**
   * Page inspection over a same-origin frame.
   *
   * A Web frame belongs to the visited origin, so an arbitrary address stays
   * unreadable: the face reports every page-reading capability as unavailable
   * rather than throwing once a caller has already committed to a plan.
   */
  get control(): BrowserFrameControl {
    this.controlFace ??= createWindowControl(() => this.presentation.readableWindow())
    return this.controlFace
  }

  /** @returns immutable navigation state. */
  getSnapshot = (): BrowserFrameState => this.store.getSnapshot()
  /** @param listener - state invalidation. @returns unsubscribe callback. */
  subscribe = (listener: () => void): (() => void) => this.store.subscribe(listener)

  /** @param target - validated address; submitting the current address reloads it. */
  loadUrl(target: BrowserTarget): void {
    if (this.disposed) return
    const request = BrowserNavigation.current(this.navigation.snapshot)?.url === target.url
      ? this.navigation.reload() : this.navigation.navigate(target)
    this.load(request)
  }

  /** Move through application-known history while the iframe address remains known. */
  goBack(): void { if (!this.disposed) this.load(this.navigation.back()) }
  /** Move through application-known history while the iframe address remains known. */
  goForward(): void { if (!this.disposed) this.load(this.navigation.forward()) }
  /** Reload the last application-known address. */
  reload(): void { if (!this.disposed) this.load(this.navigation.reload()) }

  /** @returns after the presentation has been removed; repeated calls join disposal. */
  dispose(): Promise<void> {
    if (this.disposal !== undefined) return this.disposal
    this.disposed = true
    this.presentation.dispose()
    this.disposal = Promise.resolve()
    return this.disposal
  }

  private setSandbox(enabled: boolean): void {
    if (this.disposed || enabled === this.sandboxed) return
    this.sandboxed = enabled
    if (this.store.getSnapshot().target === undefined) {
      this.store.set({ ...this.store.getSnapshot(), sandboxEnabled: enabled })
      return
    }
    this.load(this.navigation.reload())
  }

  private load(request: ReturnType<BrowserNavigation['navigate']> | undefined): void {
    if (request === undefined) return
    this.error = undefined
    this.publish()
    this.presentation.show({ target: request.target, revision: request.revision, sandboxed: this.sandboxed })
  }

  private snapshot(): BrowserFrameState {
    const state = this.navigation.snapshot
    const target = BrowserNavigation.current(state)
    return { target, address: target === undefined ? 'empty' : state.navigation.status === 'unknown' ? 'unknown' : 'requested',
      loading: state.navigation.status === 'loading' && this.error === undefined,
      canGoBack: this.navigation.canGoBack, canGoForward: this.navigation.canGoForward,
      error: this.error, sandboxEnabled: this.sandboxed }
  }

  private publish(): void {
    this.store.set(this.snapshot())
    this.options.persist(this.navigation.snapshot)
  }
}
