// @vitest-environment jsdom
/** Agent-facing page inspection: extraction, command dispatch, and carrier control. */
import { describe, expect, it, vi } from 'vitest'
import type {
  BrowserCaptureImage, BrowserConsoleRecord, BrowserControlCapabilities, BrowserFrame, BrowserFrameControl,
  BrowserFrameState,
} from '../src/client/browser/BrowserFrame.ts'
import { emptyBrowserFrame } from '../src/client/browser/BrowserFrame.ts'
import { EXTRACT_SOURCE, extractDocument, formatSnapshot } from '../src/client/browser/snapshot.ts'
import { readDocument, runInspect } from '../src/client/browser/inspect.ts'
import { createWindowControl } from '../src/client/browser/document-control.ts'
import { createGuestControl } from '../src/client/electron/guest-control.ts'
import { consoleRecord } from '../src/client/electron/ElectronWebViewImpl.ts'
import type { ConsoleMessageEvent, WebviewElement } from '../src/client/electron/ElectronWebviewPresentation.ts'
import { electronFixture } from './electron-harness.client.ts'

const NO_ACCESS: BrowserControlCapabilities = { snapshot: false, evaluate: false, screenshot: false, console: false }
const FULL: BrowserControlCapabilities = { snapshot: true, evaluate: true, screenshot: true, console: true }

/** A frame whose navigation calls are recorded and whose state is settable. */
function fakeFrame(options: { readonly control?: BrowserFrameControl; readonly state?: Partial<BrowserFrameState> } = {}) {
  const calls: string[] = []
  const state: BrowserFrameState = { ...emptyBrowserFrame(), ...options.state }
  const frame: BrowserFrame = {
    getSnapshot: () => state,
    subscribe: () => () => {},
    loadUrl: (target) => { calls.push(`loadUrl:${target.url}`) },
    goBack: () => { calls.push('goBack') },
    goForward: () => { calls.push('goForward') },
    reload: () => { calls.push('reload') },
    dispose: () => Promise.resolve(),
    ...options.control === undefined ? {} : { control: options.control },
  }
  return { frame, calls }
}

/** A control face that answers fixed values and records the calls it received. */
function fakeControl(overrides: Partial<BrowserFrameControl> = {}) {
  const calls: string[] = []
  const records: BrowserConsoleRecord[] = [{ level: 'error', message: 'boom' }]
  const control: BrowserFrameControl = {
    capabilities: FULL,
    snapshot: () => { calls.push('snapshot'); return Promise.resolve('snapshot text') },
    evaluate: (script) => { calls.push(`evaluate:${script}`); return Promise.resolve({ ok: true }) },
    capture: () => Promise.resolve({ mimeType: 'image/png', dataBase64: 'AAAA' }),
    consoleRecords: () => records,
    ...overrides,
  }
  return { control, calls, records }
}

const identity = { tabId: 'tab-1', sessionId: 'session-1', applicationOrigin: 'http://127.0.0.1:3080' }

