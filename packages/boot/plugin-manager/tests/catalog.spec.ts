/** Reading a catalog entry's spec into the package it installs, and the list a stock installation offers. */

import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { describe, expect, it, onTestFinished } from 'vitest'
import { catalogPackageName, DEFAULT_CATALOG } from '@nero/nero-plugin-manager'

/** A temporary directory holding the named files, removed when the test finishes. */
function directory(files: Record<string, string> = {}): string {
  const root = mkdtempSync(join(tmpdir(), 'plugin-catalog-'))
  onTestFinished(() => { rmSync(root, { recursive: true, force: true }) })
  for (const [name, content] of Object.entries(files)) writeFileSync(join(root, name), content)
  return root
}

describe('catalogPackageName', () => {
  it('reads a registry name as the spec spells it, dropping any version range', async () => {
    expect(await catalogPackageName('nero-x')).toBe('nero-x')
    expect(await catalogPackageName(' @acme/nero-x@^1.2 ')).toBe('@acme/nero-x')
  })

  it("reads a local directory's own manifest name", async () => {
    const root = directory({ 'package.json': JSON.stringify({ name: '@acme/nero-local' }) })
    expect(await catalogPackageName(root)).toBe('@acme/nero-local')
  })

  it('names no package for a directory without a readable manifest, a directory whose manifest names none, a git address, a tarball, or a refused spec', async () => {
    expect(await catalogPackageName(directory())).toBeUndefined()
    expect(await catalogPackageName(directory({ 'package.json': '{' }))).toBeUndefined()
    expect(await catalogPackageName(directory({ 'package.json': '{}' }))).toBeUndefined()
    expect(await catalogPackageName('https://github.com/acme/nero-plugin')).toBeUndefined()
    expect(await catalogPackageName('/packs/nero-x-1.0.0.tgz')).toBeUndefined()
    expect(await catalogPackageName('not a spec')).toBeUndefined()
  })
})

describe('DEFAULT_CATALOG', () => {
  it('offers the published experimental packages a stock installation can install by name', () => {
    expect(DEFAULT_CATALOG.map(entry => entry.spec)).toEqual(['@nero/nero-experimental-auto-review'])
    expect(DEFAULT_CATALOG.every(entry => entry.title !== undefined && entry.description !== undefined)).toBe(true)
  })
})
