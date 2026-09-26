/** Real profile patches, Loader updates, and consumers of live Config references. */
import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { onTestFinished } from 'vitest'
import { Context } from '@nero/cordis'
import z from '@nero/schemastery'
import Timer from '@nero/cordis-plugin-timer'
import type { PatchOptions } from '@nero/cordis-plugin-include'
import { boot, initProfile, readProfilePatches, type ProfileContext } from '@nero/nero-app-boot'
import ConfigEditor from '@nero/nero-config-editor'
import Hmr from '@nero/nero-hmr'
import DefaultModel from '@nero/nero-agent-default-model'
import Settings from '../src/index.ts'

export async function configurationFixture(options: {
  schema?: z
  apply?: (ctx: Context, config: unknown) => void
  hmr?: boolean
  /** Launch-time command-line overlays, applied above both user layers. */
  overlays?: PatchOptions[]
} = {}) {
  const home = realpathSync(mkdtempSync(join(tmpdir(), 'settings-config-')))
  const dir = join(home, 'profiles', 'test')
  onTestFinished(() => { rmSync(home, { recursive: true, force: true }) })
  initProfile(dir, ['test-bundle'])
  const bundle = join(dir, 'node_modules', 'test-bundle')
  mkdirSync(bundle, { recursive: true })
  writeFileSync(join(home, 'package.json'), '{"name":"test-installation"}\n')
  writeFileSync(join(bundle, 'package.json'), JSON.stringify({ name: 'test-bundle', version: '1.0.0', nero: { bundle: { patch: 'cordis.patch.yml' } } }))
  writeFileSync(join(bundle, 'cordis.patch.yml'), JSON.stringify([{ insert: [
    { id: 'config-editor', name: 'cordis:editor' },
    { id: 'settings', name: 'cordis:settings' },
    { id: 'default-model', name: 'cordis:model', config: { provider: 'test', model: 'original' } },
    { id: 'first', name: 'cordis:probe', config: { ordinary: 'fixed', token: 'private' } },
    { id: 'second', name: 'cordis:probe', config: { ordinary: 'second' } },
  ] }]))
  writeFileSync(join(dir, 'cordis.yml'), '[]\n')
  const profile: ProfileContext = {
    name: 'test', startedBundles: ['test-bundle'], dir, patchPath: join(dir, 'cordis.patch.yml'),
    installAnchor: join(home, 'package.json'), cwd: home, home, overlays: options.overlays ?? [],
    telemetryDisabledEnv: undefined,
  }
  const Probe = {
    Config: options.schema ?? z.object({ ordinary: z.string().required(), count: z.number().min(1).default(2).volatile(), token: z.string().role('secret').volatile(), list: z.array(z.object({ name: z.string().required(), token: z.string().role('secret') })).volatile() }),
    apply: options.apply ?? (() => {}),
  }
  const start = async (): Promise<Context> => {
    const ctx = await boot('test', join(dir, 'cordis.yml'), readProfilePatches('test', profile), (ctx) => {
      ctx.provide('profileContext', profile)
      ctx.provide('appReady', { onReady: (listener: () => void) => { listener(); return () => {} } })
      Object.assign(ctx.loader.builtins, {
        editor: ConfigEditor, settings: Settings, model: DefaultModel, probe: Probe,
      })
    })
    onTestFinished(async () => { await ctx.fiber.dispose() })
    if (options.hmr !== false) {
      await ctx.plugin(Timer)
      const hmr = ctx.plugin(Hmr, { root: [], ignored: [], debounce: 0 })
      await hmr.await()
      await ctx.hmr.runExclusive(async () => {})
    }
    return ctx
  }
  return { ctx: await start(), profile, home, start }
}
