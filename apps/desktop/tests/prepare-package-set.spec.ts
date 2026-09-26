import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  assertDesktopHostPackageFiles,
  selectDesktopPackageClosure,
  type PackedDesktopPackage,
} from '../scripts/prepare-package-set.ts'

function packed(name: string, manifest: Record<string, unknown> = {}): PackedDesktopPackage {
  return { tarball: `${name}.tgz`, manifest: { name, version: '1.0.0', ...manifest } }
}

describe('desktop package-set selection', () => {
  afterEach(() => {
    vi.unstubAllEnvs()
  })

  it('does not select a packaging target when imported as a library', async () => {
    vi.stubEnv('NERO_DESKTOP_TARGET_PLATFORM', 'linux')
    vi.stubEnv('NERO_DESKTOP_TARGET_ARCH', 'x64')
    vi.resetModules()
    await expect(import('../scripts/prepare-package-set.ts')).resolves.toHaveProperty('prepareDesktopPackageSet')
  })

  it('includes only the available internal production closure', () => {
    const available = new Map<string, PackedDesktopPackage>([
      ['@nero/nero', packed('@nero/nero', {
        dependencies: { '@nero/nero-base': '^1.0.0', external: '^2.0.0' },
        optionalDependencies: { '@nero/platform-package': '1.0.0', '@nero/missing-platform': '1.0.0' },
      })],
      ['@nero/nero-desktop-host', packed('@nero/nero-desktop-host', {
        dependencies: { '@nero/nero': '^1.0.0' },
      })],
      ['@nero/nero-base', packed('@nero/nero-base', {
        peerDependencies: { '@nero/cordis': '^1.0.0' },
      })],
      ['@nero/cordis', packed('@nero/cordis')],
      ['@nero/platform-package', packed('@nero/platform-package')],
      ['@nero/unused', packed('@nero/unused')],
    ])
    expect(selectDesktopPackageClosure(available).map(entry => entry.manifest.name)).toEqual([
      '@nero/cordis',
      '@nero/nero',
      '@nero/nero-base',
      '@nero/nero-desktop-host',
      '@nero/platform-package',
    ])
  })

  it.each([
    '@nero/nero-base', '@nero/cordis', '@nero/node-addon-system',
  ])('rejects required prepared package %s absent from the packed release inputs', (dependency) => {
    const available = new Map<string, PackedDesktopPackage>([
      ['@nero/nero', packed('@nero/nero', {
        dependencies: { [dependency]: '^1.0.0' },
      })],
      ['@nero/nero-desktop-host', packed('@nero/nero-desktop-host', {
        dependencies: { '@nero/nero': '^1.0.0' },
      })],
    ])
    expect(() => selectDesktopPackageClosure(available)).toThrow(/unpacked package/u)
    expect(() => selectDesktopPackageClosure(new Map([
      ['@nero/nero', packed('@nero/nero')],
    ]))).toThrow(/omit @nero\/nero-desktop-host/u)
  })

  it('leaves independently published Office packages to npm resolution', () => {
    const available = new Map<string, PackedDesktopPackage>([
      ['@nero/nero', packed('@nero/nero', {
        dependencies: {
          '@deepseek-ai/libreoffice-kit': '0.0.1',
          '@deepseek-ai/libreoffice-kit-wasm': '0.0.1',
        },
      })],
      ['@nero/nero-desktop-host', packed('@nero/nero-desktop-host')],
    ])
    expect(selectDesktopPackageClosure(available).map(entry => entry.manifest.name)).toEqual([
      '@nero/nero', '@nero/nero-desktop-host',
    ])
  })

  it('requires the Desktop Host entry', () => {
    const files = [
      'package/lib/index.js',
    ]
    expect(() => {
      assertDesktopHostPackageFiles(files)
    }).not.toThrow()
    expect(() => {
      assertDesktopHostPackageFiles(files.slice(1))
    }).toThrow(/lib\/index\.js/u)
  })
})