describe('document snapshot', () => {
  it('extracts title, address, text, and indexed interactive elements', () => {
    document.title = 'Example'
    document.body.innerHTML = '<h1>Hello</h1><a href="/one">First</a><input placeholder="Name"><button>Go</button>'
    const snapshot = extractDocument(document)
    expect(snapshot.title).toBe('Example')
    expect(snapshot.text).toContain('Hello')
    expect(snapshot.elements.map(element => element.tag)).toEqual(['a', 'input', 'button'])
    expect(snapshot.elements[0]?.href).toBe('/one')
    expect(snapshot.elements[0]?.label).toBe('First')
    expect(snapshot.elements[1]?.label).toBe('Name')
    expect(snapshot.elements[0]?.selector).toContain('a')
    expect(snapshot.textTruncated).toBe(false)
    expect(snapshot.elementsTruncated).toBe(false)
  })

  it('truncates a long document instead of returning it whole', () => {
    document.title = 'Long'
    document.body.textContent = 'x'.repeat(9000)
    const snapshot = extractDocument(document)
    expect(snapshot.text).toHaveLength(8000)
    expect(snapshot.textTruncated).toBe(true)
  })

  it('renders the snapshot as line-oriented text and marks omitted sections', () => {
    const text = formatSnapshot({
      title: '', url: 'http://example.test/', text: 'body', textTruncated: true,
      elements: [{ index: 0, tag: 'a', label: 'Link', href: '/x', selector: 'a' }], elementsTruncated: true,
    })
    expect(text).toContain('# (untitled)')
    expect(text).toContain('[0] <a> Link — /x')
    expect(text).toContain('… more elements omitted')
    expect(text).toContain('… text truncated')
  })

  it('extracts through the injectable source used by execution-only carriers', () => {
    document.title = 'Injected'
    document.body.innerHTML = '<a href="/deep">Deep</a>'
    const result = window.eval(EXTRACT_SOURCE) as ReturnType<typeof extractDocument>
    expect(result.title).toBe('Injected')
    expect(result.elements[0]?.href).toBe('/deep')
    expect(readDocument(document)).toContain('Deep')
  })
})

describe('inspect dispatch', () => {
  it('reports tab identity and navigation state without touching the page', async () => {
    const { frame } = fakeFrame({ state: { target: { kind: 'http', url: 'http://a.test/', title: 'A' }, canGoBack: true } })
    const result = await runInspect(frame, identity, { command: 'state' })
    expect(result.tab).toMatchObject({ tabId: 'tab-1', sessionId: 'session-1', url: 'http://a.test/', canGoBack: true })
    expect(result.capabilities).toEqual(NO_ACCESS)
  })

  it('drives history and reload through the frame', async () => {
    const { frame, calls } = fakeFrame()
    await runInspect(frame, identity, { command: 'back' })
    await runInspect(frame, identity, { command: 'forward' })
    await runInspect(frame, identity, { command: 'reload' })
    expect(calls).toEqual(['goBack', 'goForward', 'reload'])
  })

  it('validates a navigation address the way the address bar does', async () => {
    const { frame, calls } = fakeFrame()
    const ok = await runInspect(frame, identity, { command: 'navigate', url: 'example.test' })
    expect(ok.unsupported).toBeUndefined()
    expect(calls).toEqual(['loadUrl:https://example.test/'])
    const bad = await runInspect(frame, identity, { command: 'navigate', url: 'file:///etc/passwd' })
    expect(bad.unsupported).toContain('rejected')
    const empty = await runInspect(frame, identity, { command: 'navigate' })
    expect(empty.unsupported).toBe('navigate requires a url')
  })

  it('denies page reading for a carrier without page access', async () => {
    const { frame } = fakeFrame()
    for (const command of ['snapshot', 'evaluate', 'screenshot', 'console'] as const) {
      const result = await runInspect(frame, identity, { command, script: '1', url: 'http://a.test/' })
      expect(result.unsupported).toBeDefined()
    }
  })

  it('names the Web carrier remedy when its sandboxed frame denies the command', async () => {
    // A cross-origin page leaves the iframe carrier with nothing readable, and
    // an unreadable denial must offer the carrier that can do the work rather
    // than read as a broken app.
    const { control } = fakeControl({ capabilities: { snapshot: false, evaluate: false, screenshot: false, console: false } })
    const unreadable = await runInspect(fakeFrame({ control }).frame, identity, { command: 'snapshot' })
    expect(unreadable.unsupported).toContain('sandboxed iframe')
    expect(unreadable.unsupported).toContain('the Desktop app reads, scripts, captures, and reports console output')
    const sameOrigin = fakeControl({ capabilities: { snapshot: true, evaluate: true, screenshot: false, console: false } })
    const capture = await runInspect(fakeFrame({ control: sameOrigin.control }).frame, identity, { command: 'screenshot' })
    expect(capture.unsupported).toContain('a Web pane cannot rasterize the frame it embeds')
    expect(capture.unsupported).toContain('the Desktop app captures this same pane')
    const detached = await runInspect(fakeFrame().frame, identity, { command: 'screenshot' })
    expect(detached.unsupported).toContain('no page is attached to this Browser tab yet')
  })

  it('runs reading, script, capture, and console through a capable carrier', async () => {
    const { control, calls, records } = fakeControl()
    const { frame } = fakeFrame({ control })
    expect((await runInspect(frame, identity, { command: 'snapshot' })).text).toBe('snapshot text')
    expect((await runInspect(frame, identity, { command: 'evaluate', script: '1+1' })).value).toBe('{"ok":true}')
    expect((await runInspect(frame, identity, { command: 'screenshot' })).image).toEqual({
      mimeType: 'image/png', dataBase64: 'AAAA',
    } satisfies BrowserCaptureImage)
    expect((await runInspect(frame, identity, { command: 'console' })).console).toEqual(records)
    expect(calls).toEqual(['snapshot', 'evaluate:1+1'])
  })

  it('requires a script for evaluate and renders non-JSON values as text', async () => {
    const { control } = fakeControl({
      evaluate: () => Promise.resolve(undefined),
    })
    const { frame } = fakeFrame({ control })
    expect((await runInspect(frame, identity, { command: 'evaluate' })).unsupported).toBe('evaluate requires a script')
    expect((await runInspect(frame, identity, { command: 'evaluate', script: 'void 0' })).value).toBe('null')
    const circular: Record<string, unknown> = {}
    circular.self = circular
    const { control: cyclic } = fakeControl({ evaluate: () => Promise.resolve(circular) })
    expect((await runInspect(fakeFrame({ control: cyclic }).frame, identity,
      { command: 'evaluate', script: 'x' })).value).toBe('[object Object]')
  })

  it('turns a carrier failure into an unsupported answer', async () => {
    const { control } = fakeControl({ snapshot: () => Promise.reject(new Error('guest is gone')) })
    const { frame } = fakeFrame({ control })
    expect((await runInspect(frame, identity, { command: 'snapshot' })).unsupported).toBe('guest is gone')
    const throwing = fakeControl({ snapshot: () => { throw 'plain' } })
    expect((await runInspect(fakeFrame({ control: throwing.control }).frame, identity,
      { command: 'snapshot' })).unsupported).toBe('plain')
  })

  it('rejects an unknown command', async () => {
    const { frame } = fakeFrame()
    const result = await runInspect(frame, identity, { command: 'launch' as 'state' })
    expect(result.unsupported).toBe('unsupported command launch')
  })
})

