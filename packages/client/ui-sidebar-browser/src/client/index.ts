/** Register the HTTP(S) Browser tab type in the right Sidebar. */
import type { Context } from '@nero/cordis'
import type {} from '@nero/nero-client-locale/client'
import type {} from '@nero/nero-client-ui-renderer/client'
import type {} from '@nero/nero-client-ui-session/client'
import type {} from '@nero/nero-client-ui-sidebar-right/client'
import type {} from '@nero/nero-api-workspace-controller/client'
import { BrowserBody, type BrowserBodyProps } from './view/BrowserBody.tsx'
import { BrowserTitle } from './view/BrowserTitle.tsx'
import { createBrowserControllers } from './browser/BrowserController.ts'
import type { BrowserInjected } from './browser/BrowserController.ts'
import { createIframePage } from './pages.ts'
import { createElectronPage } from './electron/pages.ts'
import type { DesktopBrowserBridge } from '../types.ts'
// Type-only: pulls the Remote Events Context merge (ctx.remote) into this face.
import type {} from '@nero/nero-api-remotes/client'
import type { ISessions } from '@nero/nero-api-session-controller/client'
import type { TypertClientEventListener } from '@nero/nero-typert-protocol'
import { runInspect } from './browser/inspect.ts'
import type { SidebarBrowserResult, SidebarBrowserTabState } from '../control.ts'
import { browserWorkspace } from './electron/workspace.ts'
import type { BrowserPageFactory } from './browser/BrowserPage.ts'
import { BROWSER_ID, BROWSER_KIND, browserDefinition } from './definition.tsx'
import type { TabId } from '@nero/nero-client-ui-dockkit'
import { en, zh } from './locales.ts'
import { createBrowserStore } from './browser/store.ts'

export type { BrowserBodyProps } from './view/BrowserBody.tsx'
export type { BrowserControllerState, BrowserInjected, BrowserMountRequest } from './browser/BrowserController.ts'
export type {
  BrowserCaptureImage, BrowserConsoleRecord, BrowserControlCapabilities, BrowserFrame, BrowserFrameControl,
  BrowserFrameState, BrowserLoadError, BrowserSandboxControl,
} from './browser/BrowserFrame.ts'
export { extractDocument, formatSnapshot, EXTRACT_SOURCE } from './browser/snapshot.ts'
export type { DocumentSnapshot, SnapshotElement } from './browser/snapshot.ts'
export { inspectTab, readDocument, runInspect } from './browser/inspect.ts'
export type { BrowserInspectCommand, BrowserInspectRequest, BrowserInspectResult, BrowserInspectTab } from './browser/inspect.ts'
export type { BrowserPage, BrowserPageFactory, BrowserPageOptions } from './browser/BrowserPage.ts'
export type { BrowserPresentation } from './view/BrowserPresentation.ts'
export type { BrowserFailure, BrowserHistoryEntry, BrowserNavigationStatus, BrowserTabState } from './browser/BrowserPersistence.ts'
export type { SidebarBrowserKey } from './locales.ts'
export type { BrowserState } from './browser/store.ts'
export type { BrowserAddressFailure, BrowserAddressResult, BrowserTarget } from './browser/url.ts'
export type {
  SidebarBrowserCapabilities, SidebarBrowserCommand, SidebarBrowserConsoleRecord, SidebarBrowserImage,
  SidebarBrowserRequestEvent, SidebarBrowserResult, SidebarBrowserTabState,
} from '../control.ts'

declare module '@nero/nero-client-ui-sidebar-right/client' {
  interface SidebarRightTabParamsMap {
    /** Optional initial Browser URL. */
    browser: { readonly url?: string }
  }
}

/** Required Browser services: panes, the Remote event stream, and Session scope. */
export const inject = ['slots', 'locale', 'sidebarRight', 'sidebarRightTabs', 'remote', 'sessions']

type BrowserRequestListener = TypertClientEventListener<'sidebar-browser/request'>
type ClientBrowserRequest = Parameters<BrowserRequestListener>[0]
type ClientBrowserNext = Parameters<BrowserRequestListener>[1]

/** One open tab's reported state, read from the inventory and its controller. */
function tabState(tab: { readonly tabId: string; readonly sessionId: string },
  frame: ReturnType<BrowserInjected['frame']>): SidebarBrowserTabState {
  const state = frame?.getSnapshot()
  const target = state?.target
  return {
    tabId: tab.tabId,
    sessionId: tab.sessionId,
    ...target === undefined ? {} : { url: target.url, title: target.title },
    loading: state?.loading ?? false,
    canGoBack: state?.canGoBack ?? false,
    canGoForward: state?.canGoForward ?? false,
  }
}

