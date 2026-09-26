/**
 * Configuration edits, written into the user layer that owns each row and
 * serialized with Loader hot reload.
 */
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { isDeepStrictEqual } from 'node:util'
import { Context, FiberState, Service, resolveConfig } from '@nero/cordis'
import { entryListSchema, type PatchOptions } from '@nero/cordis-plugin-include'
import yaml from 'js-yaml'
import type { Entry, EntryOptions } from '@nero/cordis-plugin-loader'
import type {} from '@nero/nero-hmr'
import {
  composeEntries, loadOptionalPatches, loadProfileDirectory, PROFILE_PATCH_FILENAME, readProfilePatches, reconcileProfilePatches,
} from '@nero/nero-app-boot'
import { withFileLock, writeFileAtomic } from '@nero/nero-atomic-write'
import { isMap, isSeq, parseDocument, Scalar, visit } from 'yaml'

declare module '@nero/cordis' {
  interface Context {
    /** Persistent edits to the active profile's plugin configuration. */
    configEditor: ConfigEditor
  }
}

function flatten(rows: EntryOptions[]): EntryOptions[] {
  return rows.flatMap(row => [row, ...row.group && Array.isArray(row.config) ? flatten(row.config as EntryOptions[]) : []])
}

/**
 * Persist complete raw configs and apply them through the normal Loader path.
 *
 * An edit lands in the user layer that owns its row: the shared
 * `$NERO_HOME/cordis.patch.yml` when that file declares the row, otherwise the
 * active profile's own patch. The shared layer outranks every profile layer, so
 * writing a shared row into the profile would leave the edit shadowed and the
 * two surfaces disagreeing. Rows only a bundle or the profile declares stay
 * profile-local until a shared row with the same id exists.
 */
export class ConfigEditor extends Service {
  static inject = ['loader', 'profileContext']

  constructor(private readonly ownerContext: Context) {
    super(ownerContext, 'configEditor')
  }

  /** The active profile's own patch; the target for rows no shared layer declares. */
  get documentPath(): string { return this.ownerContext.profileContext.patchPath }

  /** The shared home patch, applied over every profile's own layer. */
  get homePatchPath(): string {
    return join(this.ownerContext.profileContext.home, PROFILE_PATCH_FILENAME)
  }

  /**
   * Resolve the user patch file that owns one row.
   * @param id - the row's profile entry id.
   * @param homePatches - parsed home patches; omitted reads the shared file.
   * @returns the shared home patch when a top-level row declares `id`, otherwise the profile patch.
   */
  documentPathFor(id: string, homePatches: readonly PatchOptions[] | undefined = loadOptionalPatches('nero', this.homePatchPath)): string {
    const shared = homePatches?.some(patch => patch.id === id && patch.insert === undefined) ?? false
    return shared ? this.homePatchPath : this.documentPath
  }

  /** Addressable profile rows; nested Includes have independent configuration ownership.
   * @returns Active entries with unique profile patch ids.
   */
  entries(): Entry[] {
    const candidates = [...this.ownerContext.loader.entries()].filter(entry => entry.parent.tree.ctx.fiber.entry?.id === 'include')
    const counts = new Map<string, number>()
    for (const entry of candidates) counts.set(entry.options.id, (counts.get(entry.options.id) ?? 0) + 1)
    return candidates.filter(entry => counts.get(entry.options.id) === 1)
  }

  /** Read inherited and explicit profile values for the active entries.
   * @returns Detached layer values alongside their Loader entries.
   */
  configuration(): Array<{ entry: Entry; inherited: Record<string, unknown>; override: Record<string, unknown> }> {
    const profile = this.ownerContext.profileContext
    const loaded = loadProfileDirectory('nero', profile.dir, profile.installAnchor)
    const homePatches = loadOptionalPatches('nero', this.homePatchPath)
    return this.entries().map(entry => ({
      entry, inherited: this.inherited(entry, loaded, homePatches),
      override: structuredClone((this.owningRows(entry.options.id, loaded.patches, homePatches).findLast(
        row => row.id === entry.options.id && row.config !== undefined,
      )?.config ?? {}) as Record<string, unknown>),
    }))
  }

  /** The configured rows of the user layer that owns `id`. */
  private owningRows(
    id: string, profilePatches: readonly PatchOptions[], homePatches: readonly PatchOptions[] | undefined,
  ): readonly PatchOptions[] {
    return this.documentPathFor(id, homePatches) === this.homePatchPath ? homePatches ?? [] : profilePatches
  }

  /**
   * Compose everything below the owning row: the bundle layers plus both user
   * layers with that row's own config removed. What remains is the value a form
   * falls back to, and the value a reset returns the row to.
   */
  private inherited(
    entry: Entry, loaded: ReturnType<typeof loadProfileDirectory>, homePatches: readonly PatchOptions[] | undefined,
  ): Record<string, unknown> {
    const withoutRow = (patches: readonly PatchOptions[]): PatchOptions[] => patches.map((patch) => {
      if (patch.id !== entry.options.id || patch.insert !== undefined) return patch
      const rest = { ...patch }; Reflect.deleteProperty(rest, 'config')
      return rest
    })
    const layers: PatchOptions[][] = [
      ...loaded.layers.map(layer => [...layer.patches]), withoutRow(loaded.patches), withoutRow(homePatches ?? []),
    ]
    const row = flatten(composeEntries(layers)).find(row => row.id === entry.options.id)
    return structuredClone((row?.config ?? {}) as Record<string, unknown>)
  }

