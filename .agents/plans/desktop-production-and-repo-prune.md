# Desktop production readiness and repository prune plan

Ship a Windows desktop application plus the Web UI, and nothing else. Windows x64 is the sole target. The rule the program enforces is closure. Every surviving file must be reachable from the desktop profile or the web profile. Everything else is deleted, and the gates that policed a deleted surface are deleted with it.

Deliverables, in order. P1 inventory, P2 prune, P3 retire tooling, P4 release pipeline, P5 runtime hardening, P6 product polish, P7 install and rehearsal.

P1 to P3 subtract. P4 to P7 add. P2 is the large one and gates everything after it.

## How to read this

One box is one unit of work. Every box names the evidence that checks it. A nested box is a sub-step of the box above it. Check a box only when its evidence exists, a file, a log line, a screenshot, a test run, or a SHA. The body is a how-to. The appendices explain and record.

The program runs `pstack/skills/poteto-mode/playbooks/autopilot-stack.md`. The operator lands the chain. Nothing on this program is merged by an owner.

Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

Two environment facts bound the program. This workspace has no subagent transport, so the ten live lanes run serially by the owner instead of through the swarm. The UI control skill is Playwright MCP, which is connected.

Four product decisions are settled, and every section below assumes them. Windows x64 is the only desktop target, so the macOS packaging, signing, and notarization path is deleted. The repository keeps a minimal build and release CI, which P4 recreates because the removal earlier in this session deleted `.github`. The `website/` and `docs/` trees are deleted. The packages stop publishing to npm, so the publish metadata and the npm release scripts are deleted.

## Program checklist

### Arm the program

- [ ] State the protocol and this plan to the operator, then stop. Start execution only on the operator's explicit go.
- [ ] On the operator's go, arm a `/goal` with this exact text. "Execute `.agents/plans/desktop-production-and-repo-prune.md` P1 through P7 in order. Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. The operator lands the chain. Done when P7's rehearsal passes and the repository contains only closure-reachable code."
- [ ] Read these from trunk at program start. Re-read them at every tick.
  - [ ] `git show origin/main:pstack/skills/poteto-mode/playbooks/autopilot-stack.md`
  - [ ] `git show origin/main:pstack/skills/swarm/SKILL.md`
  - [ ] `git show origin/main:pstack/skills/poteto-mode/playbooks/opening-a-pr.md`
  - [ ] `git show origin/main:pstack/skills/poteto-mode/playbooks/shipping.md`
  - [ ] `git show origin/main:packages/AGENTS.md` and `git show origin/main:docs/architecture.md`
- [ ] Arm the 30-minute audit tick. In a local session, a real terminal `/loop`. Never leave the cadence to memory.
- [ ] Use this tick prompt, verbatim. "Re-read the execution playbook from trunk and the armed /goal. Audit the operation against both and fix drift in this tick. Probe every active lane and judge progress by side effects only. Stand down a stuck lane and dispatch its replacement now. Then post a short status message to the operator in chat only when the audit found a tracked change that no earlier status message reported, such as a PR opened, a code-ready head, a round launched or closed, a verdict, a merge, a stuck agent and the action taken, a blocker added or cleared, or a decision only the operator can make. Name every such change and nothing else. Do not repeat a table, the merged list, or an unchanged blocker. If the audit found none, end the turn with no reply text. Either way, log this tick's row in your decision trail. The row names the items reported, or none."
- [ ] On the operator's hold or stand-down, send every owner a zero-writes order at once.

### Spawn owners

- [ ] Spawn one owner per PR with the full lifecycle the execution playbook names. P1 and P5 and P6 start first.
- [ ] Follow this dependency graph. Start dependent work only after its parent merges, or base it on the parent branch when the execution playbook stacks.
  - [ ] P1 branches from `main`.
  - [ ] P2 and P3 stack on P1. P3 does not start until P2 merges, because P3 deletes the gates that P2's deletions orphan.
  - [ ] P4 stacks on P3.
  - [ ] P5 and P6 stack on P3 and run in parallel with P4. They touch different files.
  - [ ] P7 stacks on P4 and P5.
