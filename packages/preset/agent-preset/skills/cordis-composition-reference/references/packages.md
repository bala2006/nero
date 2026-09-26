# Loadable Harness plugin packages

This file is GENERATED from workspace manifests (`scripts/gen-plugin-packages.ts`) and verified fresh by `pnpm run verify-plugin-packages` (part of `doc-sync`); do not edit it by hand.

Every package below exports a Cordis plugin that a bundle patch can name in a Loader row. `Config` marks packages whose row accepts a `config` mapping; query `Config.listConfigs` through `cordis_inspect_query` (filter by `name`, then query the `entry` id) for the mounted schema. Packages under `experimental` are pre-stable.

## acp

| Package | Config | Description |
|---|---|---|
| `@nero/nero-acp` | yes | Automation-only Agent Client Protocol server for driving Nero Harness agents over JSON-RPC stdio |

## api

| Package | Config | Description |
|---|---|---|
| `@nero/nero-api-account-controller` | no | Expose safe account operations over authenticated Remote |
| `@nero/nero-api-gateway` | yes | Typert Remote Host dispatcher and Client API endpoint |
| `@nero/nero-api-job-controller` | yes | Job Remote observation stream and the reference-counted client job-output service |
| `@nero/nero-api-remotes` | no | Remote BFF assembly for application-selected Host capabilities |
| `@nero/nero-api-session-controller` | yes | Session Remote commands, cold reads, and live control transport |
| `@nero/nero-api-settings-controller` | yes | Remote owner for the configuration surfaces over the settings-domain seams |
| `@nero/nero-api-terminal-controller` | yes | Session-owned interactive terminals with shell discovery, screen recovery and typed Remote control |
| `@nero/nero-api-workspace-controller` | yes | Workspace Remote commands and reconnect-safe state transport |
| `@nero/nero-api-workspace-files` | yes | Workspace file service and Client resource provider: bounded reads, directory listing, and live metadata over the workspaceFiles Remote namespace |

## attachment

| Package | Config | Description |
|---|---|---|
| `@nero/nero-attachment-local` | yes | Private content-addressed NERO_HOME attachment storage |

## boot

| Package | Config | Description |
|---|---|---|
| `@nero/nero-config-editor` | no | Persist plugin configuration through profile patches and Loader reconciliation |
| `@nero/nero-hmr` | yes | Coordinated module and profile configuration hot reload |
| `@nero/nero-plugin-manager` | yes | Current-profile plugin and bundle management shared by nero CLI, Web and agent tools |

## browser-use

| Package | Config | Description |
|---|---|---|
| `@nero/nero-browser-use` | no | Exclusive named browser-use provider registration |

## bundle

| Package | Config | Description |
|---|---|---|
| `@nero/nero-acp-app` | no | The nero ACP profile bundle: automation-only JSON-RPC stdio and process lifecycle over nero-base |
| `@nero/nero-headless` | yes | The nero one-shot bundle: a direct core Agent/Session runner over nero-base with no Host, HTTP, or browser layer |
| `@nero/nero-sdk-app` | yes | The nero SDK profile bundle: stdio JSON-RPC serving and process lifecycle over nero-base |
| `@nero/nero-web-app` | yes | The nero browser-surface bundle: the web patch layer over nero-base plus the runtime glue plugin (frontend dist serving, web-surface prompt, bash runtime variables, URL line) |

## client

