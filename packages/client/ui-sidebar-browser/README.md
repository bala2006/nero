---
description: "Right-Sidebar browser tabs for sandboxed HTTP(S) pages, including loopback services."
kind: "package-reference"
---

# @nero/nero-client-ui-sidebar-browser

English | [中文](README.zh.md)

## Summary

Browse HTTP(S) pages, including loopback services, inside independent right-Sidebar tabs. Web uses an iframe with application-managed history; Desktop uses Electron `<webview>` with native navigation history and retained pages. The package never injects Electron or Node access into visited content.

This pane is also the Agent's browser: a mounted Host half publishes tools that navigate, read, script, capture, and observe the tabs a Session already shows, so a person watches the same pages the Agent reports.

## Table of Contents

- [Use this package](#use-this-package)
- [Understand the implementation](#understand-the-implementation)
- [Further Exploration](#further-exploration)
- [Model Experience](#model-experience)
- [Known Limitations and Deferred Work](#known-limitations-and-deferred-work)
- [Dev Note](#dev-note)

-----

<a id="use-this-package"></a>
## Use this package

Browser ships enabled in Web and Desktop profiles — Web runs the sandboxed iframe carrier, Desktop the Electron `<webview>` one — and a profile-patch override can still switch it off. Open **Browser** from the right-Sidebar guide and enter an HTTP(S) URL. Chat HTTP(S) links open here when the [link preference](../ui-chat/README.md) selects **In-App Sidebar**. A host name without a scheme becomes HTTPS. Public and loopback targets use the same default sandbox. Each guide action or delegated message-link activation creates another Browser tab.

### When to choose it

Choose Browser for a Web page that should remain beside the current Session. Choose [Document Preview](../ui-sidebar-documentpreview/README.md) for local files, and use the explicit external-browser action when a site refuses iframe embedding or needs browser capabilities this package withholds.

### Minimal configuration

The package has no plugin configuration. The shipped entry is enabled in every profile; a profile patch can still switch it off:

```yaml
- id: ui-sidebar-browser
  disabled: true
```

Client plugins can open a tab through `ctx.sidebarRight.openTab('browser', { params: { url } })`. The optional URL passes the same validation as address-bar input before navigation.

The toolbar provides Back, Forward, Reload, Go, and Open in system browser. Web also offers a per-tab sandbox toggle; disabling it is temporary and displays a warning. Desktop shows the observed page title. After a restart, Browser shows the saved title and URL; Restore or Reload opens that address only when requested.

### The Agent's browser

Three tools let a model work in this pane instead of a browser of its own: `browser_tab_open` places one tab for the calling Session and returns it, `browser_tab_list` reports every tab that Session owns, and `browser_tab` runs one command against a tab — `navigate`, `back`, `forward`, `reload`, `snapshot`, `evaluate`, `screenshot`, or `console`. Each request crosses the forwarded `sidebar-browser/request` waterfall, so only a connected client that owns the calling Session's tabs answers it, and the panel expands because content nobody can see is not opened. The Agent therefore reads and operates the same page a person has beside the Session, and a deployment with no connected client reports that refusal instead of opening a second browser.

Every reply names what the answering carrier can do for the loaded page. Desktop reads, scripts, observes console output, and captures any page. Web reads and scripts only a page on the application's own origin and never captures, because a document cannot rasterize the frame it embeds. `screenshot` commits the capture to the durable image store and returns it to the model as an image; a deployment without such a store reports the capture it could not store instead of returning an image the model cannot see.

-----

<a id="understand-the-implementation"></a>
## Understand the implementation

<details>
<summary>Implementation internals — click to expand</summary>

### Protocol policy

The address parser accepts HTTP and HTTPS, including loopback targets. It rejects `file:` URLs, script/data/blob input, embedded credentials, the NERO application origin, and malformed addresses. Document Preview owns local-file rendering.

### Iframe carrier

Web uses `sandbox="allow-scripts allow-forms allow-same-origin allow-popups allow-popups-to-escape-sandbox"` by default. The frame has no direct download or top-navigation flag. Popups leave the sandbox; in Web, an escaped popup retains its opener and can navigate the top-level application. The visited origin can use its own cookies and Web storage but a cross-origin target cannot read NERO DOM, storage, or API responses. The iframe sends no referrer and adds no package-owned Permissions Policy, so browser defaults and user grants apply. The toolbar can remove the sandbox for the current tab occurrence; the choice is not persisted. An unsandboxed page can navigate the top-level application under browser activation rules and use downloads, modal dialogs, and input locks. The package does not proxy or probe remote pages.

Web records toolbar submissions and typed tab opens. A navigation state machine treats the first iframe load for each controlled revision as known and a later load as proof that the page changed to an unreadable URL. In that unknown state the address is marked, Back, Forward, and external-open are disabled, and Reload returns to the last controlled URL. A remounted body reloads the latest application-known URL and uses its optional initial URL only before the first controlled target. History API and fragment changes that emit no iframe load remain invisible. An iframe `error` event displays a transient load-failure notice until the next controlled load without changing URL history.

### Controller

Each tab's `BrowserController` owns address validation, commands and explicit restoration. `BrowserFrame` supplies carrier-neutral navigation state; `IframeImpl` uses `BrowserNavigation`, while `ElectronWebViewImpl` observes Chromium history. `BrowserPresentation` owns physical DOM attachment. Slot injection supplies `useBrowserState` and plain callbacks, keeping provider objects and observables out of the React body.

Desktop's main process approves guest leases and enforces attachment, navigation and permission policy. Preload exposes only scoped Browser operations. Shared declarations use the standard `/types` export with `import type`; the Host and Client compile through separate tsconfig files. Desktop Browser tabs declare `keepMounted`, so Sidebar preserves their DOM across tab changes, Session switches, collapse and floating.

### Capture

A `<webview>` tag cannot rasterize the guest it embeds, so a capture request travels to the main process, which owns the guest's paint output: `capture` resolves the calling window's lease, refuses a guest that belongs to another window, that is detached, or that has rendered no page, and answers the page as base64 PNG. The renderer receives plain encoded bytes and reports `screenshot: true` for the carrier, which is what makes `browser_tab`'s `screenshot` command reachable on Desktop.

</details>

-----

<a id="further-exploration"></a>
## Further Exploration

- [Right Sidebar](../../../docs/subsystems/sidebar-right.md) — tab composition, navigation, and lifecycle.
- [Document Preview](../ui-sidebar-documentpreview/README.md) — local source, Markdown, images, HTML, and PDF rendering.
- [Sidebar Browser decision](../../../.agents/notes/implemented/feature/2026-09-16-sidebar-browser.md) — iframe behavior and controller ownership.
- [Desktop Browser decision](../../../.agents/notes/implemented/feature/2026-09-20-desktop-browser-webview.md) — webview leases, CWD storage grouping and manual restoration.

-----

<a id="model-experience"></a>
## Model Experience

Through the three Agent-facing tools above, whose results report the calling Session's tabs, the page's structured text, `evaluate` completion values, console records, and captures. A capture is committed as a durable image and reaches the model as an image block, while the recorded result carries the durable reference instead of the bytes. Browser pages themselves never enter a prompt, and the pane registers no prompt section.

#### KV Cache effect

The tools register once with the package, so the catalog and prompt prefix stay stable across Sessions. Navigation, page reads, and captures add no prompt text.

## Known Limitations and Deferred Work

<a id="known-limitations-and-deferred-work"></a>

The isolation policy deliberately gives up some browser compatibility:

- Many sites refuse iframe embedding or need downloads or top-level navigation withheld from the frame by the default sandbox. An HTTPS application can also block public HTTP pages as mixed content. Disabling the sandbox trades its restrictions for compatibility but does not bypass mixed-content or private-network policy. The unsandboxed frame can navigate the top-level application under browser activation rules and use downloads, modal dialogs, and input locks. It does not isolate the visited origin's cookies per Browser tab or prevent an in-frame page from choosing its own next URL.
- In Web, a popup that escapes the sandbox retains its opener and can use that chain to navigate the top-level application. Desktop handles popup creation separately.
- A later iframe load reveals that navigation occurred but not the new cross-origin URL. History API and fragment changes may remain invisible; Web Back and Forward are unavailable after the state becomes unknown.
- Browsers conceal many iframe failures for security: DNS, TLS, mixed-content, CSP, and `X-Frame-Options` failures may emit `load` or no actionable event instead of `error`. The load-failure notice is best-effort.
- Saved title and URL survive reloads and plugin unload while the tab remains in Sidebar's layout. Closing the tab removes its checkpoint. Restart restoration does not recover page memory, unsaved forms or Chromium's history stack.
- Local files are rejected and remain owned by Document Preview.
- Only Desktop captures the pane, and only while its guest has rendered a page. Web never captures, and a guest that is released, detached, or still loading refuses the request while naming that state rather than answering an empty image.
- Desktop shares process-local storage partitions by canonical workspace CWD; Sessions without a resolved Workspace are isolated separately. Cookies and Web storage do not survive application restart. Guest permissions, downloads and native popups are denied; approved HTTP(S) popup requests open Sidebar tabs. Host-address filtering is not a general private-network or DNS-rebinding firewall.

<a id="dev-note"></a>
### Dev Note

<details>
<summary>Working context for maintainers — click to expand</summary>

None.

</details>

**Runtime invariant:** No companion is published. Each navigation provider owns its live state and publishes checkpoints directly; the UI consumes the same provider state through its controller.
