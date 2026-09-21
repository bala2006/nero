# Tests

Test files mirror the `lib/features/*` layout so a file is easy to locate from
the code it exercises.

```
test/
  agent/         agent task planning + runtime adapters
  chat/          chat controller, orchestrator, streaming, recovery
  docs/          document/artifact parsing and builders
  memory/        working-memory + semantic-fact stores
  runtime/       run coordinator, ledger, progress snapshots
  settings/      settings/session behavior
  tools/         local tool runtime bridges
  workspace/     workspace ingestion + document generation/export
  capabilities/  capability registry
  providers/     provider adapters
  response/      response envelope builders
  skills/        skill registry/selector/runner
  verifier/      response + tool-intent verification
  helpers/       shared fakes and test doubles
```

## Shared doubles

`helpers/fakes.dart` holds the fakes that several suites need
(`FakeWorkspaceStore`, `FakeAuditLogStore`, `FakeNativeBridgeService`).
Prefer importing these over re-declaring a copy in a test file; keep a fake
private (`_MyFake`) when only one file uses it.

## Running

```bash
# Full suite (fast path; raises file-level parallelism on many-core machines)
flutter test -j 16

# A single feature area
flutter test test/chat

# One file
flutter test test/chat/chat_session_controller_test.dart

# Shard locally the same way CI does
flutter test --total-shards 4 --shard-index 0
```

`dart_test.yaml` sets the per-test timeout and default concurrency.

## Performance notes

- **Do not `flutter clean` before testing.** A cold build recompiles the app and
  every test entrypoint; that, not the assertions, dominates the run time.
- The suite is easiest to keep fast by parallelizing at the **file** level
  (concurrency / sharding). Tests within a file run sequentially.
- `helpers` avoid real `Future.delayed` polls: `waitForMessageCompletion` and
  `until` resolve on controller notifications rather than a fixed sleep.
- `--coverage` roughly doubles the run; it is a separate CI job for that reason.