| Package | Config | Description |
|---|---|---|
| `@nero/nero-client-connection` | yes | Authenticated RPC transport and generation lifecycle |
| `@nero/nero-client-file-upload` | no | Agent-scoped browser file upload, streaming intake, and staged receipt service |
| `@nero/nero-client-hmr` | yes | Web client graph synchronization and rebuilt-bundle reload transport |
| `@nero/nero-client-locale` | no | Locale plugin: Host-backed preference, extensible language catalog, browser fallback, and typed built-in dictionaries |
| `@nero/nero-client-modules` | no | Client module system, dual-face: node half composes the __NERO_BOOT__ entry graph (incremental nero.client scan, bundle route, index tap, webPlugins service); browser half is the lazy-CJS module table the vendored cordis Loader consumes as its internal seam |
| `@nero/nero-client-resources` | no | Unified client resource model: protocol-registered providers turn URL addresses into live values, consumed through the useResource global standard hook |
| `@nero/nero-client-ui-agent-preset` | no | Agent-preset surfaces: the default for later sessions, this session's seat, and the composition editor |
| `@nero/nero-client-ui-approval` | no | Approval composer takeover over the scoped Remote Event waterfall |
| `@nero/nero-client-ui-attachment` | no | Dynamic attachment presentation plugin for conversation input, message-image, and trajectory image slots |
| `@nero/nero-client-ui-brand-official` | no | Official Nero Harness brand occupants for the Web client's sidebar slots |
| `@nero/nero-client-ui-chat` | no | Chat Conversation target, node definitions, renderers, and details surface |
| `@nero/nero-client-ui-commands` | no | Client command surface: global directory cache, '/' source, three command UI kinds, popupSelect registry |
| `@nero/nero-client-ui-conversation` | no | Target-neutral Conversation assembly, shell, composer, queue, and view navigation |
| `@nero/nero-client-ui-deliverables` | no | Changed-files card with per-file comparison tabs, delivery cards, and clickable final-response file references for Web |
| `@nero/nero-client-ui-directory-picker-browse` | no | In-app directory browsing surface: the workspace directory-flow owner rendering the host's listing and creation primitives |
| `@nero/nero-client-ui-directory-picker-native` | no | Native directory-picker surface: the renderless workspace directory-flow occupant driving the local Desktop or Host OS chooser |
| `@nero/nero-client-ui-goal` | no | Session goal surface: GoalBar docked above the composer, read from the goal session projection |
| `@nero/nero-client-ui-input-trigger` | no | Input trigger pipeline: '/' and '@' detection, candidate menu, pick routing to registered sources |
| `@nero/nero-client-ui-jobs` | no | Session-header background-job list with on-demand streaming record panels |
| `@nero/nero-client-ui-layout` | no | Shell plugin: three-column AppFrame with drag handles, ctx.layout viewing-state service (navigation + panels) |
| `@nero/nero-client-ui-message-feedback` | no | The Web feedback surface: per-message Like/Dislike in the assistant-message action strip and the feedback dialog behind both ratings and /feedback, backed by the messageFeedback and sessionFeedback Host Remotes |
| `@nero/nero-client-ui-model-selection` | no | Model selection over the shared model catalog, Session projection, and session.selectModel |
| `@nero/nero-client-ui-open-in-app` | no | Web "Open In..." controls: the Session-header split button opening the workspace directory in an installed application, and the document preview's default-application controls for one file |
| `@nero/nero-client-ui-permission-presets` | no | Permission surfaces: a new-session default in General settings and a current-session /permission popup over the permissions projection |
| `@nero/nero-client-ui-plan` | no | Plan mode controls, persistent transcript plan cards, and sidebar Markdown previews |
| `@nero/nero-client-ui-plugin-manager` | yes | Plugin management for the nero web client: the sidebar Plugins panel installs, enables, disables, retries, and composes installed plugin packages |
| `@nero/nero-client-ui-reference` | no | Unified Web @file and @session reference source |
| `@nero/nero-client-ui-renderer` | no | Browser UI renderer: React slot bindings, ctx.uiRenderer, and the assembled application root |
| `@nero/nero-client-ui-schedule` | no | Read-only active Schedule catalog in the Web Session header |
| `@nero/nero-client-ui-session` | no | Session Controller adapter for React and session-scoped slots |
| `@nero/nero-client-ui-settings` | no | Settings domain base plugin: shared configuration forms and the canonical settings slot-type contract |
| `@nero/nero-client-ui-settings-account` | yes | Manage Nero login and open Platform billing pages |
| `@nero/nero-client-ui-settings-agent-loop` | no | Settings page of the agent loop on the nero web client's Plugins page: the parallel tool-call cap of the agent-loop namespace |
| `@nero/nero-client-ui-settings-general` | no | Settings ownerless-copy and product onboarding plugin: the General section, shell trigger/header chrome content, settings dictionaries, and the versioned welcome notice |
| `@nero/nero-client-ui-settings-models` | yes | Models settings and shared product-onboarding dialogs over existing settings and credential joins |
| `@nero/nero-client-ui-settings-plugin-inventory` | no | Read-only Cordis Loader inventory tab in Web Plugins settings |
| `@nero/nero-client-ui-settings-plugins` | no | Built-in plugins settings section for the nero web client: the Settings navigation entry and the tab chrome feature-owned tabs register into |
| `@nero/nero-client-ui-settings-shell` | no | Settings page of the shell executor on the nero web client's Plugins page: the command timeout and the per-stream output cap of the shell namespace |
| `@nero/nero-client-ui-settings-subagent` | no | Settings page of Subagent delegation on the nero web client's Plugins page: recursion depth, parallel capacity, and the models agents may choose for subagents |
| `@nero/nero-client-ui-settings-web-search` | no | Settings page of the Nero web-search provider on the nero web client's Plugins page: its API key, endpoint, and per-request search budget |
| `@nero/nero-client-ui-sidebar` | no | Sidebar plugin: session multi-level tree, search, grouping, state dots |
| `@nero/nero-client-ui-sidebar-browser` | no | Sandboxed Web browser tabs for the right Sidebar |
| `@nero/nero-client-ui-sidebar-documentpreview` | yes | Extensible Sidebar previews for Office documents, spreadsheets, Markdown, code, images, PDF, HTML, and plain text |
| `@nero/nero-client-ui-sidebar-files` | no | Workspace file tree tab type for the right Sidebar: lazy directory listing over the workspaceFiles Remote namespace, opening files into the Sidebar |
| `@nero/nero-client-ui-sidebar-right` | no | Right Sidebar: the docking surface's session-bound state, its panel and header expand control, and the navigation service over it |
| `@nero/nero-client-ui-sidebar-terminal` | no | Interactive shell tabs for the right Sidebar |
| `@nero/nero-client-ui-skill` | no | Web skill references and the dedicated skill tool row |
| `@nero/nero-client-ui-subagent` | no | Subagent conversation catalog, continuation routing UI, and '@' reference source |
| `@nero/nero-client-ui-theme` | yes | Theme plugin: Host bootstrap for the pre-plugin palette; DOM-free ThemeRuntime for light/dark/system state; --dsw-* token styles and Appearance settings row |
| `@nero/nero-client-ui-tool` | no | Client Tool call-tree renderer and keyed per-tool presentation slot |
| `@nero/nero-client-ui-trajectory` | no | Trajectory event ledger with an interactive timing overview: pure-consumer plugin registering into the conversation ViewMap (no service) |
| `@nero/nero-client-ui-user-questions` | no | Web ask_user_question composer takeover and plan-review presentation UI |
| `@nero/nero-client-ui-workflow-run` | no | Durable workflow-run Conversation Node and nested member disclosure for nero web |
| `@nero/nero-client-ui-workspace` | no | Workspace picker plugin: one WorkspacePicker registered into the sidebar and empty-state workspace slots |