- [ ] Hold the file boundaries. P1 touches only `.agents/plans/`. P2 and P3 touch deletion targets and their own gate files. P4 touches `apps/desktop/scripts/`, `apps/desktop/.env.*.example`, and `.github/workflows/` if retained. P5 touches `apps/desktop/src/` hardening and crash reporting. P6 touches the welcome window, locale, and client UI. P7 touches installer scripts and migration.
- [ ] Hold the review gate. P4, P5, P6, and P7 change an interaction. They wait for the operator's review in chat with screenshots and a video before merge. P1, P2, and P3 are not review-gated.

### PR mechanics, for every PR

- [ ] Resolve the forge once. Default to `gh`. If `command -v origin` succeeds and Origin can resolve the repository, use `origin pr` for every PR operation. Record any fallback to `gh`. Never require `gt`.
- [ ] Open the PR ready, never draft, with `origin pr create --status open --base <base-branch>` or `gh pr create --base <base-branch>` according to the resolved forge. A stack child targets its parent branch.
- [ ] Run the repo's lint and typecheck once before the PR-facing push. Push with hooks on.
- [ ] Review the diff for AI-tell slop before each commit and run `/no-comments` before review.
- [ ] Triage every Bugbot and security-reviewer comment per `../references/bugbot-triage.md`.
- [ ] Rebase onto current trunk before the code-ready report. Keep that merge base in fix rounds. Rebase again only at merge prep, on a `git merge-tree` conflict with trunk, or on a CI failure that comes from a change on trunk.

### Verdict and merge, for every PR

- [ ] At the code-ready head SHA and at each later push that changes the patch, run the swarm per `pstack/skills/swarm/SKILL.md`. One gates lane. The ten live lanes from the PR's **Verify, live** block. The perf lane from its **Verify, perf** block. Two audit lanes that read the diff and the receipts and distrust the PR body.
- [ ] Clean only when every lane is `PASS`. Findings go back to the owner. A new head gets a fresh verdict, except for results that stay valid under the patch-id rule in `playbooks/shipping.md`.
- [ ] No owner merges. A clean verdict appends the PR to the linear base-branch stack via the root. The operator lands the chain bottom-up.

### Boot recipe, for every live lane

Each live lane runs at the PR head in this workspace. Drive the UI through Playwright MCP.

- [ ] `git fetch origin <head-branch> && git checkout <head SHA>`.
- [ ] `pnpm install && pnpm run build`.
- [ ] Start the surface. Web is `pnpm nero web`, default `http://127.0.0.1:3080`. Desktop is `pnpm run start:desktop`, default port `19387`.
- [ ] Deliver input only through Playwright MCP. Read-only diagnostics are `pnpm run verify-runtime-closure`, `pnpm run verify-package-dependencies`, and `pnpm run verify-application-entrypoints`.
- [ ] Save every screenshot to `/tmp/swarm-<pr-id>/worker-<n>/<slug>.png` and return the paths with the report.

## Inventory the real closure (P1)

**Depends on.** None.

**Files.**

- [ ] Create `.agents/plans/closure-inventory.md`.

**Build.**

- [ ] Record the composed plugin tree for the web profile from `pnpm nero --profile web --dump-config`.
- [ ] Record the host closure from the desktop runtime tree in `apps/desktop/src/runtime-tree.ts` and the bundle rows in `packages/bundle/base/cordis.patch.yml` and `packages/bundle/web-app/cordis.patch.yml`.
- [ ] Record the client closure with `pnpm run verify-client-packages` and `pnpm run gen-client-catalog`. The Web UI lives on this side.
- [ ] Re-anchor `pnpm run verify-runtime-closure` to the desktop runtime manifest. Measured on this checkout it anchors to `python/sdk-runtime/package.json` and places all 58 `packages/client/*` packages outside its closure, because it measures the Python SDK runtime product.
- [ ] Regenerate `docs/module-graph.md` and `docs/dependency-catalog.json` with `pnpm run gen-module-graph` and `pnpm run gen-dependency-catalog`.
- [ ] Classify every top-level directory and every `packages/*` group as KEEP or DELETE, with the reachable-from evidence on the KEEP row.
- [ ] Record the desktop profile's bundle list from `apps/desktop`'s profile resolution, since the CLI refuses the reserved `desktop` name.
- [ ] Record Windows x64 as the sole release target, and list the macOS-only files that P2 deletes.

**You see.**

