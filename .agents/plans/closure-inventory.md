# Closure inventory for the desktop and web prune

Measured on `desktop-deepseek-harness`, Node v22.18.0, pnpm 11.7.0. Every number below is measured unless the row says inferred.

## The premise failure

The plan's P2 lever was `pnpm run verify-runtime-closure`. Measured, that gate anchors to `python/sdk-runtime/package.json` and globs `packages/bundle/web-app/presets/*.patch.yml`. It reports 173 reachable workspace packages out of 316.

That closure describes the **Python SDK runtime product**, not the desktop and web product. Two rows prove it.

- `packages/client` shows 1 kept and 58 deleted. The deleted set includes `@nero/nero-client-ui-chat`, `@nero/nero-client-ui-conversation`, and the whole Web UI.
- `packages/bundle` shows 1 kept and 5 deleted. The kept package is `nero-base`. `nero-web-app` itself is outside.

Deleting by that closure would destroy the Web UI. It is not the lever for this prune.

## Measured group table

`keep` is membership in the SDK runtime closure. `delete` is `total` minus `keep`.

| group | keep | total | delete |
|---|---|---|---|
| acp | 1 | 1 | 0 |
| api | 1 | 9 | 8 |
| attachment | 2 | 2 | 0 |
| boot | 5 | 5 | 0 |
| browser-use | 0 | 1 | 1 |
| bundle | 1 | 6 | 5 |
| client | 1 | 59 | 58 |
| compaction | 5 | 5 | 0 |
| computer-use | 0 | 1 | 1 |
| context | 2 | 6 | 4 |
| core | 8 | 8 | 0 |
| credentials | 5 | 5 | 0 |
| deliverables | 1 | 2 | 1 |
| document | 0 | 1 | 1 |
| experimental | 0 | 20 | 20 |
| extensions | 2 | 4 | 2 |
| feedback | 2 | 2 | 0 |
| fs | 7 | 7 | 0 |
| goal | 4 | 4 | 0 |
| guard | 2 | 2 | 0 |
| hooks | 3 | 3 | 0 |
| host | 2 | 9 | 7 |
| identity | 1 | 1 | 0 |
| interaction | 5 | 5 | 0 |
| jobs | 3 | 3 | 0 |
| llm | 7 | 7 | 0 |
| lsp | 0 | 3 | 3 |
| mcp | 2 | 2 | 0 |
| plan | 1 | 1 | 0 |
| preset | 2 | 3 | 1 |
| ptc-runtime | 2 | 2 | 0 |
| runtime-diagnostics | 1 | 1 | 0 |
| sandbox | 4 | 4 | 0 |
| schedule | 0 | 1 | 1 |
| sdk | 2 | 3 | 1 |
| session | 17 | 20 | 3 |
| session-query | 2 | 4 | 2 |
| settings | 1 | 1 | 0 |
| shell | 10 | 10 | 0 |
| skill | 6 | 6 | 0 |
| spill | 3 | 3 | 0 |
| ssh | 0 | 4 | 4 |
| storage | 3 | 4 | 1 |
| subagent | 7 | 10 | 3 |
| subprocess | 3 | 3 | 0 |
| terminal | 2 | 3 | 1 |
| test-support | 0 | 7 | 7 |
| todo | 1 | 1 | 0 |
| typert | 3 | 4 | 1 |
| util | 14 | 16 | 2 |
| vendor | 7 | 9 | 2 |
| web | 6 | 6 | 0 |
| webhook | 0 | 2 | 2 |
| workflow | 4 | 4 | 0 |
| workspace | 0 | 1 | 1 |

Tally. 316 workspace packages under the gate's glob, 173 in that closure, 143 outside.

## The corrected levers

The desktop and web closure is two-sided. A package survives when either side reaches it.

Host side. The desktop runtime tree in `apps/desktop/src/runtime-tree.ts`, plus the bundle rows in `packages/bundle/base/cordis.patch.yml` and `packages/bundle/web-app/cordis.patch.yml`.

Client side. The Web UI graph under `packages/client/**`, guarded by `pnpm run verify-client-packages` and `pnpm run verify-client-domain-graph`, and enumerated by `pnpm run gen-client-catalog`.

Neither side is measured yet. The corrected KEEP and DELETE lists are the remaining P1 work, and every row needs the anchor that reaches it.

## Candidate deletes, inferred

These families appear in the wrong closure and are expected to be outside the corrected one. Each is inferred from the group table and the settled product decisions, not measured against the corrected levers.

| target | why |
|---|---|
| `python/` | The Python SDK and its runtime wheel. The bundled interpreter under `scripts/primary-runtime/` stays. |
| `packages/bundle/{headless,sdk-app,sdk-minimal,acp-app}` | Non-shipping profiles. |
| `packages/{sdk,acp}` | Entry packages for those profiles. |
| `packages/experimental/**` | 20 packages, none kept by either product. Agent Teams is a published opt-in, so confirm before deleting. |
| `packages/{ssh,lsp,lsp-stdio,webhook,schedule}` | Opt-in capability families. |
| `website/`, `docs/`, `benchmarks/`, `snapshots/` | Settled by the operator. |
| `apps/desktop/scripts/macos-runtime.ts` and the macOS release path | Windows is the sole target. |

## Must not be deleted

These sit outside the SDK runtime closure and inside the desktop and web product.

- `packages/client/**`. The Web UI, 58 packages.
- `packages/api/**`. The BFF and RPC controllers the Web Host serves.
- `packages/host/**`. The Web GUI host services, including `webserver` and `frontend-static`.
- `packages/bundle/web-app`. The web application bundle.
- `apps/{cli,web,desktop,desktop-host}`, `native/system`, `vendor/**`.

## Open question

`verify-runtime-closure` is anchored to an artifact this prune deletes. Either it is retired with the Python SDK and replaced by the two-sided check, or it is re-anchored to the desktop runtime manifest. The plan takes the second option, because a closure check is worth keeping.
