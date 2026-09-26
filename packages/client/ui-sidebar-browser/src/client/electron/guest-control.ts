/**
 * Control face for a desktop guest — the pane carrier that reads, scripts,
 * observes, and captures the page it embeds.
 *
 * The guest is owned by this renderer, so it can be read and scripted
 * directly, and the tag reports its console output to us. Nothing crosses into
 * the visited page beyond the script a caller asked to run.
 */
import type {
  BrowserCaptureImage, BrowserConsoleRecord, BrowserControlCapabilities, BrowserFrameControl,
} from '../browser/BrowserFrame.ts'
import { EXTRACT_SOURCE, formatSnapshot, type DocumentSnapshot } from '../browser/snapshot.ts'
import type { WebviewElement } from './ElectronWebviewPresentation.ts'

/**
 * A prepared guest exposes reading, execution, console observation, and capture.
 *
 * A tag cannot rasterize the page it embeds, so the capture arrives from the
 * main process through the lease that owns this guest; the renderer asks for it
 * and receives plain encoded bytes.
 */
const GUEST: BrowserControlCapabilities = { snapshot: true, evaluate: true, screenshot: true, console: true }

/** Live inputs a guest control reads per call. */
export interface GuestControlInputs {
  /** @returns the live guest, or undefined while none is attached. */
  readonly current: () => WebviewElement | undefined
  /** @returns console records observed for the current guest, oldest first. */
  readonly consoleRecords: () => readonly BrowserConsoleRecord[]
  /** @returns the attached guest's page as a raster capture. */
  readonly capture: () => Promise<BrowserCaptureImage>
}

/**
 * Build the desktop guest control face.
 * @param inputs - live guest, console, and capture providers.
 * @returns the carrier's control face; each call re-reads the guest so a
 * recreated guest is never driven through a stale element.
 */
export function createGuestControl(inputs: GuestControlInputs): BrowserFrameControl {
  const guest = (): WebviewElement => {
    const element = inputs.current()
    if (element === undefined) throw new Error('no desktop guest is attached')
    return element
  }
  return {
    capabilities: GUEST,
    snapshot: async () => formatSnapshot(await guest().executeJavaScript(EXTRACT_SOURCE, true) as DocumentSnapshot),
    evaluate: (script: string) => guest().executeJavaScript(script, true),
    capture: () => inputs.capture(),
    consoleRecords: () => inputs.consoleRecords(),
  }
}
