# Nero architecture

This document describes how the app is put together after the agentic-platform
work. It is the map to read before touching `lib/`.

## Layers

| Layer | Location | Responsibility |
| --- | --- | --- |
| App shell | `lib/app/` | Route table, navigation destinations, service container |
| Core kit | `lib/core/` | Theme, shared widgets, formatters — no feature imports |
| Features | `lib/features/<feature>/{domain,application,presentation}` | One feature per directory |
| Platform | `lib/platform/` | Drift database, file storage, native bridge |

`presentation` may import its own `application` and `domain`; `application` may
import `domain`; `domain` imports nothing from `presentation`. Features talk to
each other through `application` classes, never through widgets.

## Service container

`AppServices` (in `lib/app/app_services.dart`) is an `InheritedWidget` that owns
one instance of every app-lifetime service — settings, chat history, workspace,
audit log, native bridge, MCP registry — and disposes them together. Screens
resolve what they need with `AppServices.maybeOf(context)`, which returns null
outside the container so a screen can still be rendered standalone in a widget
test. [`NeroChatScreen`](lib/features/chat/presentation/nero_chat_screen.dart)
accepts the same services as optional constructor arguments for the same reason.

## Capability catalog

Tools used to be a compile-time `const` list. They are now a runtime merge:

```
CapabilityProvider  ──┐
  ├─ BuiltInProvider  │   CapabilityCatalog.instance
  ├─ McpCapabilityProvider ──►  (merged, de-duplicated by key)
  └─ (future providers) ┘            │
                                     ├─ modelToolNames()      → request tools
                                     └─ modelToolPayloads()   → tool schemas
```

A provider bumps its own revision and calls
`catalog.notifyProviderChanged(providerId)`; the catalog increments its
`revision`, which invalidates `ToolSelector`'s decision cache so newly enabled
tools are visible on the very next turn. `ToolRiskClassifier` and the approval
gate read the same catalog, so a tool's risk is derived from its declared
`sideEffectPolicy` rather than a hand-maintained name list.

## Run pipeline

```
ChatSessionController.sendPrompt
  ├─ ApprovalGate.request            (pauses here when a prompt is needed)
  ├─ RunCoordinator.runTurn
  │    ├─ RequestClassifier + SkillSelector + RunRouteSelector
  │    ├─ AgentOrchestrator.run      (bounded by RunBudget)
  │    │    ├─ ToolDispatcher.dispatch → ToolExecutionCoordinator
  │    │    │     ├─ ToolExecutorRegistry (mcp__*, future sandbox_*)
  │    │    │     └─ built-in tool switch
  │    │    └─ returns partial answer + stopReason when the budget runs out
  │    └─ persists RuntimeRun, RuntimeRunNode, RuntimeRunEvent rows
  └─ renders response, reasoning, artifacts
```

Every tool call — built-in or remote — goes through `ApprovalGate` first. When
the gate keeps a call, the returned future does not complete until the user
answers, so the agent loop is genuinely suspended; the UI shows an
`ApprovalCard` above the composer and the active task moves to
`AgentTaskStatus.waitingUser`.

Runs are bounded by the user's `RunBudget` (rounds, tool calls, wall clock).
Exhausting it returns the partial answer with a visible `stopReason` instead of
looping. The Runs screen can replay a recorded conversation run's prompt back
into the composer via `RunReplayBus`, which is how an interrupted or
budget-stopped run gets continued without re-typing.

## Reasoning

`AzureResponsesClient` sets `reasoning: {effort, summary}` on the request.
Without `reasoning.summary` the Responses API never emits
`response.reasoning_summary_text.delta`, which is why reasoning previously never
appeared. Deltas are accumulated by `ReasoningSession`
(`lib/features/chat/application/reasoning_session.dart`) into a
`ReasoningState` and rendered by `ReasoningBlock`. Tool status labels are routed
through the same object as phase captions, so a tool call no longer fabricates
reasoning text.

Chats persisted by older builds stored `thinkingSteps`; `ReasoningState`
converts them on load, so history keeps rendering.

## MCP

```
McpServersScreen ──► McpRegistry ──► McpClient ──► McpTransport
                        │                              ├─ StreamableHttp
                        │                              └─ Sse
                        ├─ McpServerStore   (JSON in app_metadata)
                        ├─ McpCapabilityProvider → CapabilityCatalog
                        └─ McpToolExecutor (ExternalToolExecutor for mcp__*)
```

Servers are remote only: Android cannot spawn stdio child processes. Tool
descriptions and JSON schemas from a server are **untrusted input that reaches
the model's prompt**, so everything passes through `sanitizeMcpText` and
`projectMcpInputSchema`, which strip control and zero-width characters, drop
injection-shaped sentences, and bound schema depth and breadth. Tool names are
namespaced as `mcp__<serverSlug>__<toolSlug>`. Binary content is written to the
workspace as an artifact instead of being pasted into the prompt as base64.

## Sandbox

```
NeroHomeShell ──► AppServices.sandboxController ──► SandboxRunner
     │                                                  └─ WebViewSandboxRunner
     └─ AppServices.sandboxWebViewHost                       (platform WebView)
```

The sandbox controller is app-lifetime and owned by `AppServices`; the shell
mounts its 1×1 off-screen WebView host once, next to the chat screen. That is
what lets the agent's `sandbox_run_code` tool execute while no sandbox screen is
open — a WebView only runs JavaScript while it is in the render tree, so a
caller can never mount and unmount its way around that constraint.

Two entry points share the controller: the Sandbox screen (user scratchpads,
policy editing, console panel) and `SandboxToolExecutor` (the agent, which runs
against transient sessions so it never clobbers a scratchpad mid-edit). Both go
through `SandboxController.runSession`, which records audit entries and reports
status.

`WebViewSandboxRunner` builds a self-contained document per run: the user's
source is embedded as a JSON string literal (with `</` escaped so it cannot
terminate the enclosing `<script>`), plus a shim that replaces `console.*`,
captures uncaught errors and promise rejections, and posts one JSON payload back
over a JavaScript channel. Permissions are deny-by-default and enforced by JS
shims.

Two honest constraints:

* Runs are strictly serialized: one WebView means one snippet at a time. A
  second concurrent request is declined rather than queued.
* The permission shims are defence in depth against a page, not a security
  boundary against a hostile binary. The sandbox isolates the page from Dart,
  the filesystem and the native bridge.

## Persistence

Structured, queryable data lives in Drift (`lib/platform/database/app_database.dart`,
schema v9) — conversations, messages, runs, nodes, events, memory entries,
semantic facts, audit entries. Small configuration blobs (advanced settings, MCP
servers and discovered tools, sandbox sessions and policy) are stored as JSON in
the `app_metadata` key/value table, so adding a preference never requires a
schema migration. Schema v9 renamed the settings row's legacy `sarvamApiKey`
column to `azureApiKey`; the migration copies the value across so no credential
is lost.

## Testing

`flutter analyze` must be clean. Tests live in `test/` mirroring `lib/`
(`test/mcp/`, `test/runtime/`, `test/chat/`…). CI shards the suite eight ways.
The widget kit in `lib/core/widgets` exists so screens can be tested without
duplicating chrome.
