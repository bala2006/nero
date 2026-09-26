---
description: "右侧 Sidebar 浏览器 tab：在 sandbox 中访问 HTTP(S) 页面，包括 loopback 服务。"
kind: "package-reference"
---

# @nero/nero-client-ui-sidebar-browser

[English](README.md) | 中文

## 概述

在独立的右侧 Sidebar tab 中浏览 HTTP(S) 页面，包括 loopback 服务。Web 使用 iframe 和应用维护的 history；Desktop 使用 Electron `<webview>`、原生导航 history 和保活页面。本包不会向被访问内容注入 Electron 或 Node 能力。

这个 pane 同时是 Agent 的浏览器：已挂载的 Host 一半发布工具，用于导航、读取、执行脚本、截图和观察 Session 已经展示的 tab，因此人看到的页面与 Agent 报告的页面是同一个。

## 目录

- [使用本包](#use-this-package)
- [了解实现](#understand-the-implementation)
- [延伸阅读](#further-exploration)
- [模型体验](#model-experience)
- [已知限制与延期工作](#known-limitations-and-deferred-work)
- [开发备注](#dev-note)

-----

<a id="use-this-package"></a>
## 使用本包

Browser 在 Web 与 Desktop profile 中默认启用——Web 使用 sandboxed iframe 载体，Desktop 使用 Electron `<webview>` 载体——profile patch 仍可显式关闭该条目。可以从右侧 Sidebar guide 打开 **浏览器**并输入 HTTP(S) URL。Chat 的[链接偏好](../ui-chat/README.zh.md)选择**应用内侧边栏**时，HTTP(S) 链接会在此打开。不带 scheme 的主机名会补全为 HTTPS。公共目标与 loopback 目标使用相同的默认 sandbox。每次 guide 操作或委托到此的消息链接操作都会创建一个新的 Browser tab。

### 何时选择

当 Web 页面需要保留在当前 Session 旁时，选择 Browser。本地文件使用 [Document Preview](../ui-sidebar-documentpreview/README.zh.md)；站点拒绝 iframe 嵌入或需要本包不授予的浏览器 capability 时，使用明确的外部浏览器操作。

### 最小配置

本包没有插件配置字段。随附条目在所有 profile 中默认启用；profile patch 仍可关闭它：

```yaml
- id: ui-sidebar-browser
  disabled: true
```

Client 插件可以调用 `ctx.sidebarRight.openTab('browser', { params: { url } })` 打开 tab。可选 URL 会在导航前接受与地址栏输入相同的校验。

工具栏提供后退、前进、刷新、前往和在系统浏览器中打开。Web 还提供逐 tab sandbox 开关；关闭它是临时选择，并会显示警告。Desktop 显示观察到的页面标题。重启后，Browser 展示保存的标题和 URL；只有点击恢复或刷新才打开该地址。

### Agent 的浏览器

三个工具让模型直接在这个 pane 中工作，而不需要自己的浏览器：`browser_tab_open` 为调用方 Session 放置一个 tab 并返回它，`browser_tab_list` 报告该 Session 拥有的全部 tab，`browser_tab` 对一个 tab 执行一条命令——`navigate`、`back`、`forward`、`reload`、`snapshot`、`evaluate`、`screenshot` 或 `console`。每个请求都走转发后的 `sidebar-browser/request` waterfall，因此只有拥有调用方 Session tab 的已连接 client 才会应答；面板会展开，因为无人能看到的内容不会被打开。Agent 读取和操作的因此就是人放在 Session 旁的同一个页面；没有已连接 client 的部署会报告该拒绝，而不会打开第二个浏览器。

每个回复都会说明应答载体对当前加载页面能做到什么。Desktop 可以读取、执行脚本、观察 console 输出并捕获任何页面。Web 只能读取和执行应用自身 origin 上的页面，且从不捕获，因为文档无法栅格化它嵌入的 frame。`screenshot` 会把捕获提交到持久图片存储，并作为图片返回给模型；没有该存储的部署会报告无法存储的捕获，而不会返回模型看不到的图片。

-----

<a id="understand-the-implementation"></a>
## 了解实现

<details>
<summary>实现细节——点击展开</summary>

### 协议策略

地址解析器接受 HTTP 与 HTTPS，包括 loopback 目标。`file:` URL、脚本/data/blob 输入、内嵌凭据、NERO 应用自身 origin 和畸形地址会被拒绝。本地文件由 Document Preview 负责渲染。

### Iframe 载体

Web 默认使用 `sandbox="allow-scripts allow-forms allow-same-origin allow-popups allow-popups-to-escape-sandbox"`。frame 没有直接的下载或顶层导航 flag。popup 会脱离 sandbox；在 Web 中，逃逸的 popup 会保留 opener，并可以导航顶层应用。被访问的 origin 可以使用自身 Cookie 与 Web storage，但跨域目标无法读取 NERO DOM、storage 或 API 响应。iframe 不发送 referrer，也不添加包自有的 Permissions Policy，因此浏览器默认策略与用户授权生效。toolbar 可以为当前 tab occurrence 移除 sandbox；该选择不持久化。未受 sandbox 约束的页面可以按浏览器 activation 规则导航顶层应用，并使用下载、模态对话框和输入锁定。本包不代理或探测远程页面。

Web 记录 toolbar 提交和 typed tab 打开。导航状态机把每个受控 revision 的第一次 iframe load 视为已知，把后续 load 视为页面已经变化到不可读取 URL 的证据。进入 unknown 状态后，地址会显示标记，后退、前进和外部打开会禁用，刷新则返回最后一个受控 URL。body 重挂载时会重新加载应用最后已知的 URL，并且仅在尚无受控目标时使用可选初始 URL。不产生 iframe load 的 History API 与 fragment 变化仍不可见。iframe `error` event 会显示临时加载失败 notice，直到下一个受控加载，但不会改变 URL history。

### Controller

每个 tab 的 `BrowserController` 负责地址校验、命令和显式恢复。`BrowserFrame` 提供与载体无关的导航状态；`IframeImpl` 使用 `BrowserNavigation`，`ElectronWebViewImpl` 观察 Chromium history。`BrowserPresentation` 负责 DOM 的物理挂载。Slot injection 提供 `useBrowserState` 和普通 callback，React body 不接收 provider 对象或 observable。

Desktop 主进程批准 guest 租约，并执行挂载、导航和权限策略。preload 只暴露限定范围的 Browser 操作。共享声明通过标准 `/types` 出口配合 `import type` 引入；Host 与 Client 使用独立 tsconfig 编译。Desktop Browser tab 声明 `keepMounted`，Sidebar 因而在切 tab、切 Session、收起与浮动期间保留其 DOM。

### 截图

`<webview>` tag 无法栅格化它嵌入的 guest，因此截图请求会送到拥有 guest 绘制输出的主进程：`capture` 解析调用窗口的租约，拒绝属于其他窗口的 guest、已分离的 guest、以及尚未渲染页面的 guest，并以 base64 PNG 返回页面。renderer 只拿到已编码的普通数据，并为该载体报告 `screenshot: true`，这也是 Desktop 上 `browser_tab` 的 `screenshot` 命令可用的原因。

</details>

-----

<a id="further-exploration"></a>
## 延伸阅读

- [右侧 Sidebar](../../../docs/subsystems/sidebar-right.zh.md)——tab composition、导航与生命周期。
- [Document Preview](../ui-sidebar-documentpreview/README.zh.md)——本地源码、Markdown、图片、HTML 与 PDF 渲染。
- [Sidebar Browser 决策](../../../.agents/notes/implemented/feature/2026-09-16-sidebar-browser.zh.md)——iframe 行为与 controller 所有权。
- [Desktop Browser 决策](../../../.agents/notes/implemented/feature/2026-09-20-desktop-browser-webview.zh.md)——webview 租约、CWD 存储分组与手动恢复。

-----

<a id="model-experience"></a>
## 模型体验

经由上述三个面向 Agent 的工具：其结果报告调用方 Session 的 tab、页面的结构化文本、`evaluate` 完成值、console 记录与截图。截图会提交为持久图片，并以 image block 送达模型；记录下来的结果只携带持久引用而不携带字节。浏览器页面本身不进入 prompt，本 pane 也不注册 prompt section。

#### KV Cache 影响

三个工具随本包一次性注册，因此 catalog 与 prompt 前缀在不同 Session 之间保持稳定。导航、页面读取与截图都不添加 prompt 文本。

## 已知限制与延期工作

<a id="known-limitations-and-deferred-work"></a>

隔离策略有意放弃部分浏览器兼容性：

- 很多站点拒绝 iframe 嵌入，或需要默认 sandbox 不向 frame 授予的下载与顶层导航。HTTPS 应用还可能按 mixed-content 策略阻止公共 HTTP 页面。关闭 sandbox 会用自身限制换取兼容性，但不会绕过 mixed-content 或 private-network 策略。未受 sandbox 约束的 frame 可以按浏览器 activation 规则导航顶层应用，并使用下载、模态对话框和输入锁定。该模式不会按 Browser tab 隔离被访问 origin 的 Cookie，也无法阻止 iframe 内页面自行选择后续 URL。
- 在 Web 中，逃逸出 sandbox 的 popup 会保留 opener，并可以通过该链导航顶层应用。Desktop 会单独处理 popup 创建。
- 后续 iframe load 能表明发生了导航，但无法给出新的跨域 URL。History API 与 fragment 变化可能仍不可见；状态变成 unknown 后，Web 的后退与前进不可用。
- 出于安全原因，浏览器会隐藏很多 iframe 失败：DNS、TLS、mixed-content、CSP 与 `X-Frame-Options` 失败可能触发 `load`，也可能不提供可操作 event，而不是触发 `error`。加载失败 notice 只能作为 best-effort 提示。
- 只要 tab 仍在 Sidebar 布局中，保存的标题和 URL 就会跨刷新与插件卸载保留。关闭 tab 会删除其检查点。重启恢复不恢复页面内存、未保存的表单或 Chromium history 栈。
- 只有 Desktop 能捕获 pane，且只在该 guest 已渲染出页面时。Web 从不捕获；已释放、已分离或仍在加载的 guest 会拒绝该请求并说明该状态，而不是返回一张空图片。
- Desktop 按规范化的工作区 CWD 共享进程内存储分区；没有解析到 Workspace 的 Session 单独隔离。Cookie 与 Web storage 不跨应用重启保留。guest 权限、下载与原生 popup 均被拒绝；通过检查的 HTTP(S) popup 请求会打开 Sidebar tab。Host 地址过滤不是通用私网或 DNS-rebinding 防火墙。

<a id="dev-note"></a>
### 开发备注

<details>
<summary>维护者工作上下文——点击展开</summary>

无。

</details>

**运行时不变量：** 不发布 companion。每个导航 provider 拥有自身的实时状态并直接发布检查点；UI 通过 controller 消费同一份 provider 状态。
