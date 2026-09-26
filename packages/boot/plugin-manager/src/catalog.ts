/**
 * The plugins a deployment offers in the install dialog: the list a stock
 * installation ships, and the reading of one entry's spec into the package
 * name it installs, so the dialog can say whether the profile already holds it.
 * @module @nero/nero-plugin-manager/catalog
 */

import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { InvalidInstallSpecError, parseInstallSpec, type ParsedInstallSpec } from './install-spec.ts'
import type { PluginCatalogSource } from './types.ts'

/**
 * The plugins a stock installation offers to install. A deployment replaces
 * this list through the plugin's `catalog` config, so what the dialog offers
 * is the deployment's choice, not this package's.
 */
export const DEFAULT_CATALOG: readonly PluginCatalogSource[] = [
  {
    spec: '@nero/nero-experimental-auto-review',
    title: 'Auto review',
    description: 'Per-tool LLM authorization review for the Auto permission preset.',
  },
]

/**
 * The package name a catalog spec installs, read without installing it: a
 * registry name as the spec spells it, or a local directory's own manifest
 * name. A git address and a tarball name their package only once pnpm has
 * fetched it, and an unusable spec names none.
 * @param spec - the catalog entry's spec.
 * @returns the package name, or undefined when nothing names one before an install runs.
 */
export async function catalogPackageName(spec: string): Promise<string | undefined> {
  let parsed: ParsedInstallSpec
  try {
    parsed = parseInstallSpec(spec)
  } catch (error) {
    /* v8 ignore next 2 -- parseInstallSpec throws nothing but its own refusal */
    if (!(error instanceof InvalidInstallSpecError)) throw error
    return undefined
  }
  if (parsed.kind === 'registry') return parsed.name
  if (parsed.kind !== 'path') return undefined
  try {
    const manifest = JSON.parse(await readFile(join(parsed.path, 'package.json'), 'utf8')) as { name?: unknown }
    return typeof manifest.name === 'string' ? manifest.name : undefined
  } catch (_error) {
    // A directory with no readable manifest names no package; installing it reports the problem.
    return undefined
  }
}