## compaction

| Package | Config | Description |
|---|---|---|
| `@nero/nero-command-compact` | no | Human-facing slash command for explicit session compaction |
| `@nero/nero-compaction-basic` | yes | Token-meter-driven compaction policy and LLM summarization backend for the Nero Harness |
| `@nero/nero-compaction-image-offload` | no | Durable image offload for image-capable routes: replace over-budget request images with placeholders and retry |
| `@nero/nero-compaction-tool-result-pruner` | yes | Replay-safe model-free head/middle/tail pruning for tool-result surface nodes |

## computer-use

| Package | Config | Description |
|---|---|---|
| `@nero/nero-computer-use` | no | Exclusive named computer-use provider registration |

## context

| Package | Config | Description |
|---|---|---|
| `@nero/nero-agent-instructions` | yes | Workspace context loader for AGENTS.md/CLAUDE.md instruction files |
| `@nero/nero-file-reference-local` | yes | Local-filesystem ctx.fileReferences provider with bounded fuzzy indexes |
| `@nero/nero-session-reference` | yes | Cross-session snapshot references and durable untrusted model context (ctx.sessionReferenceResolver) |
| `@nero/nero-time-context` | yes | Opt-in durable per-step context with the current time and elapsed time |
| `@nero/nero-tmux-context` | yes | Opt-in durable per-step context with this agent's tmux pane and window location |

## core

| Package | Config | Description |
|---|---|---|
| `@nero/nero-agent` | no | Agent interface, registry, initiator scope, and event vocabulary for the Nero Harness |
| `@nero/nero-agent-default-model` | yes | Default model selection shared by Agent entry points |
| `@nero/nero-agent-loop` | yes | The concrete agent loop plugin for the Nero Harness |
| `@nero/nero-agent-tool-presentation` | yes | Agent-plane presentation selector: composes one agent's tools as PTC mode, native, or both |
| `@nero/nero-session` | no | Event-sourced session store for the Nero Harness |
| `@nero/nero-system-prompt` | yes | System prompt assembly registry for the Nero Harness |
| `@nero/nero-tools` | yes | Tool registry and execution pipeline for the Nero Harness |

## credentials