/** Bounded wait for a freshly placed pane to mount and register its face. */
async function settleFace(read: () => BrowserInjected | undefined): Promise<BrowserInjected | undefined> {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const face = read()
    if (face !== undefined) return face
    await new Promise(resolve => setTimeout(resolve, 25))
  }
  return read()
}

/**
 * Bounded wait for a placement to reach the published tab inventory.
 *
 * A placement commits through the Session's Sidebar store, and the inventory
 * that mirrors those commits only publishes with it, so reading it once in the
 * same turn can still describe the layout before the pane opened — which would
 * report the Browser tab the user is watching appear as a refusal.
 * @param read - reads this Session's Browser tabs from the inventory.
 * @returns the tabs once any are published, or the last read on timeout.
 */
async function settleTabs<T extends { readonly tabId: string; readonly sessionId: string }>(
  read: () => readonly T[],
): Promise<readonly T[]> {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const tabs = read()
    if (tabs.length > 0) return tabs
    await new Promise(resolve => setTimeout(resolve, 25))
  }
  return read()
}

/**
 * Answer one Browser control request for the client that owns the Session.
 *
 * Only this Session's panes are visible here, so a request from another
 * Session's agent falls through to the next answerer instead of driving a tab
 * the user did not offer.
 */
async function answerBrowserRequest(ctx: Context, owner: Context, request: ClientBrowserRequest,
  next: ClientBrowserNext, faces: Map<string, BrowserInjected>): Promise<SidebarBrowserResult> {
  const sessionId = (ctx.sessions as ISessions).scopeOf(owner)
  if (sessionId === undefined) return next()
  const inventoryOf = () => ctx.sidebarRight.openTabs.getSnapshot()
    .filter(tab => tab.sessionId === sessionId && tab.kind === BROWSER_KIND)
  const tabsOf = (face: BrowserInjected | undefined): SidebarBrowserTabState[] =>
    inventoryOf().map(tab => tabState(tab, face?.frame(tab.tabId as TabId)))
  const command = request.command
  // `open` is how this Session's pane comes into existence: a client that has
  // not rendered the Browser tab has no face yet, so requiring one here would
  // refuse the very request that creates it as "no client connected". Place
  // the tab for this Session, then read back the face it mounts.
  if (command.kind === 'open') {
    ctx.sidebarRight.openTabIn(sessionId, BROWSER_KIND, { params: { url: command.url } })
    let placed = await settleTabs(inventoryOf)
    if (placed.length === 0) {
      // This Session's store was never adopted here, so the mounted seat is
      // the only surface left to open into; it throws when none is mounted.
      try { ctx.sidebarRight.openTab(BROWSER_KIND, { params: { url: command.url } }) } catch { /* no seat mounted */ }
      placed = await settleTabs(inventoryOf)
    }
    if (placed.length === 0) {
      return { ok: false, error: 'no Browser pane could be opened for this Session', tabs: [] }
    }
    return { ok: true, tabs: tabsOf(faces.get(sessionId) ?? await settleFace(() => faces.get(sessionId))) }
  }
  // A tab whose pane is still mounting registers its face a turn later; the
  // command that follows `open` must wait for it rather than tell the model to
  // retry work it already did.
  let face = faces.get(sessionId)
  if (face === undefined && inventoryOf().length > 0) face = await settleFace(() => faces.get(sessionId))
  if (face === undefined) {
    // A tab without a live face is mounting: reporting "no client connected"
    // would blame the connection for an opening still in flight.
    if (inventoryOf().length > 0) {
      return { ok: false, error: 'the Browser pane for this Session is still opening; retry', tabs: tabsOf(undefined) }
    }
    // This Session simply has no Browser tab yet. Answering here tells the
    // model the world is empty (so `open` is the next move); falling through
    // would surface as "no client connected", which reads like a broken app.
    if (command.kind === 'list') return { ok: true, tabs: [] }
    return { ok: false, error: 'no Browser tab is open for this Session; call browser_tab_open first', tabs: [] }
  }
  const inventory = inventoryOf()
  const tabs = inventory.map(tab => tabState(tab, face.frame(tab.tabId as TabId)))
  // Chrome above owns the layout: republish after any command so callers see it.
  const wanted = command.kind === 'list' ? undefined : command.tabId ?? inventory.at(-1)?.tabId
  if (command.kind === 'list') return { ok: true, tabs }
  if (wanted === undefined) return { ok: false, error: 'no Browser tab is open for this Session', tabs }
  const frame = face.frame(wanted as TabId)
  if (frame === undefined) return { ok: false, error: `Browser tab ${wanted} has no live page`, tabs }
  const inspected = await runInspect(frame, {
    tabId: wanted, sessionId, applicationOrigin: globalThis.location.origin,
  }, { command: command.kind, ...'url' in command ? { url: command.url } : {},
    ...'script' in command ? { script: command.script } : {} })
  const after = inventory.map(tab => tabState(tab, face.frame(tab.tabId as TabId)))
  const tab = after.find(entry => entry.tabId === wanted)
  return {
    ok: inspected.unsupported === undefined,
    ...inspected.unsupported === undefined ? {} : { error: inspected.unsupported },
    tabs: after,
    ...tab === undefined ? {} : { tab },
    capabilities: inspected.capabilities,
    ...inspected.text === undefined ? {} : { text: inspected.text },
    ...inspected.image === undefined ? {} : { image: inspected.image },
    ...inspected.console === undefined ? {} : { console: [...inspected.console] },
    ...inspected.value === undefined ? {} : { value: inspected.value },
  }
}