- [ ] One table with a row per directory, a KEEP or DELETE verdict, and the evidence column filled for every KEEP.
- [ ] A DELETE list where no row is claimed without naming the bundle or profile that does not reach it.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] The inventory is documentation only. Run `pnpm run verify-md-links` and confirm it stays green.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `opencode/mimo-v2.6-flash-free` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Boot web at trunk and head. Save `web-boot.png`. Pass when both reach the composer with a selected workspace.
- [ ] Lane 2. `pnpm run verify-client-packages` at the head. Save `client-verify.png`. Pass when it exits zero.
- [ ] Lane 3. `pnpm run verify-package-dependencies` at the head. Save `dependencies-verify.png`. Pass when it exits zero.
- [ ] Lane 4. `pnpm run verify-application-entrypoints` at the head. Save `entrypoints-verify.png`. Pass when it exits zero.
- [ ] Lane 5. Send one message in a web session and await the assistant reply. Save `session-roundtrip.png`. Pass when the reply renders.
- [ ] Lane 6. Open Settings. Save `settings.png`. Pass when the Models page renders.
- [ ] Lane 7. Open the Plugins page. Save `plugins.png`. Pass when the inventory lists the composed plugins.
- [ ] Lane 8. Start the desktop app. Save `desktop-boot.png`. Pass when the welcome window appears.
- [ ] Lane 9. Switch the client language to Chinese and back. Save `locale.png`. Pass when labels change and revert.
- [ ] Lane 10. Read the browser console across lanes 5 to 9. Save `console.png`. Pass when it carries no error-level entry.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Web profile cold boot to interactive composer, in milliseconds.
- [ ] Probe. Time `pnpm nero web` to first composer render, at trunk and at the head, interleaved, three runs each.
- [ ] Baseline. Record the trunk median first.
- [ ] Rule. Fail if the head median exceeds the trunk median by more than 10 percent.

**Review gate.** None. P1 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] Root appends to the stack.

## Prune code outside the closure (P2)

**Depends on.** P1.

**Files.**

- [ ] Delete `python/sdk` and `python/sdk-runtime`, the Python SDK and its runtime wheel. Keep the Desktop bundled interpreter preparation under `scripts/primary-runtime/`.
- [ ] Delete `website/`, the `docs/` tree, `benchmarks/`, and `snapshots/`. The website and docs deletion is settled. The other two hold only when P1 shows the desktop build does not read them.
- [ ] Delete the non-shipping bundles under `packages/bundle/`, which P1 confirms as `headless`, `sdk-app`, `sdk-minimal`, and `acp-app`.
- [ ] Delete the non-shipping entry packages `packages/sdk`, `packages/acp`, `packages/headless` when present.
- [ ] Delete out-of-closure packages P1 marks DELETE, including the opt-in families `webhook`, `schedule`, `ssh`, `lsp`, and the `experimental/*` prototypes that no shipping bundle loads.
- [ ] Delete `.agents/notes` for removed surfaces. The `docs/` tree goes with the website.
- [ ] Delete the macOS packaging path. `apps/desktop/.env.macos.example`, `apps/desktop/scripts/macos-runtime.ts`, the macOS icon and entitlement resources, the notarization and parallel artifact lanes, and the `verify:mac-signature` check.
- [ ] Delete the npm publish path. Every `publishConfig` and `repository` field across the manifests, `scripts/publish-npm-baseline.ts`, the publish and pack steps under `scripts/release/`, and `native/system/scripts/publish-release.mjs`.
- [ ] Delete the macOS-only branches in the desktop shell that have no Windows reader, including its menu and material code.
- [ ] Delete the removed profiles from `package.json` scripts and from the launcher's shipped template list.

**Build.**

- [ ] Delete in waves, one top-level family per commit, ordered leaf first so a package is removed only after its last consumer is gone.
- [ ] After each wave, run `pnpm run verify-client-packages` and `pnpm run verify-package-dependencies`, then boot the web profile. A failure names the family that still has a consumer.
- [ ] Trim `pnpm-workspace.yaml` globs only when a whole workspace root is gone.

**You see.**