  /** Validate, persist, and reconcile a plugin's next config; ordinary fields keep normal lifecycle rules.
   * @param entry Current Loader entry, also used to detect replacement during the write.
   * @param change Derive a raw config from the current entry and its inherited layer.
   * @returns Fulfillment after Loader reconciliation completes.
   */
  async edit(
    entry: Entry,
    change: (current: Record<string, unknown>, inherited: Record<string, unknown>) => Record<string, unknown>,
  ): Promise<void> {
    const profile = this.ownerContext.profileContext
    const id = entry.options.id
    // Writers of the shared file serialize on that file itself, so two surfaces
    // cannot interleave a read-modify-write of the same layer. A profile row
    // keeps the profile package lock it shares with package operations.
    const path = this.documentPathFor(id)
    const lock = path === this.homePatchPath ? path : join(profile.dir, 'package.json')
    const run = async (): Promise<void> => {
      await withFileLock(lock, async () => {
        if (!this.entries().includes(entry) || entry.fiber === undefined) throw new Error('Configuration entry is no longer available')
        const beforePatches = readProfilePatches('nero', profile)
        await reconcileProfilePatches(this.ownerContext.root, beforePatches, 'nero')
        if (!this.entries().includes(entry)) throw new Error('Configuration entry changed during reload')
        if (this.documentPathFor(id) !== path) throw new Error('Configuration entry moved to another layer during reload')
        const loaded = loadProfileDirectory('nero', profile.dir, profile.installAnchor)
        const current = structuredClone((entry.options.config ?? {}) as Record<string, unknown>)
        const inherited = this.inherited(entry, loaded, loadOptionalPatches('nero', this.homePatchPath))
        const next = change(current, inherited)
        const fiber = entry.fiber
        if (fiber.state !== FiberState.ACTIVE) throw new Error('Configuration plugin is no longer active')
        const resolved: unknown = fiber.ctx.waterfall(fiber, 'internal/config', next, () => next)
        resolveConfig(fiber.runtime as NonNullable<typeof fiber.runtime>, resolved)
        let before: string
        try { before = await readFile(path, 'utf8') }
        catch (error) {
          if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error
          before = '[]\n'
        }
        const document = parseDocument(before, {
          customTags: [{ tag: 'tag:yaml.org,2002:js', resolve: (value: string) => value }],
        })
        if (document.errors[0] !== undefined) throw document.errors[0]
        if (!isSeq(document.contents)) throw new Error('Profile patch must be a YAML sequence')
        document.contents.flow = false
        const index = document.contents.items.findLastIndex((item, index) => isMap(item)
          && document.getIn([index, 'id']) === entry.options.id && !item.has('insert')
          && (!item.has('name') || document.getIn([index, 'name']) === entry.options.name))
        if (isDeepStrictEqual(next, inherited)) {
          for (let index = document.contents.items.length - 1; index >= 0; index--) {
            const row = document.contents.items[index]
            if (!isMap(row) || document.getIn([index, 'id']) !== entry.options.id || row.has('insert')) continue
            row.delete('config')
            if (row.items.length === Number(row.has('id')) + Number(row.has('name'))) document.delete(index)
          }
        } else if (index < 0) document.add(document.createNode({ id: entry.options.id, name: entry.options.name, config: next }))
        else document.setIn([index, 'config'], document.createNode(next))
        visit(document, { Map(_key, node) {
          if (node.items.length !== 1 || typeof node.get('__jsExpr') !== 'string') return
          const expression = new Scalar(node.get('__jsExpr'))
          expression.tag = 'tag:yaml.org,2002:js'
          return expression
        } })
        const candidate = yaml.load(String(document), { schema: entryListSchema }) as PatchOptions[]
        const patches = path === this.homePatchPath
          ? readProfilePatches('nero', profile, loaded, candidate)
          : readProfilePatches('nero', profile, { ...loaded, patches: candidate })
        const effective = flatten(composeEntries([patches])).find(row => row.id === id)
        if (!isDeepStrictEqual(effective?.config ?? {}, next)) {
          throw new Error(`Configuration for "${id}" is overridden by a higher user layer: a command-line overlay or an insert list in a home patch`)
        }
        await writeFileAtomic(path, String(document), { mode: 0o600 })
        try {
          await reconcileProfilePatches(this.ownerContext.root, patches, 'nero', [id])
        } catch (error) {
          await writeFileAtomic(path, before, { mode: 0o600 })
          await reconcileProfilePatches(this.ownerContext.root, beforePatches, 'nero')
          throw error
        }
      })
    }
    const hmr = this.ownerContext.get('hmr')
    await (hmr === undefined ? run() : hmr.runExclusive(run))
  }
}

export default ConfigEditor
