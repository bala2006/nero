// @vitest-environment jsdom
/** Browser type, Slot, locale, and HMR disposal through the real registries. */
import { afterEach, describe, expect, it, vi } from 'vitest'
import { Context } from '@nero/cordis'
import { createSnapshotStore } from '@nero/nero-client-store'
import { SidebarRightTabRegistry } from '@nero/nero-client-ui-sidebar-right/src/client/tab-registry.ts'
import { BrowserBody } from '../src/client/view/BrowserBody.tsx'
import { BrowserTitle } from '../src/client/view/BrowserTitle.tsx'
import type { BrowserInjected } from '../src/client/browser/BrowserController.ts'
import { BROWSER_ID, BROWSER_KIND } from '../src/client/definition.tsx'
import { apply, inject } from '../src/client/index.ts'
import { en, zh } from '../src/client/locales.ts'
import { createBrowserStore } from '../src/client/browser/store.ts'
import type { TabId } from '@nero/nero-client-ui-dockkit'
import type { DesktopBrowserBridge, DesktopBrowserLeaseId } from '../src/types.ts'

const contexts: Context[] = []

afterEach(async () => {
  await Promise.all(contexts.splice(0).map(ctx => ctx.fiber.dispose()))
  vi.unstubAllGlobals()
})

interface Recorded {
  name: string
  key: string
  locale?: string
  store?: unknown
  inject?: unknown
  component: unknown
}

async function boot() {
  const ctx = new Context()
  contexts.push(ctx)
  const tabs = new SidebarRightTabRegistry(ctx)
  const registered: Recorded[] = []
  const slots = {
    inject: vi.fn((_name: string, register: () => () => void) => register()),
    register: vi.fn((options: Omit<Recorded, 'component'>, component: unknown) => {
      const entry: Recorded = { ...options, component }
      registered.push(entry)
      return () => { registered.splice(registered.indexOf(entry), 1) }
    }),
  }
  const dictionaries = new Map<string, unknown>()
  const locale = {
    bind: vi.fn(() => (key: string) => key),
    register: vi.fn((namespace: string, value: unknown) => {
      dictionaries.set(namespace, value)
      return () => { dictionaries.delete(namespace) }
    }),
  }
  ctx.provide('sidebarRightTabs', tabs as never)
  const openTabs = createSnapshotStore<readonly { sessionId: string; tabId: TabId; kind: string }[]>([])
  const openTabIn = vi.fn()
  const openTab = vi.fn()
  const mounted = createSnapshotStore<string | undefined>(undefined)
  ctx.provide('sidebarRight', { openTabs, mounted, openTabIn, openTab } as never)
  ctx.provide('workspaces', { list: createSnapshotStore({ phase: 'ready', items: [] }) } as never)
  ctx.provide('slots', slots as never)
  ctx.provide('locale', locale as never)
  // The control bridge answers forwarded requests; this harness records its
  // listeners so a test can dispatch one exactly as the Gateway does.
  const forwarded = new Map<string, (this: unknown, request: unknown, next: () => unknown) => unknown>()
  ctx.provide('remote', {
    $on: vi.fn((event: string, listener: (this: unknown, request: unknown, next: () => unknown) => unknown) => {
      forwarded.set(event, listener)
      return () => { forwarded.delete(event) }
    }),
  } as never)
  ctx.provide('sessions', { scopeOf: () => 'session' } as never)
  const fiber = ctx.plugin({ inject: [...inject], apply })
  await fiber.await()
  return { tabs, registered, dictionaries, fiber, openTabs, openTabIn, openTab, mounted, forwarded }
}