describe('window control', () => {
  it('exposes reading and scripting only for a readable context', async () => {
    const readable = createWindowControl(() => window)
    expect(readable.capabilities).toMatchObject({ snapshot: true, evaluate: true, screenshot: false, console: false })
    document.title = 'Readable'
    expect(await readable.snapshot()).toContain('# Readable')
    expect(await readable.evaluate('21*2')).toBe(42)
    expect(readable.consoleRecords()).toEqual([])
    await expect(readable.capture()).rejects.toThrow('cannot be rasterized')
  })

  it('withdraws every page operation when the frame is unreadable', async () => {
    const unreadable = createWindowControl(() => undefined)
    expect(unreadable.capabilities).toEqual(NO_ACCESS)
    await expect(unreadable.snapshot()).rejects.toThrow('not readable')
    await expect(unreadable.evaluate('1')).rejects.toThrow('not readable')
  })
})

describe('guest control', () => {
  it('reads, scripts, and captures a prepared guest', async () => {
    const calls: string[] = []
    let captured = 0
    const guest = {
      executeJavaScript: (code: string) => {
        calls.push(code)
        if (code === EXTRACT_SOURCE) return Promise.resolve({ title: 'G', url: 'u', text: 't', textTruncated: false,
          elements: [], elementsTruncated: false })
        return Promise.resolve(7)
      },
    } as unknown as WebviewElement
    const consoleRecords: BrowserConsoleRecord[] = [{ level: 'log', message: 'hi' }]
    const control = createGuestControl({
      current: () => guest,
      consoleRecords: () => consoleRecords,
      capture: () => {
        captured += 1
        return Promise.resolve({ mimeType: 'image/png', dataBase64: 'AAAA' })
      },
    })
    expect(control.capabilities).toEqual({ snapshot: true, evaluate: true, screenshot: true, console: true })
    expect(await control.snapshot()).toContain('# G')
    expect(await control.evaluate('7')).toBe(7)
    expect(await control.capture()).toEqual({ mimeType: 'image/png', dataBase64: 'AAAA' })
    expect(captured).toBe(1)
    expect(control.consoleRecords()).toEqual(consoleRecords)
    expect(calls[0]).toBe(EXTRACT_SOURCE)
  })

  it('reports a detached guest instead of driving a stale element', async () => {
    const control = createGuestControl({
      current: () => undefined,
      consoleRecords: () => [],
      capture: () => Promise.resolve({ mimeType: 'image/png', dataBase64: '' }),
    })
    await expect(control.snapshot()).rejects.toThrow('no desktop guest is attached')
    expect(() => control.evaluate('1')).toThrow('no desktop guest is attached')
  })
})

