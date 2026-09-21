# Nero 🐈‍⬛

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)

**Nero is a fully agentic AI assistant that runs on your device.** It connects to an
Azure AI (Microsoft Foundry Models) deployment, plans multi-step tasks, calls tools,
connects to your own **MCP servers**, and can even execute JavaScript/HTML snippets in
an on-device sandbox — all with a local audit trail and offline persistence.

```
You: "Research the top 3 wind-turbine makers and build me a comparison sheet."
Nero: 🧠 thinking… → 🔎 web search → 📄 generates .xlsx → ✅ done (audited)
```

---

## ✨ What can Nero do?

### 💬 Chat with real reasoning
- **Live reasoning blocks** — the model's extended thinking streams into a collapsible
  block with elapsed time and token estimates (summary text is requested from the
  Responses API, so you see actual reasoning, not a fake placeholder).
- **Rich answers** — markdown with live syntax-highlighted code, interactive tables,
  Mermaid diagrams rendered inline, and generated artifacts you can download or share.
- Everything on screen stays smooth while responses stream: streaming deltas rebuild
  only the one bubble that changed, not the whole transcript.

### 🤖 Agentic run loop
- **Three modes** from the composer: **Chat** (direct answers), **Plan** (tracked plan),
  and **Agent** (autonomous multi-round execution).
- The agent loop is `plan → select tools → execute → verify → answer`, with run budgets
  (rounds, tool calls, wall-clock) so it always returns a result instead of looping.
- **Approval gate** — risky tool calls pause the run and ask you first. Approve once,
  always, or deny. You are always in control.
- **Run history** — every run is recorded with its phases and can be re-issued with one
  tap ("Run again").

### 🔌 MCP (Model Context Protocol)
- Add your own MCP servers (Streamable HTTP and SSE transports) from **Settings → MCP**.
- Tools from connected servers appear automatically in the model's toolset, with a
  sanitized schema preview.
- Per-tool control: enable/disable, exposure, and approval mode per tool; server
  connection status is always visible in the sidebar footer.
- Binary tool results become workspace files instead of flooding the prompt with base64.

### 🧪 On-device sandbox
- The agent can write and run **JavaScript or HTML snippets** in a sandboxed WebView —
  quick math, data transforms, tiny visual demos — without leaving the chat.
- A dedicated **Sandbox** screen lets you run snippets yourself with console output and
  error capture.
- Deny-by-default permission policy, persisted per session.

### 🛠️ Built-in tools
- **Web**: search, read pages, extract articles.
- **Documents**: generate ready-to-download `.xlsx`, `.docx`, and `.pdf` files.
- **Workspace**: import files/photos, manage artifacts, package ZIPs.
- **Skills & memory**: reusable skills and long-term memory that persist across chats.

### 🔒 Local-first & auditable
- **Everything is stored on-device** (Drift/SQLite): conversations, settings, runs,
  audit entries. No telemetry, no cloud storage.
- Every tool execution and capability use is written to a structured **audit log** —
  time, status, and parameters for every action Nero took.

---

## 🏛️ Architecture

Clean architecture, organized by feature. Each feature folder follows the same
`domain / application / presentation` split (models, controllers/services, UI).

```
lib/
├── app/                  # App bootstrap, routing, navigation shell, service locator
├── core/                 # Theme, shared widgets (backdrop, cards, banners), formatting
├── platform/             # Drift/SQLite database, key-value stores
└── features/
    ├── agent/            # Task planning and agent task runtime
    ├── audit/            # Capability catalog and audit log
    ├── capabilities/     # Tool definitions exposed to the LLM + registry
    ├── chat/             # Chat screen, streaming pipeline, markdown renderer
    ├── docs/             # docx / xlsx / pdf generation engines
    ├── mcp/              # MCP client, transports, tool bridge, server screens
    ├── memory/           # Long-term memory stores
    ├── packaging/        # ZIP packaging
    ├── projects/         # Artifact organizers
    ├── providers/        # Azure AI (Foundry) Responses client
    ├── response/         # Response parsing guards
    ├── runtime/          # Run ledger, budgets, approval gate, progress snapshots
    ├── sandbox/          # On-device WebView sandbox (JS/HTML execution)
    ├── settings/         # Settings schema + screens, model catalog
    ├── skills/           # Skill registry
    ├── tools/            # Local tool dispatchers
    ├── verifier/         # Output / semantic / safety checkers
    └── workspace/        # File import, context extraction, sharing
```

Deeper detail lives in [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 🚀 Getting started

### Prerequisites
- **Flutter SDK** `^3.9.2` (Dart `^3.9.2`)
- An Android device or emulator (iOS/web/desktop untested)

### Install & run

```bash
# 1. Clone
git clone https://github.com/bala2006/nero.git
cd nero

# 2. Fetch dependencies
flutter pub get

# 3. Generate the Drift database code (only needed after schema changes)
dart run build_runner build --delete-conflicting-outputs

# 4. Run
flutter run
```

### Configuration

1. Open **Settings → API** in the app (or the sidebar footer → Settings).
2. Paste your **Azure AI API key**. The key is stored only on your device.
3. The default model is **GPT-5.6 Luna** (~1M token context) served through Azure AI
   Foundry. Endpoint and deployment are configured in
   `lib/features/providers/azure_ai_config.dart`.

---

## 🧪 Testing

```bash
flutter test
```

Tests are organized next to the features they cover under `test/<feature>/`. CI runs
the analyzer and the test suite in sharded jobs on every push (see
[.github/workflows/ci.yml](.github/workflows/ci.yml)).

---

## 🗺️ Roadmap

### v0.2
- More model providers (pluggable provider adapters)
- Parallel sandbox workers (multiple isolated WebView executors)

### v0.3
- Plugin marketplace
- Multi-agent workflows

### v0.4
- Team workspaces
- Remote execution support

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