describe('ui-sidebar-browser apply', () => {
  it.each([0, 1])('binds and rebinds session controllers under desktop protocol %s', async (protocolVersion) => {
    const acquire = vi.fn(async () => ({ lease: 'test-lease' as DesktopBrowserLeaseId, partition: 'test-partition' }))
    const bridge: DesktopBrowserBridge = {
      acquire,
      release: vi.fn(async () => {}),
      capture: vi.fn(async () => ({ mimeType: 'image/png' as const, dataBase64: 'AAAA' })),
      onOpenRequested: vi.fn(() => () => {}),
    }
    vi.stubGlobal('neroDesktop', { protocolVersion, browser: bridge })
    const h = await boot()
    expect(h.tabs.get(BROWSER_KIND)?.keepMounted).toBe(protocolVersion === 1)
    const injectFace = h.registered.find(entry => entry.name === 'sidebar.right.pane.tab')!.inject as
      (sessionId: string, actions: Parameters<BrowserInjected['rebind']>[0]) => BrowserInjected
    const firstStore = createBrowserStore().create(`apply-first-${protocolVersion}`)
    const replacementStore = createBrowserStore().create(`apply-replacement-${protocolVersion}`)
    const controller = injectFace('session', firstStore.actions)
    expect(injectFace('session', replacementStore.actions)).toBe(controller)
    const host = document.createElement('div')
    host.id = `browser-apply-${protocolVersion}`
    document.body.append(host)
    const signal = new AbortController()
    const tabId = 'apply-tab' as TabId
    try {
      controller.mount({ tabId, signal: signal.signal, viewportId: host.id, applicationOrigin: 'https://nero.example',
        initial: undefined, initialUrl: 'https://example.test/', openTab: vi.fn() })
      expect(replacementStore.getSnapshot().byTab[tabId]).toBeDefined()
      expect(firstStore.getSnapshot().byTab[tabId]).toBeUndefined()
      if (protocolVersion === 1) await vi.waitFor(() => { expect(acquire).toHaveBeenCalledWith('session:session') })
      else expect(host.querySelector('iframe')).not.toBeNull()
      h.openTabs.set([{ sessionId: 'other', tabId, kind: BROWSER_KIND }, { sessionId: 'session', tabId: 'other-tab' as TabId, kind: BROWSER_KIND }])
      signal.abort()
      expect(replacementStore.getSnapshot().byTab[tabId]).toBeUndefined()
      const reopened = new AbortController()
      controller.mount({ tabId, signal: reopened.signal, viewportId: host.id, applicationOrigin: 'https://nero.example',
        initial: undefined, initialUrl: 'https://retained.example/', openTab: vi.fn() })
      h.openTabs.set([{ sessionId: 'session', tabId, kind: BROWSER_KIND }])
      reopened.abort()
      expect(replacementStore.getSnapshot().byTab[tabId]).toBeDefined()
      const active = new AbortController()
      controller.mount({ tabId, signal: active.signal, viewportId: host.id, applicationOrigin: 'https://nero.example',
        initial: undefined, initialUrl: undefined, openTab: vi.fn() })
      await h.fiber.dispose()
      expect(controller.keyedHooks.browserState(tabId)).toBeUndefined()
    } finally {
      await h.fiber.dispose()
      host.remove()
    }
  })

  it('registers a multi-instance builtin and its body and title', async () => {
    const { tabs, registered, dictionaries } = await boot()
    const definition = tabs.get(BROWSER_KIND)
    expect(definition).toMatchObject({ id: BROWSER_ID, kind: BROWSER_KIND, multiple: true, priority: 'builtin' })
    expect(definition?.title('sidebar://browser')).toBe('type.label')
    expect(definition?.guide?.map(entry => [entry.order, entry.title(), entry.description?.()]))
      .toEqual([[30, 'guide.title', 'guide.description']])
    expect(dictionaries.get('sidebarBrowser')).toEqual({ zh, en })
    expect(dictionaries.get('sidebarBrowser')).toMatchObject({
      zh: { 'guide.description': '浏览网页' },
      en: { 'guide.description': 'Browse web pages' },
    })
    expect(registered.map(entry => [entry.name, entry.key, entry.locale, entry.component])).toEqual([
      ['sidebar.right.pane.tab', BROWSER_ID, 'sidebarBrowser', BrowserBody],
      ['sidebar.right.pane.tab.title', BROWSER_ID, undefined, BrowserTitle],
    ])
    expect(registered[0]?.store).toBeDefined()
    expect(registered[0]?.inject).toBeTypeOf('function')
    const injectFace = registered[0]?.inject as ((sessionId: string, actions: unknown) => unknown)
    const browser = injectFace('session', { replace: vi.fn(), forget: vi.fn() }) as BrowserInjected
    expect(browser.keyedHooks.browserState('missing')).toBeUndefined()
    expect(typeof browser.mount).toBe('function')
  })

  it('answers an opened pane whose store publishes after the placement turns', async () => {
    const h = await boot()
    const listener = h.forwarded.get('sidebar-browser/request')!
    // The real Sidebar commits the placement into its Session store and the
    // shared inventory mirrors that commit with it, so the pane is visible to
    // the user before this read sees it. Judging the open on one synchronous
    // read reported that pane as refused.
    h.openTabIn.mockImplementation(() => {
      setTimeout(() => { h.openTabs.set([{ sessionId: 'session', tabId: 'raced' as TabId, kind: BROWSER_KIND }]) }, 5)
    })
    const outcome = await listener.call({}, { command: { kind: 'open', url: 'https://example.test/' } }, () => 'next')
    expect(outcome).toMatchObject({ ok: true, tabs: [{ tabId: 'raced', sessionId: 'session' }] })
    expect(h.openTab).not.toHaveBeenCalled()
  })

  it('opens through the mounted seat when this Session holds no adopted store', async () => {
    const h = await boot()
    const listener = h.forwarded.get('sidebar-browser/request')!
    h.openTab.mockImplementation(() => {
      h.openTabs.set([{ sessionId: 'session', tabId: 'seated' as TabId, kind: BROWSER_KIND }])
    })
    const outcome = await listener.call({}, { command: { kind: 'open', url: 'https://example.test/' } }, () => 'next')
    expect(h.openTabIn).toHaveBeenCalledWith('session', BROWSER_KIND, { params: { url: 'https://example.test/' } })
    expect(outcome).toMatchObject({ ok: true, tabs: [{ tabId: 'seated' }] })
  })

  it('refuses with a diagnosis only when no surface places the tab', async () => {
    const h = await boot()
    const listener = h.forwarded.get('sidebar-browser/request')!
    const outcome = await listener.call({}, { command: { kind: 'open', url: 'https://example.test/' } }, () => 'next')
    expect(outcome).toMatchObject({ ok: false, error: 'no Browser pane could be opened for this Session' })
  })

  it('lists an empty world and names the next move for a Session without a pane', async () => {
    const h = await boot()
    const listener = h.forwarded.get('sidebar-browser/request')!
    expect(await listener.call({}, { command: { kind: 'list' } }, () => 'next')).toMatchObject({ ok: true, tabs: [] })
    expect(await listener.call({}, { command: { kind: 'snapshot' } }, () => 'next')).toMatchObject({
      ok: false, error: 'no Browser tab is open for this Session; call browser_tab_open first', tabs: [],
    })
  })

  it('removes every registration when the plugin is disposed', async () => {
    const { tabs, registered, dictionaries, fiber } = await boot()
    await fiber.dispose()
    expect(tabs.get(BROWSER_KIND)).toBeUndefined()
    expect(registered).toEqual([])
    expect(dictionaries.size).toBe(0)
  })
})
