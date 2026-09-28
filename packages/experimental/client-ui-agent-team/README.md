---
description: "Use and debug the experimental Web Agent Teams roster, shared task board, Agent Swarm cards, and per-teammate chat tab."
kind: "package-reference"
---

# @nero/nero-experimental-client-ui-agent-team

English | [中文](README.zh.md)

## Summary

This package folds the Team into one Agent Teams box in the Web conversation and opens the Agent Canvas as a right-Sidebar tab, where the Lead sits above its teammates as rounded nodes joined by curved links and a node click opens that member's mini chat. The canvas reads the current roster through the generated `ctx.remote.agentTeams` contribution, assigns a teammate's job role, and messages a teammate through its live conversation; the Sidebar chat tab also queues a durable direct message, and a full teammate conversation remains one click away on the stable addressed-subagent path. Choose it through the published experimental Agent Teams bundle. The browser projection does not extend the stable API Proxy, store Team state, or register model-facing input.

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

Enable this package through [`@nero/nero-experimental-agent-team-profile`](../agent-team-profile/README.md), which supplies the Team service, tools, and Web UI together. The Web Client loader mounts the `/client` export; the root Host export is inert, and the package has no user configuration fields.

### Open the Agent Canvas

The Agent Teams box in the transcript opens the canvas tab, which reads `agentTeams/view`. The canvas keeps the hierarchy: the Lead node sits above its teammates, and one curved edge joins the Lead to each teammate. Each node is an agent card — a role-flavoured avatar, the durable name over its job role, its live status, and a menu — over six metric tiles read from that teammate's own Session: context used against the route's window, tokens billed, decode speed, the model it runs, cache-hit share, and completed to-dos out of its list. The figures come from the Session list row plus that Session's projection baseline (requested without opening its history), so a node never activates a teammate to draw itself; a fact the Session has not published yet reads as unavailable, and a long value keeps its exact form in the tile's hover text. Provisioning and running members use the shared ongoing loader, inactive members use idle, and failed members use error. The canvas keeps the hierarchy centered in the panel and pans by dragging its dotted ground. Every card is drawn at half its design size, so the whole Team reads as an overview, and the canvas zooms from there: the toolbar carries a step down, the current percentage, and a step up, Ctrl/Cmd with the wheel zooms about the pointer, and a double-click on the ground returns the camera home at 100%. The mini window is not part of the zoomed graph, so it stays at its own size and readability. The Host validates the parent, child, and mode when history opens.

### Edit one agent in its mini window

Selecting a node opens that member's mini window over the canvas, landing on the Chat tab, with three tabs: Edit Agent, Chat, and Trajectory. Edit Agent shows the durable agent name, the immutable Chat ID (the member's Session id, with a copy control), the Role, the System prompt, the Response preference, and a to-do list whose steps are added, retyped, checked off, and deleted in place. Chat embeds the member's live conversation and Trajectory shows the same occurrence as its trajectory view; the window keeps one size across all three tabs, so switching tabs never resizes it and a transcript longer than the window scrolls in place. The embedded conversation brings its own composer, to-do row, and usage metadata into the window, so a message typed there is a message to that agent's Session, and the whole occurrence renders scaled down to the window's smaller width. That composer's own model selector is Agent-bound and refused for an addressed teammate Session, so the same row position carries the model the Session is bound to as a read-only chip instead of standing in the tool row with no model at all, and a user prompt takes the window's spare left room: the bubble cap rises from the figma 70.2% of the content axis to 93.5%, which spends about half of the empty band the window used to leave beside a prompt. Dragging the window's bottom-right corner resizes it — a drag up and left grows it, the shared floor stops it at 280×220, and the canvas edge caps it — and double-clicking that corner returns the window to the canvas-sized default. The size every tab shares is stored with the canvas, and a tap on the empty canvas away from every node closes the window (a pan is not a tap). Leaving either tab releases the child Session hold. `Open full conversation` opens the teammate's own Sidebar chat tab from its Lead and roster identity.

The Role dropdown lists the core company roles — engineering lead, software developer, game-architect, performance engineer, researcher, QA tester, designer, writer, code reviewer, security engineer, platform engineer, data engineer, and product manager — and each one carries the system prompt that role starts from. Choosing a role offers that prompt: an empty or still-untouched preset draft is filled straight away, while a prompt the user wrote is never discarded — the tab asks first and offers `Use the recommended prompt` or `Keep mine`. A draft that is still empty also offers its own role's prompt as a link under the field. Role prompts are plain editable drafts, and they stay in English like every other piece of roster data.

**Role is the only Edit Agent field the Host owns today.** The dropdown persists a Lead-authorized `updateMemberRole` edit; the agent name, system prompt, response preference, and to-do steps are browser-local drafts because the Team Remote exposes no method for them, and the window says so with its `Not yet persisted to the Host` notice.

### See the Team in the transcript

Every durable `team/member` record folds into ONE Agent Teams box, so the transcript shows the team as it is provisioned rather than one row per teammate. The box carries the durable names and a teammate count, and clicking it opens the canvas. A teammate's first durable record is its provisioning snapshot, which is the unique node start; the settled `active` snapshot and any later job-role edit update the same member, and a second teammate extends the same box.

