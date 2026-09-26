/**
 * Control face for carriers that expose a readable same-document context.
 *
 * A carrier supplies "the context I may read, if any" and receives the shared
 * page operations. Rasterizing an embedded frame is impossible from script in
 * any browser, so `screenshot` is permanently denied here and the carrier that
 * can capture — the desktop guest — reports its own capabilities instead.
 */
import type {
  BrowserConsoleRecord, BrowserControlCapabilities, BrowserFrameControl,
} from './BrowserFrame.ts'
import { EXTRACT_SOURCE, formatSnapshot, type DocumentSnapshot } from './snapshot.ts'

/** Capabilities of a context that can be read and scripted but never rasterized. */
const READABLE: BrowserControlCapabilities = { snapshot: true, evaluate: true, screenshot: false, console: false }

/** No context is readable, so every page operation is denied. */
const UNREADABLE: BrowserControlCapabilities = { snapshot: false, evaluate: false, screenshot: false, console: false }

/** @returns the context to read, or undefined when the page is not readable. */
export type ReadableContextProvider = () => Window | undefined

/**
 * Run one script in a frame window.
 * @param window - the frame's window.
 * @param code - script source.
 * @returns the script's completion value.
 */
function run(window: Window, code: string): unknown {
  // `Window` alone omits `eval`; the frame window provides it at runtime.
  return (window as Window & { eval(code: string): unknown }).eval(code)
}

/**
 * Control face over an optionally readable same-origin context.
 * @param readable - provider of the readable context, probed per call so a
 * navigation to a cross-origin page withdraws access immediately.
 * @returns the carrier's control face.
 */
export function createWindowControl(readable: ReadableContextProvider): BrowserFrameControl {
  const context = (): Window | undefined => readable()
  const requireContext = (): Window => {
    const window = context()
    if (window === undefined) throw new Error('the page is not readable from this origin')
    return window
  }
  return {
    get capabilities(): BrowserControlCapabilities { return context() === undefined ? UNREADABLE : READABLE },
    // Reading through the injected source keeps one extractor for every carrier.
    // Async so an unreadable page rejects instead of throwing past a caller.
    snapshot: async () => formatSnapshot(run(requireContext(), EXTRACT_SOURCE) as DocumentSnapshot),
    evaluate: async (script: string) => run(requireContext(), script),
    capture: () => Promise.reject(new Error('an embedded frame cannot be rasterized from script')),
    consoleRecords: (): readonly BrowserConsoleRecord[] => [],
  }
}
