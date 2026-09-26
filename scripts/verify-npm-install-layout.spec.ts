import { describe, expect, it } from 'vitest'
import type { NpmPackageLock, RegistryIndex } from './benchmark-npm-resolution.ts'
import {
  assertDualNeroInstallLayout,
  buildDualNeroRegistry,
} from './verify-npm-install-layout.ts'

function validLayout(): NpmPackageLock {
  return {
    lockfileVersion: 3,
    packages: {
      '': { dependencies: { '@nero/nero': '0.2.0', 'nero-previous': 'npm:@nero/nero@0.1.0' } },
      'node_modules/@nero/cordis': { version: '4.0.1' },
      'node_modules/@nero/nero': {
        version: '0.2.0',
        dependencies: { '@nero/nero-child': '^0.2.0' },
        peerDependencies: { '@nero/cordis': '^4.0.1' },
      },
      'node_modules/@nero/nero-child': {
        version: '0.2.0',
        dependencies: { '@nero/nero-leaf': '^0.2.0' },
      },
      'node_modules/@nero/nero-leaf': { version: '0.2.0' },
      'node_modules/nero-previous': {
        name: '@nero/nero',
        version: '0.1.0',
        dependencies: { '@nero/nero-child': '^0.1.0' },
        peerDependencies: { '@nero/cordis': '^4.0.1' },
      },
      'node_modules/nero-previous/node_modules/@nero/nero-child': {
        version: '0.1.0',
        dependencies: { '@nero/nero-leaf': '^0.1.0' },
      },
      'node_modules/nero-previous/node_modules/@nero/nero-leaf': { version: '0.1.0' },
    },
  }
}

describe('npm install layout verifier', () => {
  it('creates two incompatible versions of every NERO package', () => {
    const index: RegistryIndex = new Map([
      ['@nero/nero', new Map([['0.1.1-rc.2', {
        name: '@nero/nero',
        version: '0.1.1-rc.2',
        dependencies: { '@nero/nero-child': '^0.1.1-rc.2' },
        peerDependencies: { '@nero/cordis': '^4.0.1' },
      }]])],
      ['@nero/nero-child', new Map([['0.1.1-rc.2', {
        name: '@nero/nero-child',
        version: '0.1.1-rc.2',
      }]])],
      ['@nero/cordis', new Map([['4.0.1', {
        name: '@nero/cordis',
        version: '4.0.1',
      }]])],
    ])

    const dual = buildDualNeroRegistry(index, '0.1.1-rc.2')

    expect([...dual.get('@nero/nero')?.keys() ?? []]).toEqual(['0.1.0', '0.2.0'])
    expect(dual.get('@nero/nero')?.get('0.1.0')).toMatchObject({
      version: '0.1.0',
      dependencies: { '@nero/nero-child': '^0.1.0' },
      peerDependencies: { '@nero/cordis': '^4.0.1' },
    })
    expect(dual.get('@nero/nero')?.get('0.2.0')).toMatchObject({
      version: '0.2.0',
      dependencies: { '@nero/nero-child': '^0.2.0' },
    })
    expect(dual.get('@nero/cordis')).toBe(index.get('@nero/cordis'))
  })

  it('accepts isolated NERO releases with one shared Cordis installation', () => {
    expect(assertDualNeroInstallLayout(validLayout())).toEqual({
      neroPackagesPerVersion: 3,
      checkedNeroEdges: 4,
    })
  })

  it.each([
    ['react', 'node_modules/react'],
    ['react-dom', 'node_modules/react-dom'],
    ['react', 'node_modules/nero-previous/node_modules/react'],
    ['react-dom', 'node_modules/nero-previous/node_modules/react-dom'],
  ])('rejects browser runtime %s installed at %s in the NERO-only consumer', (name, path) => {
    const layout = validLayout()
    const packages = { ...layout.packages, [path]: { version: '18.3.1' } }
    expect(() => assertDualNeroInstallLayout({ ...layout, packages })).toThrow(
      `${path}: ${name} is a browser build input`,
    )
  })

  it('rejects an internal edge that crosses release versions', () => {
    const layout = validLayout()
    const packages = { ...layout.packages }
    Reflect.deleteProperty(packages, 'node_modules/nero-previous/node_modules/@nero/nero-leaf')

    expect(() => assertDualNeroInstallLayout({ ...layout, packages })).toThrow(
      'node_modules/nero-previous/node_modules/@nero/nero-child: dependencies '
      + '@nero/nero-leaf resolves to node_modules/@nero/nero-leaf@0.2.0, expected 0.1.0',
    )
  })

  it('rejects a second Cordis installation', () => {
    const layout = validLayout()
    const packages = {
      ...layout.packages,
      'node_modules/nero-previous/node_modules/@nero/cordis': { version: '4.0.1' },
    }

    expect(() => assertDualNeroInstallLayout({ ...layout, packages })).toThrow(
      'expected one shared @nero/cordis',
    )
  })
})
