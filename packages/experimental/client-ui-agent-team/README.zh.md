---
description: "使用并排查实验性 Web Agent Teams roster、共享任务板、Agent Swarm 卡片与单 teammate 聊天 tab。"
kind: "package-reference"
---

# @nero/nero-experimental-client-ui-agent-team

[English](README.md) | 中文

## 概述

本包把 Team 折叠为 Web 会话中的唯一 Agent Teams 方框，并把 Agent Canvas 作为右侧 Sidebar tab 打开：其中 Lead 位于其 teammate 上方，各自为一个圆角 node，由曲线 link 相连，点选 node 会打开该成员的 mini chat。canvas 通过生成的 `ctx.remote.agentTeams` contribution 读取当前 roster，分配 teammate 的 job role，并通过其实时会话向 teammate 发消息；Sidebar 聊天 tab 仍可排队一条持久直接消息，完整 teammate 会话仍在稳定 addressed-subagent 路径上一步可达。通过公开发布的实验性 Agent Teams bundle 选择本包。这个浏览器 projection 不扩展稳定 API Proxy、不存储 Team 状态，也不注册面向模型的输入。

## 目录

- [使用本包](#use-this-package)
- [理解实现](#understand-the-implementation)
- [进一步探索](#further-exploration)
- [模型体验](#model-experience)
- [已知限制与延期工作](#known-limitations-and-deferred-work)
- [开发备注](#dev-note)

-----

<a id="use-this-package"></a>
## 使用本包

通过 [`@nero/nero-experimental-agent-team-profile`](../agent-team-profile/README.zh.md) 启用本包。这个组合包同时提供团队服务、工具与 Web 界面。Web Client loader 挂载 `/client` export；root Host export 不执行行为，本包也没有用户配置字段。

### 打开 Agent Canvas

会话中的 Agent Teams 方框会打开 canvas tab，并读取 `agentTeams/view`。canvas 保持层级：Lead node 位于其 teammate 上方，每条曲线 edge 把 Lead 与一个 teammate 相连。每个 node 都是一张 agent 卡片：带角色味的头像、持久名称叠在 job role 之上、实时状态与一个菜单，下面是从该 teammate 自己的 Session 读出的六个指标格：已用上下文 / 路由窗口、计费 token、解码速度、所用模型、缓存命中率，以及清单中已完成的待办。这些数字来自 Session 列表行加上该 Session 的 projection baseline（获取时不打开其历史），因此绘制 node 绝不会激活 teammate；Session 尚未上报的项显示为不可用，较长的数值在悬停文本里保留完整形式。provisioning 和 running 成员使用共享 ongoing loading，inactive 成员使用 idle 灰点，failed 成员使用 error 红点。canvas 会把层级居中放在面板内，拖拽点状底面可平移。每张卡片按其设计尺寸的一半绘制，因此整个 Team 会呈现为总览视图，并可在此之上缩放：工具栏提供缩小、当前百分比与放大三个控件，Ctrl/Cmd + 滚轮以指针为中心缩放，双击底面把相机复位到 100% 的原位。mini window 不属于被缩放的 graph，因此保持自己的尺寸与可读性。Host 在打开历史时校验 parent、child 与 mode。

### 在 mini window 中编辑单个 agent

点选 node 会在 canvas 上方打开该成员的 mini window，默认停在 Chat tab，其中包含三个 tab：Edit Agent、Chat 与 Trajectory。Edit Agent 展示持久 agent 名称、不可修改的 Chat ID（即该成员的 Session id，附复制控件）、Role、System prompt、Response preference，以及可就地添加、改写、勾选和删除步骤的待办列表。Chat 嵌入该成员的实时会话，Trajectory 把同一 occurrence 投影为 trajectory 视图；窗口在三个 tab 下保持同一尺寸，因此切换 tab 不会改变窗口大小，比窗口更长的 transcript 在窗口内滚动。嵌入的会话会把自己的 composer、待办行与 usage 元数据一并带入窗口，因此在窗口内输入的消息就是发给该 agent Session 的消息；整个 occurrence 会按窗口更窄的宽度整体缩小渲染。该 composer 自带的 model selector 绑定 Agent，对 addressed teammate Session 已被拒绝，因此同一行位置改为以只读 chip 展示该 Session 绑定的模型，而不是让工具行完全没有模型；用户 prompt 也会占用窗口左侧的空余空间：气泡上限从 figma 的内容轴 70.2% 提升到 93.5%，用掉窗口此前留在 prompt 旁约一半的空带。拖拽窗口右下角可调整尺寸——向左上拖拽放大，共用下限停在 280×220，canvas 边缘则成为上限；双击该角会把窗口恢复为撑满 canvas 的默认尺寸。所有 tab 共用的这一尺寸会随 canvas 一同存储；在 canvas 空白处（不落在任何 node 上）点一下会关闭该窗口，而平移不算点击。离开这两个 tab 会释放对 child Session 的持有。`Open full conversation` 则根据其 Lead 与 roster 身份打开该 teammate 自己的 Sidebar 聊天 tab。

Role 下拉框列出公司的核心角色——engineering lead、software developer、game-architect、performance engineer、researcher、QA tester、designer、writer、code reviewer、security engineer、platform engineer、data engineer 与 product manager——每个角色都自带它默认使用的 system prompt。选择角色时就会提出该 prompt：空白的、或仍未被改动过的预设草稿会直接填入；而用户自己写过内容时绝不会被抛弃——面板会先询问，并提供 `Use the recommended prompt` 与 `Keep mine` 两个选择。草稿仍为空时，字段下方还会提供使用当前角色 prompt 的链接。角色 prompt 与 roster 数据一样属于可编辑内容，保持英文。

**Role 是目前 Host 唯一接管的 Edit Agent 字段。** 下拉框持久化一次 Lead 授权的 `updateMemberRole` 编辑；agent 名称、system prompt、response preference 与待办步骤都是浏览器本地草稿，因为 Team Remote 没有对应方法，窗口也会用 `Not yet persisted to the Host` 提示说明这一点。

### 在 transcript 中查看 Team

每条持久 `team/member` 记录都会折叠为同一个 Agent Teams 方框，因此 transcript 呈现的是团队本身，而不是每个 teammate 一行。方框展示持久 name 与 teammate 数量，点击即打开 canvas。teammate 的第一条持久记录是它的唯一 node start，即 provisioning 快照；settled `active` 快照以及后续 job-role 编辑更新同一成员，第二个 teammate 扩展同一个方框。

### 与单个 teammate 聊天

teammate 聊天 tab 是在右侧 Sidebar 打开的 `nero-resource://agentchat/session/…` address。它在该 tab 的生命周期内保留 teammate Session，并嵌入普通 embedded Conversation，因此用户读取实时 transcript，并通过主视图所用的同一稳定 composer 发送后续输入。在其上方，角色编辑器持久化一次 Lead 授权的 `updateMemberRole` 编辑，直接消息框则通过 `send` 排队一条持久 peer message。

### 任务板的位置

canvas 工具栏展示共享任务数量。Team agent 通过工具创建和更新任务，任务板本身不再属于这个 Web 表层。

-----

<a id="understand-the-implementation"></a>
## 理解实现

<details>
<summary>实现细节——点击展开</summary>

Client export 挂载来自 [`@nero/nero-experimental-agent-team/remote`](../agent-team/README.zh.md) 的生成的 `ctx.remote.agentTeams` contribution，然后通过 Cordis effect 注册 locale dictionary、一个右侧 Sidebar tab 类型及其正文与引导页入口、一个 Chat-node Definition 及其 keyed renderer，以及一个 teammate 聊天 tab 及其资源 provider 与 child slot。Dispose plugin fiber 会移除全部 registration。

挂载或刷新 canvas 会读取完整 Team view。并行刷新只保留最新响应，属于上一个 Session 的响应会被忽略。canvas 只根据 roster 布局 node，因此拖拽只移动一个 `transform`，不会重新读取任何内容；transcript 方框调用 `openTab`，因此每次点击只会打开一次，已打开的 tab 会被聚焦。

Agent Teams 方框是事件 Definition，而不是轮询视图：它匹配 `team/member`，以 provisioning 快照作为 start，并把后续成员记录折叠到同一个 node，因此一个方框承载整个 team。chat-node renderer 只消费折叠后的 payload，因此不会扫描 Session。聊天 tab 为 tab occurrence 持有自己的 Session reference，并在打开时读取一次 teammate roster row 来初始化角色编辑器。

| 文件 | 职责 |
|---|---|
| [`src/client/mount.ts`](src/client/mount.ts) | 生成的 Remote、locale、canvas、卡片与 tab registration |
| [`src/client/TeamPanel.tsx`](src/client/TeamPanel.tsx) | Agent Canvas 的 node、link、平移与多 tab mini window |
| [`src/client/team-panel.ts`](src/client/team-panel.ts) | Canvas tab 的 kind、id 与引导页入口 |
| [`src/client/swarm-card.ts`](src/client/swarm-card.ts) | 持久 `team/member` 折叠与 Chat-node Definition |
| [`src/client/SwarmCard.tsx`](src/client/SwarmCard.tsx) | Keyed Agent Swarm 卡片 renderer |
| [`src/client/agent-chat.tsx`](src/client/agent-chat.tsx) | teammate 聊天 tab、资源 provider、角色编辑器与消息框 |
| [`src/client/locales.ts`](src/client/locales.ts) | 中英文 panel、卡片与 tab 文案 |
| [`src/index.ts`](src/index.ts) | 不执行行为的 Host entry |

</details>

-----

<a id="further-exploration"></a>
## 进一步探索

- [Agent Teams bundle](../agent-team-profile/README.zh.md)——挂载本 Client plugin 的公开 opt-in bundle。
- [Agent Teams service](../agent-team/README.zh.md)——权威 roster、task 与 Remote 行为。
- [会话 UI](../../client/ui-conversation/README.zh.md)——稳定 header slot、addressed-subagent 导航与 Chat-node 表层。
- [右侧 Sidebar](../../client/ui-sidebar-right/README.zh.md)——聊天 tab 注册进入的 tab 类型注册表与导航表层。
- [实验性包](../README.zh.md)——孵化状态与发布规则。

-----

<a id="model-experience"></a>
## 模型体验

无直接影响，因为该浏览器 projection 不注册面向模型的输入。直接消息框与角色编辑器是仅用户可用的控件；接收方模型之后读取的 mailbox 框架由 Team service 负责。

#### KV Cache 影响

无直接影响；Team 工具与普通会话提交负责后续任何模型可见用途。

## 已知限制与延期工作

<a id="known-limitations-and-deferred-work"></a>

- **canvas 快照刷新**——canvas 在挂载和显式 refresh 时刷新；它没有实时事件订阅或 mailbox timeline。
- **没有缩放与 node 拖拽**——canvas 只能平移；node 位置来自 roster 层级，任务板不在此绘制。
- **mini window transcript**——Chat 与 Trajectory tab 会在窗口内把该 teammate 的实时会话及其 composer 作为一个整体缩小嵌入；`Open full conversation` 仍是在稳定 Sidebar 聊天 tab 上以完整宽度工作的方式。调整过尺寸的窗口会一直保持，直到 canvas 被缩得比它还小；不支持 `zoom` 的引擎会把该 occurrence 以原始尺寸渲染，而不会破坏盒模型。
- **聊天 tab 历史**——tab 嵌入普通 Conversation；角色编辑器在 tab 打开时读取一次 roster，不跟随后续 roster 变化。
- **没有 lifecycle 或 workspace control**——panel 不能 spawn、rename、delete 或 interrupt teammate，write scope 仍只是提示性 metadata。

<a id="dev-note"></a>
### 开发备注

<details>
<summary>维护者的工作上下文——点击展开</summary>

无。

</details>

**运行时不变式：** 不发布伴生入口。RPC 是权威来源，本包只持有可释放的 slot、tab、资源与事件注册。