- [ ] `git ls-files | wc -l` drops monotonically, wave by wave, with the count recorded in the decision trail.
- [ ] `pnpm run verify-client-packages` exits zero after every wave.
- [ ] A repository tree where every remaining top-level directory appears on P1's KEEP list.
- [ ] A repository where no manifest carries `publishConfig` and no `apps/desktop` file names macOS.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Run `pnpm run verify-client-packages` and `pnpm run verify-package-dependencies`. Add the case that a removed bundle name is rejected by the launcher. Run `pnpm exec vitest run scripts`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `opencode/mimo-v2.6-flash-free` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Boot web at trunk and head. Save `web-boot.png`. Pass when both reach the composer with a selected workspace.
- [ ] Lane 2. `pnpm nero --profile web --dump-config`. Save `dump.txt`. Pass when it lists no removed bundle.
- [ ] Lane 3. Boot `pnpm nero web` and send one message. Save `session-roundtrip.png`. Pass when the reply renders.
- [ ] Lane 4. Open the Files sidebar and read a workspace file. Save `files.png`. Pass when content renders.
- [ ] Lane 5. Run the `bash` tool from a session. Save `bash.png`. Pass when the command output renders.
- [ ] Lane 6. Open the Browser sidebar and load a loopback page. Save `browser.png`. Pass when the page renders.
- [ ] Lane 7. Open Settings and the Models page. Save `settings.png`. Pass when it renders without a missing-plugin error.
- [ ] Lane 8. Open the Plugins page. Save `plugins.png`. Pass when enable and disable still work.
- [ ] Lane 9. Start the desktop app and reach the welcome window. Save `desktop-boot.png`. Pass when it appears without a fatal dialog.
- [ ] Lane 10. Read the console across lanes 3 to 9. Save `console.png`. Pass when it carries no error-level entry and no unresolved-module warning.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Web profile cold boot to interactive composer, in milliseconds, plus packaged app size in mebibytes.
- [ ] Probe. Time the boot at trunk and at the head, interleaved, three runs each. Measure the packaged artifact size before and after.
- [ ] Baseline. Record the trunk values first. Trunk boot median and trunk package size.
- [ ] Rule. Fail if head boot exceeds trunk by more than 10 percent, or if package size does not shrink.

**Review gate.** None. P2 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] Root appends to the stack.

## Retire tooling for removed surfaces (P3)

**Depends on.** P2.

**Files.**

- [ ] Delete the gate scripts and specs whose only subject was a removed surface, under `scripts/`.
- [ ] Delete the corresponding entries from `scripts/run-gates.ts` in every `gatesForMode` arm.
- [ ] Delete the corresponding entries from `package.json` scripts.
- [ ] Delete the documentation gates, including `verify-md-links`, `verify-translation-pairing`, and the doc catalog generators, since their corpus is deleted.
- [ ] Keep `apps/desktop` packaging scripts, `scripts/primary-runtime/`, `scripts/build.ts`, and the gates that guard the shipping closure.

**Build.**

- [ ] Grep for each deleted script name across `scripts`, `package.json`, and any retained workflow, and remove every caller.
- [ ] Re-run `pnpm run check:all` and delete or repair what it now reports as missing.
- [ ] Record the surviving gate inventory in the decision trail, one line per gate with its subject.
- [ ] Keep a minimal CI surface. The removal earlier in this session deleted `.github`, so P4 recreates one Windows build and release workflow rather than pruning an existing set.
- [ ] Delete or re-anchor `verify-runtime-closure`. Its manifest source is `python/sdk-runtime/package.json`, which P2 deletes.

**You see.**

- [ ] `pnpm run check:all` exits zero.
- [ ] `pnpm run lint` and `pnpm run typecheck` exit zero.
- [ ] No retained file names a deleted script or package.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Run `pnpm run check:all`. Add the case that `run-gates.ts` rejects an unknown gate id rather than skipping it.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `opencode/mimo-v2.6-flash-free` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Boot web at trunk and head. Save `web-boot.png`. Pass when both reach the composer.
- [ ] Lane 2. `pnpm run check:all`. Save `check-all.txt`. Pass when it exits zero.
- [ ] Lane 3. `pnpm run lint`. Save `lint.png`. Pass when it exits zero.
- [ ] Lane 4. `pnpm run typecheck`. Save `typecheck.png`. Pass when it exits zero.
- [ ] Lane 5. `pnpm run test`. Save `test.png`. Pass when it exits zero.
- [ ] Lane 6. Send one message in a web session. Save `session-roundtrip.png`. Pass when the reply renders.
- [ ] Lane 7. Open Settings. Save `settings.png`. Pass when it renders.
- [ ] Lane 8. Open the Plugins page. Save `plugins.png`. Pass when it lists the composed plugins.
- [ ] Lane 9. Start the desktop app. Save `desktop-boot.png`. Pass when the welcome window appears.
- [ ] Lane 10. Read the console across lanes 6 to 9. Save `console.png`. Pass when it carries no error-level entry.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Wall-clock duration of `pnpm run check:all`.
- [ ] Probe. Time the full gate run at trunk and at the head, interleaved, once each, on the same machine.
- [ ] Baseline. Record the trunk duration first.
- [ ] Rule. Fail if the head run is slower than the trunk run, since this PR only deletes gates.