/** Register the Browser type, localized guide entry, body, and title. */
export function apply(ctx: Context): void {
  const namespace = 'sidebarBrowser'
  const t = ctx.locale.bind(namespace)
  const store = createBrowserStore()
  const openTabs = ctx.sidebarRight.openTabs
  const carrier = (globalThis as typeof globalThis & {
    neroDesktop?: { readonly protocolVersion: number; readonly browser?: DesktopBrowserBridge }
  }).neroDesktop
  const desktop = carrier?.protocolVersion === 1 ? carrier.browser : undefined
  ctx.effect(() => ctx.locale.register(namespace, { zh, en }), 'ui-sidebar-browser.copy')
  ctx.effect(() => ctx.sidebarRightTabs.register({ ...browserDefinition(t), keepMounted: desktop !== undefined }), 'ui-sidebar-browser.type')
  const installFrames = (scope: Context, factory: (sessionId: BrowserBodyProps['sessionId']) => BrowserPageFactory,
    faces: Map<string, BrowserInjected>): void => {
    const controllers = new Map<BrowserBodyProps['sessionId'], BrowserInjected>()
    scope.effect(() => async () => {
      const pending = [...controllers.values()].map(controller => controller.dispose())
      controllers.clear()
      faces.clear()
      await Promise.all(pending)
    }, 'ui-sidebar-browser.frames')
    scope.effect(() => scope.slots.inject('sidebar.right.pane.tab', () => scope.slots.register({
      name: 'sidebar.right.pane.tab', key: BROWSER_ID, locale: namespace, store,
      inject: (sessionId, actions) => {
        const existing = controllers.get(sessionId)
        if (existing !== undefined) {
          existing.rebind(actions)
          faces.set(sessionId, existing)
          return existing
        }
        const controller = createBrowserControllers(actions, factory(sessionId), tabId =>
          openTabs.getSnapshot().some(tab => tab.sessionId === sessionId && tab.tabId === tabId))
        controllers.set(sessionId, controller)
        // The forwarded control request resolves panes through this face.
        faces.set(sessionId, controller)
        return controller
      },
    }, BrowserBody)), 'ui-sidebar-browser.body')
  }
  const faces = new Map<string, BrowserInjected>()
  ctx.effect(() => () => { faces.clear() }, 'ui-sidebar-browser.faces')
  if (desktop === undefined) installFrames(ctx, () => createIframePage, faces)
  else ctx.inject(['workspaces'], (scope) => {
    installFrames(scope, sessionId => options => createElectronPage(options, desktop,
      signal => browserWorkspace(scope.workspaces.list, sessionId, signal)), faces)
  })
  ctx.remote.$on('sidebar-browser/request', function (request, next) {
    return answerBrowserRequest(ctx, this, request, next, faces)
  })
  ctx.effect(() => ctx.slots.inject('sidebar.right.pane.tab.title', () => ctx.slots.register({
    name: 'sidebar.right.pane.tab.title', key: BROWSER_ID, store,
  }, BrowserTitle)), 'ui-sidebar-browser.title')
}
