# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