**Review gate.** None. P3 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] Root appends to the stack.

## Harden the desktop release pipeline (P4)

**Depends on.** P3.

**Files.**

- [ ] Edit `apps/desktop/scripts/` packaging, preflight, and upload scripts for the Windows target only.
- [ ] Delete `apps/desktop/.env.macos.example` and every macOS release field.
- [ ] Create one Windows build and release workflow under `.github/workflows/`.
- [ ] Edit `apps/desktop/.env.windows.example`.
- [ ] Edit `apps/desktop/README.md` for the release section.

**Build.**

- [ ] Pin one release identity. Shell, runtime, and bundled pnpm share the exact version, as the Desktop packaging decision already requires.
- [ ] Make version selection refuse a version that is not greater than the published feed, so a bad build cannot be published as a downgrade.
- [ ] Make credential preflight fail closed. A missing, expired, or wrong-issuer code-signing certificate stops the build before compilation.
- [ ] Make upload atomic, and write the completion record only after signing succeeds.
- [ ] Make the signing path one target. The hardware token signs serially, and every new signature must match the configured certificate and carry a timestamp.
- [ ] Add a rollback path. Publishing a corrected feed and re-pointing the channel must be a documented, scripted operation.

**You see.**

- [ ] `pnpm --dir apps/desktop run check:package` fails loudly on a deliberately broken certificate path.
- [ ] A packaging run produces exactly one target's artifacts.
- [ ] A build with a non-increasing version exits nonzero with the reason printed.
- [ ] The uploader writes a completion record only on success, and a simulated mid-upload failure leaves no record.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Add cases for the version guard, the credential preflight, and the completion record. Run `pnpm exec vitest run apps/desktop`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `opencode/mimo-v2.6-flash-free` at the PR head, per the boot recipe. Lanes 2 to 6 use a test deployment and a test bucket.

