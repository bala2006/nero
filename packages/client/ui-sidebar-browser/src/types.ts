/** Type-only Electron bridge declarations shared by the desktop shell and browser provider. */
import type { Branded } from '@nero/nero-brand'

/** Main-issued identity of one guest reservation. */
export type DesktopBrowserLeaseId = Branded<'DesktopBrowserLeaseId'>

/** A guest's approved, process-local storage partition. */
export interface DesktopBrowserReservation {
  readonly lease: DesktopBrowserLeaseId
  readonly partition: string
}

/** Main-approved request to open an HTTP(S) page from an existing guest. */
export interface DesktopBrowserOpenRequest {
  readonly lease: DesktopBrowserLeaseId
  readonly url: string
}

/**
 * One raster capture of a guest's rendered page, encoded so only plain data
 * crosses IPC. Main owns the raster because the tag that hosts the guest
 * exposes no capture of its own.
 */
export interface DesktopBrowserCapture {
  /** Media type of the encoded raster; captures are always PNG. */
  readonly mimeType: 'image/png'
  /** Base64 payload without a data-URL prefix. */
  readonly dataBase64: string
}

/** Origin-scoped operations; no Electron objects or arbitrary IPC cross this interface. */
export interface DesktopBrowserBridge {
  /** @param workspace - resolved storage account. @returns one approved guest reservation. */
  acquire(workspace: string): Promise<DesktopBrowserReservation>
  /** @param lease - the caller's reservation. @returns after its guest has been destroyed. */
  release(lease: DesktopBrowserLeaseId): Promise<void>
  /**
   * Rasterize the page one leased guest is rendering.
   * @param lease - the caller's reservation, whose guest must be attached.
   * @returns the page as a PNG capture.
   */
  capture(lease: DesktopBrowserLeaseId): Promise<DesktopBrowserCapture>
  /** @param lease - originating guest. @param listener - approved URL consumer. @returns unsubscribe callback. */
  onOpenRequested(lease: DesktopBrowserLeaseId, listener: (url: string) => void): () => void
}