| Package | Config | Description |
|---|---|---|
| `@nero/nero-authorization` | no | Authorization seam (ctx.authorization): plugin-owned flows that obtain a credential through a conversation with the human |
| `@nero/nero-credentials-local` | yes | File-backed credentials provider ($NERO_HOME/.env under the live process environment) for the Nero Harness |
| `@nero/nero-nero-account-platform` | yes | Authorize Nero accounts through browser PKCE |

## deliverables

| Package | Config | Description |
|---|---|---|
| `@nero/nero-tool-present` | yes | Explicit workspace file delivery declarations for the Nero Harness |
| `@nero/nero-workspace-changes` | yes | Per-turn workspace file changes recorded from git working-tree snapshots and whole-file captures, with per-file comparisons, for the Nero Harness |

## document

| Package | Config | Description |
|---|---|---|
| `@nero/nero-office-to-pdf` | yes | Shared Office-to-PDF conversion with bounded queues and caching |

## experimental

| Package | Config | Description |
|---|---|---|
| `@nero/nero-experimental-agent-team` | yes | Implicit-root Agent Teams roster, durable peer mailbox, and shared task DAG |
| `@nero/nero-experimental-api-speech-to-text` | yes | Authenticated experimental speech transcription for browser clients |
| `@nero/nero-experimental-auto-review` | no | Per-tool LLM authorization review for the Nero Harness Auto permission preset |
| `@nero/nero-experimental-browser-use-chrome-devtools-mcp` | yes | Experimental per-Session Chromium browser tools through chrome-devtools-mcp |
| `@nero/nero-experimental-browser-use-playwright-mcp` | yes | Experimental per-Session Chromium browser tools through @playwright/mcp |
| `@nero/nero-experimental-browser-use-stagehand-native` | yes | Experimental Stagehand browser tools with separately configured native models |
| `@nero/nero-experimental-client-ui-agent-team` | no | Web Agent Teams roster, task board, and teammate navigation |
| `@nero/nero-experimental-client-ui-voice-input` | no | Record speech and insert editable text into the conversation draft |
| `@nero/nero-experimental-computer-use-cua-driver-mcp` | yes | Experimental computer use through an installed Cua Driver MCP executable |
| `@nero/nero-experimental-computer-use-cua-driver-native` | no | Experimental computer-use provider embedding the Cua Driver native npm SDK |
| `@nero/nero-experimental-inspector` | yes | Experimental cross-realm CDP hub for Host debugging and Client Runtime inspection |
| `@nero/nero-experimental-ptc-runtime-python` | yes | CPython subprocess implementation of the Nero Harness PTC execution seam |
| `@nero/nero-experimental-speech-to-text` | yes | Experimental speech recognition with independently selectable providers |
| `@nero/nero-experimental-speech-to-text-sensevoice` | yes | Local SenseVoice ONNX transcription with a managed sherpa-onnx process |
| `@nero/nero-experimental-tool-agent-team` | yes | Scoped model-facing Agent Teams tools over ctx.agentTeams |

## extensions

| Package | Config | Description |
|---|---|---|
| `@nero/nero-client-ui-cordis` | no | Cordis dynamic-plugin definition card: the keyed cordis_define tool row with its run/stop switch |
| `@nero/nero-cordis-client-runner` | no | Browser half of dynamic dual-half plugin packages: event subscription, closure evaluation, guard facade, and loader entries |
| `@nero/nero-cordis-host-runner` | yes | Dynamic package definition registry, host-half sandbox lifecycle, and invoke handler table for model-mounted dual-half packages |
| `@nero/nero-tool-cordis` | no | Read-only runtime API inspection for Harness plugin development |

## feedback

| Package | Config | Description |
|---|---|---|
| `@nero/nero-command-feedback` | no | Log-only session feedback: the record event, the sessionFeedback Host Remote, and the human-facing slash command |
| `@nero/nero-message-feedback` | yes | Canonical Session-log ratings and notes for finalized assistant messages |

## fs