- [ ] Lane 1. Regression lane against trunk. Boot the packaged app at trunk and head. Save `desktop-boot.png`. Pass when both reach the welcome window.
- [ ] Lane 2. Build an unsigned Windows package. Save `win-build.png`. Pass when the artifact is named as unsigned.
- [ ] Lane 3. Build a signed Windows package. Save `win-signed.png`. Pass when the signature verifies and the installer carries the release name.
- [ ] Lane 4. Package with a broken certificate path. Save `preflight-error.png`. Pass when preparation stops before compilation and names the certificate.
- [ ] Lane 5. Package with a version equal to the published feed. Save `version-guard.png`. Pass when it exits nonzero naming the version.
- [ ] Lane 6. Publish to the test feed, then run a rollback to the previous version. Save `rollback.png`. Pass when the client resolves the previous version.
- [ ] Lane 7. Launch the packaged app and confirm the About entry shows the built version. Save `about.png`. Pass when it matches.
- [ ] Lane 8. Open Settings in the packaged app. Save `settings.png`. Pass when it renders.
- [ ] Lane 9. Trigger a simulated update check. Save `update-check.png`. Pass when the failure path shows a message rather than a crash.
- [ ] Lane 10. Read the crash log directory after lanes 2 to 9. Save `crash-directory.png`. Pass when no unexpected report was written.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Windows installer size in mebibytes and packaging wall-clock in seconds.
- [ ] Probe. Measure the installer size and the packaging duration at trunk and at the head, on the same machine.
- [ ] Baseline. Record the trunk values first.
- [ ] Rule. Fail if installer size grows by more than 5 percent or packaging regresses beyond the trunk duration.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 2 and lane 3 screenshots into `.agents/media/P4-review-build.png`.
- [ ] Record a 30 to 60 second video of a Windows package and publish against the test feed. Save it as `.agents/media/P4-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] Root appends to the stack.

## Harden the desktop runtime (P5)

**Depends on.** P3.

**Files.**

- [ ] Edit `apps/desktop/src/` main-process security policy, window creation, and recovery handling.
- [ ] Edit the Electron builder configuration for fuses, ASAR integrity, and entitlements.
- [ ] Edit the crash-report writer when remote reporting is added.
- [ ] Edit `apps/desktop/tests/`.

**Build.**

- [ ] Enable and verify Electron fuses, and assert them in the packaged artifact rather than only in source.
- [ ] Enforce a context-isolation and sandbox policy on every window, and make the packaged build fail when a window opts out.
- [ ] Reduce entitlements to the smallest set the app needs, and assert the set in the packaged artifact.
- [ ] Add a remote crash and error report path with an explicit user consent gate, keeping the local report as the fallback.
- [ ] Bound every network call the shell makes, with a timeout and a retry cap.

**You see.**

- [ ] A packaged app whose fuses and entitlements are asserted by a script that reads the artifact.
- [ ] A crash in a deliberately broken build produces a consent prompt and one report.
- [ ] A hung network call fails within its timeout instead of stalling startup.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Add cases for the fuse assertion, the entitlement set, and the timeout bound. Run `pnpm exec vitest run apps/desktop`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `opencode/mimo-v2.6-flash-free` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Boot the packaged app at trunk and head. Save `desktop-boot.png`. Pass when both reach the welcome window.
- [ ] Lane 2. Run the fuse assertion against the packaged artifact. Save `fuses.txt`. Pass when every expected fuse is set.
- [ ] Lane 3. Open DevTools in a packaged build with the documented shortcut. Save `devtools.png`. Pass when it opens only where intended.
- [ ] Lane 4. Load a remote page in the embedded view and confirm it cannot reach renderer internals. Save `webview-isolation.png`. Pass when the probe fails as required.
- [ ] Lane 5. Force a main-process error and confirm one recovery dialog. Save `recovery.png`. Pass when the dialog offers restart and exit.
- [ ] Lane 6. Trigger a crash report and confirm consent is asked before any upload. Save `crash-consent.png`. Pass when no upload precedes consent.
- [ ] Lane 7. Block the update endpoint and confirm the app still starts. Save `offline-boot.png`. Pass when the workspace opens.
- [ ] Lane 8. Open Settings. Save `settings.png`. Pass when it renders.
- [ ] Lane 9. Sign out and back in through the account surface. Save `account.png`. Pass when the credential never reaches the renderer.
- [ ] Lane 10. Read the console and the crash directory across lanes 2 to 9. Save `console-crash.png`. Pass when there is no error-level entry and no report missing consent.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Desktop cold start to welcome window, in milliseconds.
- [ ] Probe. Time the launch at trunk and at the head, interleaved, three runs each, after clearing the cache.
- [ ] Baseline. Record the trunk median first.
- [ ] Rule. Fail if the head median exceeds trunk by more than 10 percent.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 4 and lane 5 screenshots into `.agents/media/P5-review-security.png`.
- [ ] Record a 30 to 60 second video of the crash consent flow and the recovery dialog. Save it as `.agents/media/P5-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] Root appends to the stack.

## Polish the desktop product surface (P6)

**Depends on.** P3.

**Files.**

- [ ] Edit the welcome window, entry layout, and API-key page under `apps/desktop/`.
- [ ] Edit the locale dictionary and the language preference path.
- [ ] Edit the client UI packages that the desktop shell renders.

**Build.**

- [ ] Make first-run onboarding reach a working workspace without a dead end. Every refusal names the next action.
- [ ] Make every shell string localized, with no English leaking into a Chinese session.
- [ ] Make the account and credential surface declare its error states, so a failed sign-in shows a reason.
- [ ] Bring the application menu and welcome window to keyboard reachability with visible focus.
- [ ] Add an accessibility pass over the primary surfaces. Name the standard and the tool that checks it.

**You see.**

