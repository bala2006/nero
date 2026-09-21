# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Reasoning is actually requested**: the Azure Responses payload now sends
  `reasoning.summary`, without which the provider never emitted reasoning deltas.
  Reasoning is captured as a first-class `ReasoningState` with a collapsible
  streamed block, elapsed time, token estimate and a live phase caption.
- **Runtime capability catalog**: `CapabilityProvider` / `CapabilityCatalog`
  replace the compile-time tool list, so tools can appear at runtime.
- **MCP client**: Streamable-HTTP and SSE transports, initialize/tools-list/tools-call,
  server management with connection testing, per-tool exposure and approval
  settings, an audit trail, and a tool executor wired into the chat loop. Server
  text and schemas are sanitised before they reach the model.
- **Human approval gate**: every tool call can pause the run for an explicit
  allow/deny, honouring the global policy, per-tool overrides and MCP server
  settings. The active task reports `waitingUser` while it waits.
- **Agent modes and budgets**: composer Chat/Plan/Agent selector; Plan and Agent
  modes track a plan, Chat answers directly. `RunBudget` now bounds model
  rounds, tool calls and wall-clock time, returning the partial answer with a
  visible reason instead of looping.
- **On-device sandbox**: sessions, a permission policy that denies by default,
  and a WebView execution backend for JavaScript and HTML with console capture.
  The controller is app-lifetime: the shell mounts the off-screen WebView host,
  so the agent's `sandbox_run_code` tool runs code while no sandbox screen is
  open, against transient sessions that never touch the user's scratchpads.
- **Inspection screens**: Skills (step graphs and quality gates), Memory
  (entries and learned facts, with per-item forget), and Runs (history with
  phase timelines, event logs, resumability, and "Run again" which re-issues a
  run's original prompt into the composer).

### Changed
- Renamed the legacy `SarvamModelCatalog` / `SarvamModelInfo` to
  `NeroModelCatalog` / `NeroModelInfo` and collapsed the retired `sarvamApiKey`
  settings field into `azureApiKey` (database schema v9 migrates the stored
  key). Composer hint text no longer references the retired provider.

### Changed
- Split the 4,000-line chat screen into `presentation/{screens,widgets,rich}`
  and extracted a shared `lib/core/widgets` kit, removing the duplicated
  backdrop, top bar and section card from the chat and settings screens.
- Added an app shell with a navigation drawer and a named-route table.
- Settings gained Reasoning, Agent and MCP sections.

### Fixed
- Reasoning blocks, plan status and tool activity are no longer synthesised
  from tool labels.

## [1.0.0] - 2026-06-12

### Added
- **AI Agent Orchestration Engine**: Built-in system for scheduling, planning, executing, and monitoring multi-turn agentic task runs.
- **Sarvam AI Provider Support**: Deep integration with Sarvam AI API models (`sarvam-105b`, `sarvam-30b`, `sarvam-m`), supporting both streaming and unary chat completion endpoints.
- **Capabilities and Tools System**: Extensible plugin system mapping Flutter capabilities to AI-accessible tools (e.g. web search, document parsing, document generation, workspace interactions).
- **Rich Interactive UI**: A sleek, modern dark-themed user interface featuring streaming markdown content, syntax-highlighted code viewer, interactive tables, and live Mermaid.js diagram viewer.
- **Local Persistence & SQLite Integration**: Fully offline-first capabilities powered by Drift and SQLite for chat conversations, project workspaces, capability registers, and agent runtime transaction ledgers.
- **Workspace File Management**: Native document bridge for file ingestion, PDF parsing, text extraction, photo capturing, and exporting outputs to standard DOCX/XLSX/PDF.
- **Audit Logs Ledger**: Detailed operation histories recording the execution status, metrics, and state effects of each tool invocation.
- **Unit and Integration Tests**: Wide suite of tests covering all application and domain components including planners, run coordinators, and response repairers.
