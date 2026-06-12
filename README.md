# Nero 🐈‍⬛

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)

Nero is an advanced, production-grade Flutter application implementing a localized **Agentic AI Chat System**. Built with a pluggable provider architecture, Nero can connect to any LLM API (currently includes **Sarvam AI** support out of the box). It allows LLM models to plan tasks, invoke local tools, read files, generate spreadsheets, docx files, PDFs, package zip files, query web content, and monitor executing tasks with a high-fidelity audit trail.

---
## Roadmap

### v0.2
- Additional model providers
- Enhanced agent planning

### v0.3
- Plugin marketplace
- Multi-agent workflows

### v0.4
- Team workspaces
- Remote execution support
---

## ✨ Features

- 🧠 **Agentic Run Loop**: A complete loop supporting `planning -> tool selection -> local execution -> verification -> completion` within the chat interface.
- 🛠️ **Capability & Tool Registry**: Includes out-of-the-box tools for:
  - **Web Search & Extraction**: Querying search engines and reading/extracting article text from specific URLs.
  - **Document Synthesis**: Direct generation of download-ready Excel (`.xlsx`), Word (`.docx`), and Adobe PDF (`.pdf`) documents.
  - **File Operations**: Managing workspace files, workspace serialization, and ZIP packaging.
- 💾 **Drift/SQLite Offline Persistence**: Robust schema for mapping chat messages, conversations, workspace items, capability logs, and run operations locally.
- 📊 **Audit & Ledger Trackers**: A structured logging system tracking time, costs, tool execution states, and model parameters for every prompt run.
- 📈 **Modern Dark UX**: Smooth animations, inline interactive tables, live code syntax highlighting, and responsive layout interfaces.
- 🧪 **Mermaid.js Visualizer**: Direct embedding of dynamic Mermaid charts and diagrams in chat responses.

---

## 🏛️ Architecture & Folder Structure

Nero follows clean architecture design patterns, organized cleanly by domain feature components:

```
lib/
├── app/                  # Main MaterialApp bootstrap & global error reporting
├── core/                 # Shared design systems, color tokens, and text themes
├── platform/             # Local database, secure store, and native platforms
└── features/             # Core capabilities grouped by domain functionality
    ├── agent/            # Planning algorithms, task managers, and run state transitions
    ├── audit/            # Local audit log tracking and capability event schemas
    ├── capabilities/     # Tool Definitions and Capability registries exposed to the LLM
    ├── chat/             # State controllers, screen UI layouts, markdown rendering
    ├── docs/             # Document formatting and docx/xlsx layout engines
    ├── memory/           # Working memory store and context synthesis models
    ├── packaging/        # Local compression services (ZIP)
    ├── projects/         # Scaffold builders and artifact organizers
    ├── providers/        # Sarvam client wrappers and interface adapters
    ├── response/         # Parser guards and response structures
    ├── runtime/          # Ledger engines, progress builders, run node routers
    ├── settings/         # App settings schema and configuration screens
    ├── skills/           # Custom dynamic skills loaded into runtime
    ├── tools/            # Local execution dispatchers and environments
    ├── verifier/         # Output, semantic, and safety checkers
    └── workspace/        # Workspace file picker, context importers, and share pipelines
```

---

## 🚀 Getting Started

### Prerequisites
Make sure you have the Flutter and Dart SDKs installed on your system:
- **Flutter SDK**: `^3.9.2`
- **Dart SDK**: `^3.9.2`
- **SQLite**: Local libraries installed (or resolved automatically by `sqlite3_flutter_libs`).

### Setup & Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/bala2006/nero.git
   cd nero
   ```

2. **Fetch Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Code Generation** (Drift DB schema builder):
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Launch the App**:
   Run the dev server or launch on a device/emulator:
   ```bash
   flutter run
   ```

---

## ⚙️ Configuration

To use the AI capabilities, you will need to input your **Sarvam AI API Key** in the settings panel inside the application.

### Supported Models:
- `sarvam-105b` (Recommended for complex reasoning and multi-step tasks)
- `sarvam-30b`
- `sarvam-m`

---

## 🧪 Testing

Nero comes with a comprehensive test suite for verifying the state runner, planners, parser rules, and memory stores.

To run all unit and widget tests:
```bash
flutter test
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