### Chat with one teammate

The teammate chat tab is a `nero-resource://agentchat/session/…` address opened in the right Sidebar. It retains the teammate Session for the tab's lifetime and embeds the ordinary embedded Conversation, so the user reads the live transcript and sends follow-ups through the same stable composer the main view uses. Above it, the role editor persists a Lead-authorized `updateMemberRole` edit and the direct-message box queues one durable peer message through `send`.

### Where the task board went

The canvas toolbar carries the shared task count. Team agents create and update tasks through their tools, and the task board itself is no longer part of this Web surface.

-----

<a id="understand-the-implementation"></a>
## Understand the implementation

<details>
<summary>Implementation internals — click to expand</summary>

The Client export mounts the generated `ctx.remote.agentTeams` contribution from [`@nero/nero-experimental-agent-team/remote`](../agent-team/README.md), then registers its locale dictionaries, one right-Sidebar tab type with its body and guide entry, one Chat-node Definition with its keyed renderer, and one teammate chat tab with its resource provider and child slot, all through Cordis effects. Disposing the plugin fiber removes every registration.

Mounting or refreshing the canvas reads the complete Team view. Overlapping refreshes keep the newest response, and responses for a previous Session are ignored. The canvas lays its nodes out from the roster alone, so a drag pans a `transform` and never re-reads anything; `openTab` is what the transcript box calls, so the tab is opened once per click and focused when it is already open.

The Agent Teams box is an event Definition, not a polled view: it matches `team/member`, starts on the provisioning snapshot, and folds later member records into the same node, so one box carries the whole team. The chat-node renderer consumes only the folded payload, so it never scans the Session. The chat tab keeps its own Session reference for the tab occurrence and reads the teammate's roster row once to seed the role editor.

| File | Role |
|---|---|
| [`src/client/mount.ts`](src/client/mount.ts) | Generated Remote, locale, canvas, card, and tab registrations |
| [`src/client/TeamPanel.tsx`](src/client/TeamPanel.tsx) | Agent Canvas nodes, links, panning, and the tabbed mini window |
| [`src/client/team-panel.ts`](src/client/team-panel.ts) | Canvas tab kind, id, and guide entry |
| [`src/client/swarm-card.ts`](src/client/swarm-card.ts) | Durable `team/member` fold and Chat-node Definition |
| [`src/client/SwarmCard.tsx`](src/client/SwarmCard.tsx) | Keyed Agent Swarm card renderer |
| [`src/client/agent-chat.tsx`](src/client/agent-chat.tsx) | Teammate chat tab, resource provider, role editor, and message box |
| [`src/client/locales.ts`](src/client/locales.ts) | English and Chinese panel, card, and tab copy |
| [`src/index.ts`](src/index.ts) | Inert Host entry |

</details>

-----

<a id="further-exploration"></a>
## Further Exploration

- [Agent Teams bundle](../agent-team-profile/README.md) — the published opt-in bundle that mounts this Client plugin.
- [Agent Teams service](../agent-team/README.md) — authoritative roster, task, and Remote behavior.
- [Conversation UI](../../client/ui-conversation/README.md) — the stable header slot, addressed-subagent navigation, and Chat-node surface.
- [Right Sidebar](../../client/ui-sidebar-right/README.md) — the tab-type registry and navigation face the chat tab registers into.
- [Experimental packages](../README.md) — incubation status and publication policy.

-----

<a id="model-experience"></a>
## Model Experience

None, as this browser projection registers no model-facing input. The direct-message box and role editor are user-only controls; the mailbox framing the recipient model later reads is owned by the Team service.

#### KV Cache effect

No direct effect; the Team tools and ordinary conversation submission own any later model-visible use.

## Known Limitations and Deferred Work

<a id="known-limitations-and-deferred-work"></a>

- **Canvas snapshot refresh** — the canvas refreshes on mount and explicit refresh; it has no live event subscription or mailbox timeline.
- **No zoom or node dragging** — the canvas pans only; node positions come from the roster hierarchy, and the task board is not drawn here.
- **Mini window transcript** — the Chat and Trajectory tabs embed the teammate's live conversation and its composer inside the window, scaled down as one piece; `Open full conversation` remains the way to work at full width on the stable Sidebar chat tab. A resized window keeps its size until the canvas is resized past it, and an engine without `zoom` renders the occurrence at full size rather than rescaling the box model.
- **Chat tab history** — the tab embeds the ordinary Conversation; the role editor reads the roster once when the tab opens and does not follow later roster changes.
- **No lifecycle or workspace controls** — the panel cannot spawn, rename, delete, or interrupt teammates, and write scopes remain advisory metadata.

<a id="dev-note"></a>
### Dev Note

<details>
<summary>Working context for maintainers — click to expand</summary>

None.

</details>

**Runtime invariant:** No companion is published. RPC is authoritative and the package owns only disposable slot, tab, resource, and event registrations.