| Package | Config | Description |
|---|---|---|
| `@nero/nero-fs-local` | yes | Local-filesystem implementation of the Nero Harness filesystem seam (ctx.fs) |
| `@nero/nero-fs-observation-policy` | no | File-context policy plugin for the Nero Harness — observed-state, read-before-edit, and version-guarded write/edit added over the ctx.fs provider seam through the fs/* event gate (no service API) |
| `@nero/nero-fs-sandbox` | yes | Sandbox-enforcing implementation of the Nero Harness filesystem seam: fences write/edit by the per-call sandbox mode (read-only denies mutation, workspace-write contains it to the workspace + temp roots) while reads pass through |
| `@nero/nero-tool-fs` | yes | Model-facing filesystem tools (read, write, edit) over the Nero Harness filesystem seam (ctx.fs) |
| `@nero/nero-tool-fs-search` | yes | Model-facing filesystem discovery tools (glob, grep) backed by the packaged ripgrep binary (@vscode/ripgrep) |
| `@nero/nero-tool-str-replace-editor` | yes | Model-facing view, create, literal replace, and line insert tool over the Harness filesystem service |

## goal

| Package | Config | Description |
|---|---|---|
| `@nero/nero-command-goal` | no | Human-facing slash command for persisted same-session goals |
| `@nero/nero-goal` | yes | Event-sourced same-session goal state and lifecycle service for the Nero Harness |
| `@nero/nero-goal-round-driver` | no | Race-fenced same-session goal-round driver |
| `@nero/nero-tool-goal` | yes | Model-facing same-session goal tools with execution-time authority checks |

## guard

| Package | Config | Description |
|---|---|---|
| `@nero/nero-repeat-tool-reminder` | yes | Repeat-tool-call guard plugin: advisory reminders when an agent loops on identical tool calls |
| `@nero/nero-tool-call-timeout-policy` | no | Tool-call timeout policy: a tools/execute wrapper that arms a per-tool deadline on exec.signal and returns TOOL_TIMEOUT when it wins |

## hooks

| Package | Config | Description |
|---|---|---|
| `@nero/nero-hooks-claude-code` | yes | Bridge plugin: run a Claude Code hooks.json / settings hook config on the Nero Harness interception seams |
| `@nero/nero-hooks-codex` | yes | Bridge plugin: run a Codex hooks.json hook config on the Nero Harness interception seams |

## host

| Package | Config | Description |
|---|---|---|
| `@nero/nero-host-directory-picker-auto` | no | Adaptive chooser of the directory-picker seam: resolves the host situation at boot and mounts the native or browse backend for the Nero Harness web GUI host |
| `@nero/nero-host-directory-picker-browse` | yes | In-app browsing backend of the directory-picker seam (listing/creation primitives over the host filesystem) |
| `@nero/nero-host-directory-picker-native` | no | Native-OS-chooser backend of the directory-picker seam for the Nero Harness web GUI host |
| `@nero/nero-host-frontend-static` | yes | SPA dist server for the Web shell: owns the webserver fallback seat, serving explicit index entries and static assets with traversal rejection and 404 misses |
| `@nero/nero-host-open-in-app` | yes | Host half of open-in-app: resolved application catalog, icons, and the launch endpoint as three webServer routes |
| `@nero/nero-host-plugin-inventory` | no | Read-only Remote projection of current Cordis Loader plugin state |
| `@nero/nero-host-product-telemetry-otel` | yes | Explicit product usage events exported through OpenTelemetry HTTP logs |
| `@nero/nero-host-webserver` | yes | Web route-registration plugin: HTTP and upgrade routes, index transform taps, and static dist fallback; knows no harness concepts |

## interaction

| Package | Config | Description |
|---|---|---|
| `@nero/nero-commands` | no | Plugin-owned human command registry for Nero Harness UIs |
| `@nero/nero-permission-presets` | yes | User-facing permission presets (ctx.permissionPresets) for the Nero Harness: one product-level Permissions select bundling the sandbox-mode and approval-policy knobs, written through to their own session events |
| `@nero/nero-tool-ask-user` | no | Model-facing ask_user_question tool over the ctx.userQuestions seam |
| `@nero/nero-user-approval` | yes | User-approval seam (ctx.approval) for the Nero Harness: one-shot permission decisions dispatched to composed answerers over the approval/request waterfall, fail-closed by default |
| `@nero/nero-user-questions` | no | Abstract user-questions seam (ctx.userQuestions) for asking the human during agent runs |

## jobs

| Package | Config | Description |
|---|---|---|
| `@nero/nero-jobs-local` | yes | Process-local implementation of the Nero Harness background job registry seam |
| `@nero/nero-tool-jobs` | yes | Model-facing background job control tools (job_output, job_list, job_kill) over the ctx.jobs registry |

## llm

| Package | Config | Description |
|---|---|---|
| `@nero/nero-llm` | no | Provider-neutral LLM service interface for the Nero Harness |
| `@nero/nero-llm-nero` | yes | Nero Messages adapter |
| `@nero/nero-llm-pi-ai` | yes | pi-ai-backed Nero adapter for the Nero Harness LLM seam (design-verification twin of nero-llm-nero) |
| `@nero/nero-llm-retry` | yes | Provider-routed LLM request retry policy for the Nero Harness |
| `@nero/nero-nero-llm-api-extensions` | no | Additive request-field registry for the official Nero LLM API adapter |
| `@nero/nero-plugin-package-inventory-nero` | yes | Active Loader-backed plugin package inventory for official Nero LLM API requests |
| `@nero/nero-token-meter` | yes | Replay-aware token measurement service (ctx.tokenMeter) for the Nero Harness |

## lsp

| Package | Config | Description |
|---|---|---|
| `@nero/nero-lsp` | no | Abstract LSP capability seam (ctx.lsp) for the Nero Harness — language-server provider registry keyed by branded id and extension mapping, order-independent per-query selection, normalized definition/references/implementation/hover requests and results, and the LspError taxonomy |
| `@nero/nero-lsp-stdio` | yes | Generic stdio language-server provider for the Nero Harness LSP capability seam (ctx.lsp) — spawns configured servers, translates JSON-RPC, and serves transient-open goToDefinition/findReferences/goToImplementation/hover queries in the host filesystem namespace |
| `@nero/nero-tool-lsp` | yes | Model-facing lsp tool over the Nero Harness LSP capability seam (ctx.lsp) — one read-only tool with goToDefinition/findReferences/goToImplementation/hover operations, one-based UTF-16 cursor coordinates, bounded location rendering, and hover normalization |

## mcp

| Package | Config | Description |
|---|---|---|
| `@nero/nero-mcp-client` | yes | MCP client bridge: connects to MCP servers and registers their tools on ctx.tools |
| `@nero/nero-mcp-resources` | no | Scoped MCP resource discovery and reading through shared model tools |

## plan

| Package | Config | Description |
|---|---|---|
| `@nero/nero-plan-mode` | yes | Logged per-agent plan mode with deployment guidance, a direct slash command, and a user-reviewed exit |

## preset

| Package | Config | Description |
|---|---|---|
| `@nero/nero-agent-preset` | yes | Declare an Agent capability composition in Cordis YAML |
| `@nero/nero-agent-preset-registry` | yes | Declarative Agent preset registry and profile-backed editing |
| `@nero/nero-persona` | yes | Composition-authored deployment persona section for the Nero Harness |

## ptc-runtime

| Package | Config | Description |
|---|---|---|
| `@nero/nero-ptc-runtime-node` | yes | Sandboxed Node process implementation of the Nero Harness PTC execution capability |

## runtime-diagnostics

| Package | Config | Description |
|---|---|---|
| `@nero/nero-invariants` | yes | Registry service for package-owned Nero Harness runtime invariants |

## sandbox

| Package | Config | Description |
|---|---|---|
| `@nero/nero-sandbox-local` | yes | Local process-sandbox backends for the Nero Harness sandbox seam: bwrap, the npm-distributed landlock-run launcher, macOS Seatbelt, or the Windows ACL restricted-token runner — functionally probed, fail-closed |
| `@nero/nero-sandbox-policy` | yes | Per-call sandbox policy resolver and current model context: deployment fallbacks plus each session's mode and workspace root, shared by every enforcing capability family |

## schedule

| Package | Config | Description |
|---|---|---|
| `@nero/nero-schedule` | no | Agent-scoped durable after, at, and fixed-rate reminders over the session event log |

## sdk

| Package | Config | Description |
|---|---|---|
| `@nero/nero-sdk-jsonrpc-server` | yes | Stdio JSON-RPC server plugin for out-of-process Nero Harness SDK clients |

## session

| Package | Config | Description |
|---|---|---|
| `@nero/nero-session-checkpoint-policy` | no | Semantic session durability checkpoints before model requests and tool side effects |
| `@nero/nero-session-log-nero` | yes | Incremental lossless session-log request extension for the official Nero LLM API |
| `@nero/nero-session-persistence-jsonl` | yes | JSONL durable session persistence backend for the Nero Harness |
| `@nero/nero-session-projection` | no | Session-projection seam: the merge-extensible projection type table, the provider contract, and the ctx.sessionProjections registry serving whole current values of log-derived per-session state |
| `@nero/nero-session-projection-cache` | yes | Persisted projection cache (ctx.sessionProjectionCache): durable per-session checkpoint records on the session_projcache storage domain (per-record layout), throttled write-behind, and the cached listing read |
| `@nero/nero-session-stats` | no | Whole-log conversation counts and wall times projection (sessionStats) for the Nero Harness |
| `@nero/nero-session-telemetry-otel` | yes | OpenTelemetry backend for the Nero Harness telemetry seam: hands captured session records to the OTel JS SDK's log pipeline |
| `@nero/nero-session-title` | yes | Log-backed session title service and provider registry for the Nero Harness |
| `@nero/nero-session-title-all-prompts-llm` | yes | All-user-messages LLM provider plugin for Nero Harness session titles |
| `@nero/nero-session-title-first-prompt-llm` | yes | First-message LLM provider plugin for Nero Harness session titles |
| `@nero/nero-session-turn-outline` | no | Whole-log turn outline projection (turnOutline) for the Nero Harness |

## session-query

| Package | Config | Description |
|---|---|---|
| `@nero/nero-session-log-export` | yes | Web Session-log export command and shared download dialog |
| `@nero/nero-session-query-sqlite` | yes | Concrete ctx.sessionQuery backend with SQLite FTS5 search |
| `@nero/nero-tool-session-query` | yes | Workspace-authorized model-facing session history search, trace, and event read tools |

## settings

| Package | Config | Description |
|---|---|---|
| `@nero/nero-settings` | no | Abstract user-settings seam (ctx.settings) for the Nero Harness |

## shell

| Package | Config | Description |
|---|---|---|
| `@nero/nero-bash-local` | yes | Local-subprocess implementation of the Nero Harness bash executor seam |
| `@nero/nero-bash-sandbox` | yes | Sandbox-consuming implementation of the Nero Harness bash executor seam (confines every command via ctx.sandbox, reports denial/enforcement result facts) |
| `@nero/nero-pwsh-local` | yes | Local PowerShell implementation of the Nero Harness bash executor seam |
| `@nero/nero-pwsh-sandbox` | yes | Sandbox-consuming implementation of the Nero Harness PowerShell executor seam (confines every command via ctx.sandbox, reports denial/enforcement result facts) |
| `@nero/nero-shell-env` | yes | Tool-independent managed NERO_* shell environment registry |
| `@nero/nero-tool-bash` | yes | Model-facing bash tool with optional generic background-job and sandbox-escalation support |
| `@nero/nero-tool-bash-persistent` | yes | Model-facing owner-scoped persistent Bash tool backed by the Harness PTY service |
| `@nero/nero-tool-pwsh` | yes | Model-facing pwsh tool over the bash executor seam |
| `@nero/nero-tool-pwsh-persistent` | yes | Model-facing owner-scoped persistent PowerShell tool backed by the Harness PTY service |

## skill

| Package | Config | Description |
|---|---|---|
| `@nero/nero-skill` | yes | Agent skill provider registry for the Nero Harness |
| `@nero/nero-skill-badge` | no | Bundled nero badge skill provider for Nero Harness |
| `@nero/nero-skill-filesystem` | yes | Local filesystem skill provider for the Nero Harness |
| `@nero/nero-skill-office` | yes | Bundled Word, PowerPoint, and Excel workflows and structural checks |
| `@nero/nero-tool-skill` | yes | Model-facing skill loading tool for the Nero Harness |
| `@nero/nero-tool-workspace-dependencies` | yes | The load_workspace_dependencies tool: absolute paths into a bundled Python, Node.js, and pnpm payload |

## spill

| Package | Config | Description |
|---|---|---|
| `@nero/nero-spill-local` | yes | Local-filesystem implementation of the Nero Harness spill storage seam (private session-scoped files) |
| `@nero/nero-spill-policy` | yes | Token-budgeted tool-result retention with recoverable text and image paths |

## ssh

| Package | Config | Description |
|---|---|---|
| `@nero/nero-fs-ssh` | no | Filesystem provider over the shared POSIX SSH helper |
| `@nero/nero-sandbox-ssh` | no | Remote POSIX sandbox argv provider over the shared SSH helper |
| `@nero/nero-ssh` | yes | Shared OpenSSH connection and versioned POSIX remote helper |
| `@nero/nero-subprocess-ssh` | no | Subprocess and terminal provider over the shared POSIX SSH helper |

## storage

| Package | Config | Description |
|---|---|---|
| `@nero/nero-storage` | no | Storage hub (ctx.storage): named backend registry plus mounted data-form facilities for the Nero Harness |
| `@nero/nero-storage-domain` | yes | Domain data form (ctx.storage.domain): schema-validated, event-emitting KV domains over storage backends for the Nero Harness |
| `@nero/nero-storage-json` | yes | JSON file KV storage backend for the Nero Harness storage hub |
| `@nero/nero-storage-sqlite` | yes | SQLite storage backend (kv facet) for the Nero Harness storage hub |

## subagent

| Package | Config | Description |
|---|---|---|
| `@nero/nero-subagent` | yes | Abstract subagent seam (ctx.subagents): named-provider registry for delegating to child agents |
| `@nero/nero-subagent-acp` | yes | Out-of-process ACP subagent backend: drives a child agent in a spawned subprocess over the Agent Client Protocol |
| `@nero/nero-subagent-claude-code` | yes | One-shot Claude Code subagent provider over the official Agent SDK |
| `@nero/nero-subagent-codex` | yes | One-shot Codex subagent provider over the official app-server protocol |
| `@nero/nero-subagent-fork-in-process` | yes | In-process fork subagent backend: runs a child agent seeded with a prefix of the parent's log |
| `@nero/nero-subagent-nero-sdk` | yes | Out-of-process SDK subagent backend: drives a child Nero Harness runtime subprocess over stdio JSON-RPC through the TypeScript SDK client |
| `@nero/nero-subagent-spawn-in-process` | yes | In-process spawn subagent backend: runs a fresh child agent on ctx.agents |
| `@nero/nero-tool-subagent` | yes | Model-facing subagent delegation tool over the ctx.subagents seam |
| `@nero/nero-tool-subagent-control` | no | Globally named send_message, interrupt_agent, and list_agents tools over ctx.subagents continuations |

## subprocess

| Package | Config | Description |
|---|---|---|
| `@nero/nero-subprocess-local` | no | Local-subprocess implementation of the Nero Harness subprocess seam |

## terminal

| Package | Config | Description |
|---|---|---|
| `@nero/nero-terminal` | no | Persistent PTY session seam for the Nero Harness — owner-scoped ids, backend registry, interactive sends, reads, signals, and awaited cleanup |
| `@nero/nero-terminal-bash` | yes | Persistent shell PTY backend over the Nero Harness subprocess terminal primitive |
| `@nero/nero-tool-terminal` | yes | Six model-facing persistent PTY tools with owner isolation and generic background-job integration |

## test-support

| Package | Config | Description |
|---|---|---|
| `@nero/nero-llm-replay` | yes | Replay LLM plugin: short-circuits llm/stream with model chunks reconstructed from a recorded session JSONL (keyless snapshot tests) |

## todo

| Package | Config | Description |
|---|---|---|
| `@nero/nero-tool-todo` | yes | Model-facing todo_write tool over the Nero Harness event-sourced session log |

## typert

| Package | Config | Description |
|---|---|---|
| `@nero/nero-typert-loader` | yes | Loader integration for generated Typert package contributions |

## web

| Package | Config | Description |
|---|---|---|
| `@nero/nero-tool-web` | yes | Model-facing web tools (web_search, web_fetch) over the Nero Harness web capability seam (ctx.web) |
| `@nero/nero-web` | yes | Abstract web access capability seam (ctx.web) for the Nero Harness — search/fetch provider registry, registration-order-independent selection, request/result vocabulary, and the WebError taxonomy |
| `@nero/nero-web-fetch-http` | yes | Anonymous public HTTP(S) fetch provider for the Nero Harness web capability seam (ctx.web) |
| `@nero/nero-web-search-exa` | yes | Exa-backed search provider for the Nero Harness web capability seam (ctx.web) |
| `@nero/nero-web-search-nero` | yes | Nero-backed search provider (native web_search via the Anthropic-compatible API) for the Nero Harness web capability seam (ctx.web) |
| `@nero/nero-web-search-perplexity` | yes | Perplexity-backed search provider for the Nero Harness web capability seam (ctx.web) |

## webhook

| Package | Config | Description |
|---|---|---|
| `@nero/nero-webhook` | no | Fire-and-forget webhook rule runtime that creates Workspace-backed Nero Harness Sessions |
| `@nero/nero-webhook-github` | yes | Signed GitHub HTTP webhook adapter for the Nero Harness webhook runtime |

## workflow

| Package | Config | Description |
|---|---|---|
| `@nero/nero-tool-ralph` | yes | Model-facing fresh-agent Ralph loop over the workflow and subagent seams |
| `@nero/nero-tool-workflow` | yes | Model-facing workflow tool: run a JavaScript orchestration script over ctx.workflowEngine |
| `@nero/nero-workflow-ptc` | yes | Workflow orchestration in the shared sandboxed Node PTC runtime |

## workspace

| Package | Config | Description |
|---|---|---|
| `@nero/nero-workspace` | no | Workspace entity registry (ctx.workspaceRegistry): durable workspace records with validated session attachment over the domain data form for the Nero Harness |