- [ ] A first launch from no credential to a working workspace in one path, with no dead end.
- [ ] A Chinese session whose shell strings are all translated.
- [ ] A keyboard-only pass over the welcome window, workspace, and settings.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Add cases for the locale coverage and the onboarding state machine. Run `pnpm exec vitest run`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `opencode/mimo-v2.6-flash-free` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Boot the packaged app at trunk and head. Save `desktop-boot.png`. Pass when both reach the welcome window.
- [ ] Lane 2. First run with no credential. Save `onboarding.png`. Pass when the API-key page renders and saves.
- [ ] Lane 3. Choose set-up-later and confirm the workspace opens. Save `skip-onboarding.png`. Pass when the workspace opens.
- [ ] Lane 4. Switch to Chinese. Save `locale-zh.png`. Pass when no English shell string remains.
- [ ] Lane 5. Switch back to English. Save `locale-en.png`. Pass when labels revert.
- [ ] Lane 6. Fail a sign-in deliberately. Save `auth-error.png`. Pass when a reason is shown.
- [ ] Lane 7. Tab through the welcome window. Save `focus-welcome.png`. Pass when focus is always visible.
- [ ] Lane 8. Tab through Settings. Save `focus-settings.png`. Pass when focus is always visible.
- [ ] Lane 9. Run the accessibility tool over the primary surface. Save `a11y.txt`. Pass when no serious violation remains.
- [ ] Lane 10. Read the console across lanes 2 to 9. Save `console.png`. Pass when it carries no error-level entry.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Welcome-window time to first paint, in milliseconds.
- [ ] Probe. Time the welcome window render at trunk and at the head, interleaved, three runs each.
- [ ] Baseline. Record the trunk median first.
- [ ] Rule. Fail if the head median exceeds trunk by more than 10 percent.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 2 and lane 4 screenshots into `.agents/media/P6-review-onboarding.png`.
- [ ] Record a 30 to 60 second video of the first-run path in both languages. Save it as `.agents/media/P6-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] Root appends to the stack.

## Prove install, upgrade, and migration (P7)

**Depends on.** P4 and P5.

**Files.**

- [ ] Edit the Windows installer configuration.
- [ ] Edit the profile initialization and the Harness home version handling.
- [ ] Add the rehearsal script under `apps/desktop/scripts/`.
- [ ] Edit `apps/desktop/README.md` for the rehearsal and rollback runbook.

**Build.**

- [ ] Version the Harness home, and make a newer app migrate an older home forward without data loss.
- [ ] Make an interrupted install or upgrade recoverable. The installer must leave the previous version usable when promotion fails.
- [ ] Make uninstall leave no orphaned profile or cache that breaks a reinstall.
- [ ] Script a full rehearsal. Install the previous release, upgrade to the candidate, exercise a session, then roll back.

**You see.**

- [ ] An upgrade from the previous release that keeps sessions, settings, and credentials.
- [ ] A forced promotion failure that leaves the previous version launchable.
- [ ] An uninstall then reinstall that reaches a working workspace.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Add cases for the home migration and the interrupted-upgrade recovery. Run `pnpm exec vitest run apps/desktop`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `opencode/mimo-v2.6-flash-free` at the PR head, per the boot recipe, on Windows x64.

- [ ] Lane 1. Regression lane against trunk. Boot the packaged app at trunk and head. Save `desktop-boot.png`. Pass when both reach the welcome window.
- [ ] Lane 2. Install the previous release, then upgrade to the candidate. Save `upgrade.png`. Pass when the workspace opens on the old data.
- [ ] Lane 3. Start a session, then upgrade across it. Save `upgrade-session.png`. Pass when the session resumes.
- [ ] Lane 4. Confirm settings and credentials survive the upgrade. Save `upgrade-settings.png`. Pass when both are intact.
- [ ] Lane 5. Interrupt the upgrade during promotion. Save `upgrade-interrupted.png`. Pass when the previous version still launches.
- [ ] Lane 6. Uninstall after an upgrade. Save `uninstall.png`. Pass when no profile or cache orphan remains.
- [ ] Lane 7. Reinstall after the uninstall. Save `reinstall.png`. Pass when the workspace opens.
- [ ] Lane 8. Run the installer silently and confirm it writes only the log. Save `silent-install.png`. Pass when it exits zero and opens no window.
- [ ] Lane 9. Run the rehearsal script end to end. Save `rehearsal.txt`. Pass when it exits zero.
- [ ] Lane 10. Read the crash directory and the console across lanes 2 to 9. Save `console-crash.png`. Pass when there is no unexpected report and no error-level entry.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Install duration and first-launch time after upgrade, in milliseconds.
- [ ] Probe. Time the install and the post-upgrade first launch at trunk and at the head, interleaved, on the same machine.
- [ ] Baseline. Record the trunk values first.
- [ ] Rule. Fail if install duration or post-upgrade first launch regresses by more than 15 percent.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 2 and lane 5 screenshots into `.agents/media/P7-review-upgrade.png`.
- [ ] Record a 30 to 60 second video of install, upgrade, and rollback. Save it as `.agents/media/P7-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] Root appends to the stack.