describe('console normalization', () => {
  it('reads numeric levels, older line fields, and named levels', () => {
    expect(consoleRecord({ level: 3, message: 'bad', sourceId: 'a.js', line: 12 } as ConsoleMessageEvent))
      .toEqual({ level: 'error', message: 'bad', sourceId: 'a.js', line: 12 })
    expect(consoleRecord({ level: 'warning', message: 'warn', lineNumber: 4 } as ConsoleMessageEvent))
      .toEqual({ level: 'warning', message: 'warn', line: 4 })
    expect(consoleRecord({ level: 9, message: 'odd' } as ConsoleMessageEvent)).toEqual({ level: 'log', message: 'odd' })
    expect(consoleRecord({ message: 'plain' } as ConsoleMessageEvent)).toEqual({ level: 'log', message: 'plain' })
    expect(consoleRecord({ level: 'log' } as ConsoleMessageEvent)).toBeUndefined()
    expect(consoleRecord({ level: 'log', message: '' } as ConsoleMessageEvent)).toBeUndefined()
  })
})

describe('guest console observation', () => {
  it('retains tag console output and drops it with the guest', async () => {
    const fixture = electronFixture()
    fixture.mount()
    fixture.frame.loadUrl({ kind: 'http', url: 'http://a.test/', title: '' })
    const guest = await fixture.guest()
    guest.emit('console-message', { level: 'error', message: 'kaput', sourceId: 'x.js' })
    guest.emit('console-message', { level: 1, message: '' })
    expect(fixture.frame.control?.consoleRecords()).toEqual([{ level: 'error', message: 'kaput', sourceId: 'x.js' }])
    await fixture.dispose()
  })
})

describe('frame access', () => {
  it('reaches a tab frame through its controller face', async () => {
    const { createBrowserControllers } = await import('../src/client/browser/BrowserController.ts')
    const { createIframePage } = await import('../src/client/pages.ts')
    const host = document.createElement('div')
    host.id = 'browser-viewport-fixture'
    document.body.append(host)
    const face = createBrowserControllers({ replace: vi.fn(), forget: vi.fn() }, createIframePage, () => true)
    face.mount({
      tabId: 'tab-1' as never, signal: new AbortController().signal, viewportId: host.id,
      applicationOrigin: 'http://127.0.0.1:3080', initial: undefined, initialUrl: undefined, openTab: vi.fn(),
    })
    expect(face.frame('tab-1' as never)).toBeDefined()
    expect(face.frame('absent' as never)).toBeUndefined()
    host.remove()
  })
})
