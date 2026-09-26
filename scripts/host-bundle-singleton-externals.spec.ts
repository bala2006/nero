/**
 * Pins one Node-half build rule: a package whose Host code imports a module
 * holding process-wide identity must keep that import external, because an
 * inlined second copy carries its own private registries.
 *
 * `@nero/nero-scope` is the sharpest case. `scopeTarget()` records a routing
 * carrier in the module's own WeakMap and `carrierKeyOf()` reads that same map,
 * so two copies never agree: a plugin that inlines its own copy mints carriers
 * the forwarding peer in `@nero/nero-api-remotes` cannot recognize. The
 * forwarded `sidebar-browser/request` waterfall then falls through to its
 * innermost `next` — "no browser pane answered this request: the Web or Desktop
 * client is not connected" — while a client is connected and answering.
 *
 * The Node-half preset externalizes exactly a package's production
 * dependencies (`dependencies`, `peerDependencies`, `optionalDependencies`) and
 * inlines everything else, so the rule is expressed through the resolved build
 * config rather than the import alone.
 */
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { describe, expect, it } from 'vitest'
import type { UserConfig } from 'tsdown'
import { readWorkspaceManifests } from './check-workspace-constraints.ts'

/** The module whose WeakMaps must be the same object in every Host bundle. */
const SHARED_IDENTITY = '@nero/nero-scope'

const repositoryRoot = fileURLToPath(new URL('..', import.meta.url))

/** Directory names whose sources belong to the browser bundle, not the Host half. */
const CLIENT_DIRECTORIES = new Set(['client', 'node_modules', 'tests'])

/** One package whose Host sources import the shared-identity module. */
function hostSourcesImportScope(dir: string): boolean {
  const sources = join(repositoryRoot, dir, 'src')
  if (!isDirectory(sources)) return false
  return walk(sources).some(file => new RegExp(`from '${SHARED_IDENTITY}(/|')`).test(readFileSync(file, 'utf8')))
}

function isDirectory(path: string): boolean {
  try {
    return statSync(path).isDirectory()
  } catch {
    return false
  }
}

/** Every TypeScript source of the Host half, skipping the browser-bundle directories. */
function walk(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const path = join(dir, entry.name)
    if (entry.isDirectory()) return CLIENT_DIRECTORIES.has(entry.name) ? [] : walk(path)
    return /\.tsx?$/.test(entry.name) ? [path] : []
  })
}

/** Whether one Node-half deps gate keeps the shared-identity module as an import. */
function keepsExternal(config: UserConfig): boolean {
  const gate = (config.deps as { neverBundle?: unknown } | undefined)?.neverBundle
  if (typeof gate === 'function') return gate(SHARED_IDENTITY) === true
  if (!Array.isArray(gate)) return false
  return gate.some(entry => typeof entry === 'string'
    ? entry === SHARED_IDENTITY
    : entry instanceof RegExp && entry.test(SHARED_IDENTITY))
}

/** The Node-half config a package's own preset emits, or undefined when it emits none. */
async function nodeHalfConfig(dir: string): Promise<UserConfig | undefined> {
  const configPath = join(repositoryRoot, dir, 'tsdown.config.ts')
  if (!existsSync(configPath)) return undefined
  const module = await import(pathToFileURL(configPath).href) as {
    default?: (options: { env: Record<string, string> }) => UserConfig[]
  }
  if (typeof module.default !== 'function') return undefined
  return module.default({ env: {} }).find(config => config.platform === 'node')
}

describe('Host-half shared-identity externals', () => {
  it('keeps the scope registry external wherever the Host half imports it', async () => {
    const importing = readWorkspaceManifests(repositoryRoot)
      .filter(({ dir }) => hostSourcesImportScope(dir))
    expect(importing.length).toBeGreaterThan(0)

    const inlined: string[] = []
    for (const { dir, manifest } of importing) {
      const config = await nodeHalfConfig(dir)
      if (config === undefined) continue
      if (!keepsExternal(config)) inlined.push(manifest.name ?? dir)
    }

    expect(inlined).toEqual([])
  })
})
