import { mkdir, mkdtemp, realpath, rm, symlink, writeFile } from 'node:fs/promises'
import { homedir, tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  DEFAULT_NERO_HOME_DISPLAY,
  NERO_HOME_DIR_NAME,
  canonicalizeWatchPath,
  defaultNeroHome,
  neroCachePath,
  neroHomeDisplay,
  neroHomePath,
  expandHomePath,
  resolveNeroHome,
} from '@nero/nero-home-paths'

afterEach(() => {
  vi.unstubAllEnvs()
})

describe('nero path helpers', () => {
  it('owns the shared default NERO home directory name', () => {
    expect(NERO_HOME_DIR_NAME).toBe('.nero')
    expect(DEFAULT_NERO_HOME_DISPLAY).toBe('~/.nero')
    expect(defaultNeroHome()).toBe(join(homedir(), '.nero'))
  })

  it('expands tilde paths without changing non-tilde paths', () => {
    expect(expandHomePath('~')).toBe(homedir())
    expect(expandHomePath('~/.nero')).toBe(join(homedir(), '.nero'))
    expect(expandHomePath('~\\.nero')).toBe(join(homedir(), '.nero'))
    expect(expandHomePath('/tmp/.nero')).toBe('/tmp/.nero')
    expect(expandHomePath('~other/.nero')).toBe('~other/.nero')
  })

  it('resolves explicit path before NERO_HOME and the default', () => {
    const envHome = join(homedir(), 'env-nero')

    expect(resolveNeroHome('/tmp/explicit-nero', { NERO_HOME: '~/env-nero' })).toBe(resolve('/tmp/explicit-nero'))
    expect(resolveNeroHome(undefined, { NERO_HOME: '~/env-nero' })).toBe(envHome)
    expect(resolveNeroHome(undefined, {})).toBe(defaultNeroHome())
  })

  it('treats an empty or whitespace-only NERO_HOME as unset', () => {
    expect(resolveNeroHome(undefined, { NERO_HOME: '' })).toBe(defaultNeroHome())
    expect(resolveNeroHome(undefined, { NERO_HOME: '   ' })).toBe(defaultNeroHome())
  })

  it('joins child segments onto the resolved NERO_HOME', () => {
    vi.stubEnv('NERO_HOME', '~/env-nero')
    expect(neroHomePath()).toBe(join(homedir(), 'env-nero'))
    expect(neroHomePath('storages', 'cache')).toBe(join(homedir(), 'env-nero', 'storages', 'cache'))
  })

  it('labels a resolved home by whether it is the default root', () => {
    expect(neroHomeDisplay(resolve(defaultNeroHome()))).toBe('~/.nero')
    expect(neroHomeDisplay('/some/other/root')).toBe('$NERO_HOME')
  })

  it.each([
    [undefined, join(homedir(), '.nero')],
    ['', join(homedir(), '.nero')],
    ['   ', join(homedir(), '.nero')],
    ['~/env-nero', join(homedir(), 'env-nero')],
    ['./relative-nero', resolve('./relative-nero')],
  ] as const)('resolves cache paths with NERO_HOME=%j', (home, expectedHome) => {
    vi.stubEnv('NERO_HOME', home)
    try {
      expect(neroCachePath()).toBe(join(expectedHome, 'cache'))
      expect(neroCachePath('models', 'index.json')).toBe(join(expectedHome, 'cache', 'models', 'index.json'))
    } finally {
      vi.unstubAllEnvs()
    }
  })

  it('resolves configured cache homes before the environment', () => {
    vi.stubEnv('NERO_HOME', '~/env-nero')
    try {
      expect(neroCachePath({ neroHome: '~/explicit-nero' })).toBe(join(homedir(), 'explicit-nero', 'cache'))
      expect(neroCachePath({ neroHome: './explicit-nero' }, 'attachments', 'request-images'))
        .toBe(resolve('./explicit-nero/cache/attachments/request-images'))
      expect(neroCachePath({}, 'attachments')).toBe(join(homedir(), 'env-nero', 'cache', 'attachments'))
    } finally {
      vi.unstubAllEnvs()
    }
  })

  it('canonicalizes a watcher ancestor while preserving a missing suffix', async () => {
    const root = await mkdtemp(join(tmpdir(), 'nero-watch-path-'))
    const target = join(root, 'target')
    const alias = join(root, 'alias')
    try {
      await mkdir(target)
      await symlink(target, alias, process.platform === 'win32' ? 'junction' : 'dir')
      await expect(canonicalizeWatchPath(alias)).resolves.toBe(await realpath(target))
      await expect(canonicalizeWatchPath(join(alias, 'later', 'config.yml'))).resolves.toBe(
        join(await realpath(target), 'later', 'config.yml'),
      )
      const file = join(root, 'file')
      await writeFile(file, 'not a directory')
      await expect(canonicalizeWatchPath(join(file, 'child'))).rejects.toMatchObject({ code: 'ENOTDIR' })
    } finally {
      await rm(root, { recursive: true, force: true })
    }
  })
})