## Close the program

- [ ] Every box above is checked with its evidence.
- [ ] The repository contains only closure-reachable code, and `pnpm run verify-runtime-closure` is green.
- [ ] The rehearsal in P7 passes install, upgrade, and rollback.
- [ ] Reply to the operator with the report the execution playbook names.

## Appendix A. Prototype evidence

The closure lever was wrong and is corrected. P1 measured `pnpm run verify-runtime-closure` and found it anchored to `python/sdk-runtime/package.json`, which places all 58 `packages/client/*` packages outside its closure. The corrected closure is two-sided, host plus client, per `.agents/plans/closure-inventory.md`. The corrected KEEP and DELETE lists are still unproven until P1 measures both sides. The DELETE list in P2 names the families most likely to be out of closure, and P1 may move any of them to KEEP.

Windows arm64 support is unproven. The operator chose Windows only, and the packaging scripts build x64, so x64 is the assumption. An arm64 target needs its own installer lane and its own smoke.

The ten live lanes run serially. This workspace has no subagent transport, so the swarm lanes cannot fan out. The lanes and their pass predicates are unchanged.

## Appendix B. Alternatives rejected

Deleting by directory eyeball. Rejected because the harness is an everything-is-a-plugin tree, and a package with zero direct callers can still be reachable through a bundle patch. The closure gates already exist and are cheaper than guessing.

Keeping the removed surfaces behind a disabled flag. Rejected because a disabled bundle still carries build time, packaging weight, and gate maintenance. The request was files that do not contribute, not files that are switched off.

Writing the plan into the repository `docs/` tree. Rejected because that tree is itself a P2 deletion target and because the doc gates police it. The plan lives under `.agents/plans/`, which no gate scans.

Running the whole prune as one commit. Rejected because a failure would not name the package that broke the closure. One family per wave keeps the bisect free.

Keeping macOS and Linux targets. Rejected by the operator, who chose Windows only. One target removes a signing identity, a notarization dependency, and two artifact lanes from every release.

## Appendix C. Risks

The prune breaks the closure in a way the gates do not catch. P2's per-wave `verify-runtime-closure` run plus lane 3 of every live set is the watch. Owner watches the first web boot after each wave.

The prune removes a package the Desktop runtime needs but the web profile does not. The desktop profile is resolved by the Desktop runtime and the CLI refuses the reserved name, so P1 must record the desktop bundle list from the desktop side. Owner watches lane 9 of P2.

The Windows code-signing certificate or hardware token is unavailable, so P4's lane 3 and P7's install lanes cannot run as written. The lanes record that fact and gate the guard behavior and the local rehearsal instead. Risk stays open in this appendix until the certificate exists.

The bundled Python runtime is deleted along with the Python SDK. They are different artifacts. `scripts/primary-runtime/` must survive P2, and lane 5 of P3 is the check.

No control skill covers the packaged Windows installers beyond Playwright MCP against the window. This is a risk. P4 lane 2 and P7 lane 2 name the manual drive that covers it.

## Appendix D. Links and reading list

Read before editing. `apps/desktop/README.md` owns the packaging, profile ownership, and update decisions. `docs/architecture.md` owns the profile and bundle model. `packages/AGENTS.md` owns package conventions. `packages/README.md` owns the group map. `docs/module-graph.md` and `docs/dependency-catalog.json` are the generated closure sources.

P2, P3, and P7 get `pstack/skills/how/SKILL.md`, because deleting a package and retiring a gate both change the architecture the docs describe. P4 and P5 get `pstack/skills/interrogate/SKILL.md`, because the security and update decisions are contested.

The trail per `pstack/skills/show-me-your-work/SKILL.md`. Commit it, because a prune is impossible to review from the diff alone and the audit needs the wave-by-wave count.
