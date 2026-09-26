/**
 * Resolve the public SDK launch configuration to one nero subprocess.
 * @module @nero/nero-sdk-client/launch
 */

import { existsSync, readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import type { HarnessClientOptions } from './types.ts'

/** Default bound for a profile to answer the SDK initialize handshake. */
export const DEFAULT_INITIALIZE_TIMEOUT_MS = 10_000

/** Internal generic process launch used by the transport and fake-runtime tests. */
export interface RuntimeProcessOptions {
  command: string
  args: string[]
  cwd?: string
  /** Materialize the complete child environment when the client starts its subprocess. */
  environment: () => NodeJS.ProcessEnv
  description: string
  initializeTimeoutMs: number
  requestTimeoutMs?: number
  shutdownTimeoutMs?: number
  disposeEofGraceMs?: number
  disposeGraceMs?: number
}

/** Node argv plus internal profile patches required by one resolved nero entry. */
export interface NeroNodeLaunch {
  /** Arguments before the profile selector. */
  nodeArgs: string[]
  /** Internal patches applied below caller-supplied patches. */
  patches: string[]
  /** Environment values required by the resolved entry mode. */
  environment: NodeJS.ProcessEnv
}

interface PackageManifest {
  version?: unknown
  bin?: unknown
}

/** Read a package manifest from one resolved package.json URL. */
function manifest(url: string): PackageManifest {
  return JSON.parse(readFileSync(fileURLToPath(url), 'utf8')) as PackageManifest
}

/**
 * Resolve and version-check a nero executable from package manifests.
 * @param neroManifestUrl - resolved URL of the nero package manifest.
 * @param clientManifestUrl - resolved URL of the SDK client manifest.
 * @returns the absolute nero executable path.
 */
export function resolveNeroBinFromManifests(neroManifestUrl: string, clientManifestUrl: string): string {
  const neroManifest = manifest(neroManifestUrl)
  const clientManifest = manifest(clientManifestUrl)
  if (typeof neroManifest.version !== 'string' || neroManifest.version !== clientManifest.version) {
    throw new Error(`nero SDK client ${String(clientManifest.version)} requires the same nero version, got ${String(neroManifest.version)}`)
  }
  const bin = typeof neroManifest.bin === 'object' && neroManifest.bin !== null
    ? (neroManifest.bin as Record<string, unknown>).nero
    : neroManifest.bin
  if (typeof bin !== 'string' || bin === '') throw new Error('@nero/nero declares no nero executable')
  return resolve(dirname(fileURLToPath(neroManifestUrl)), bin)
}

/**
 * Resolve and version-check the built nero executable installed with this SDK.
 * @returns the absolute built executable path, whether or not it exists in a source checkout.
 */
export function installedNeroBin(): string {
  return resolveNeroBinFromManifests(
    import.meta.resolve('@nero/nero/package.json'),
    new URL('../package.json', import.meta.url).href,
  )
}

/**
 * Resolve the Node launch for one same-version nero package.
 * @param neroManifestUrl - resolved URL of the nero package manifest.
 * @param clientManifestUrl - resolved URL of the SDK client manifest.
 * @param sourceLoaderUrl - optional absolute tsx loader URL for deterministic tests.
 * @returns built output, or the source entry plus its compatibility patch and tsx environment.
 */
export function resolveNeroNodeLaunchFromManifests(
  neroManifestUrl: string,
  clientManifestUrl: string,
  sourceLoaderUrl?: string,
): NeroNodeLaunch {
  const bin = resolveNeroBinFromManifests(neroManifestUrl, clientManifestUrl)
  if (existsSync(bin)) return { nodeArgs: [bin], patches: [], environment: {} }

  const packageDir = dirname(fileURLToPath(neroManifestUrl))
  const sourceBin = resolve(packageDir, 'src/bin.ts')
  const sourcePatch = resolve(packageDir, 'src/sdk-source.cordis.patch.yml')
  const sourceTsconfig = resolve(packageDir, 'tsconfig.json')
  if (!existsSync(sourceBin) || !existsSync(sourcePatch) || !existsSync(sourceTsconfig)) {
    throw new Error(
      `@nero/nero is missing its built executable ${bin} and complete source launch files ${sourceBin}, ${sourcePatch}, ${sourceTsconfig}`,
    )
  }
  const loader = sourceLoaderUrl ?? import.meta.resolve('tsx/esm')
  return {
    nodeArgs: ['--import', loader, sourceBin],
    patches: [sourcePatch],
    environment: { TSX_TSCONFIG_PATH: sourceTsconfig },
  }
}

/**
 * Resolve the installed nero package to a built or source Node launch.
 * @returns the launch descriptor for the current checkout or installed package.
 */
function installedNeroNodeLaunch(): NeroNodeLaunch {
  return resolveNeroNodeLaunchFromManifests(
    import.meta.resolve('@nero/nero/package.json'),
    new URL('../package.json', import.meta.url).href,
  )
}

/**
 * Resolve caller-relative filesystem inputs and construct canonical nero argv.
 * @param options - public SDK launch options.
 * @param callerCwd - parent-process directory used for lexical resolution.
 * @returns one generic subprocess spec for the JSON-RPC transport.
 */
export function resolveNeroLaunch(
  options: HarnessClientOptions = {},
  callerCwd: string = process.cwd(),
): RuntimeProcessOptions {
  const profile = options.profile ?? 'sdk'
  const neroLaunch = options.neroBin === undefined
    ? installedNeroNodeLaunch()
    : { nodeArgs: [resolve(callerCwd, options.neroBin)], patches: [], environment: {} }
  const patches = [
    ...neroLaunch.patches,
    ...(options.patches ?? []).map(path => resolve(callerCwd, path)),
  ]
  const neroHome = options.neroHome === undefined ? undefined : resolve(callerCwd, options.neroHome)
  return {
    command: process.execPath,
    args: [...neroLaunch.nodeArgs, '--profile', profile, ...patches.flatMap(path => ['--patch', path])],
    ...options.processCwd === undefined ? {} : { cwd: resolve(callerCwd, options.processCwd) },
    environment: () => ({
      ...(options.env ?? process.env),
      ...neroLaunch.environment,
      ...neroHome === undefined ? {} : { NERO_HOME: neroHome },
    }),
    description: `nero profile ${JSON.stringify(profile)}`,
    initializeTimeoutMs: options.initializeTimeoutMs ?? DEFAULT_INITIALIZE_TIMEOUT_MS,
    ...options.requestTimeoutMs === undefined ? {} : { requestTimeoutMs: options.requestTimeoutMs },
    ...options.shutdownTimeoutMs === undefined ? {} : { shutdownTimeoutMs: options.shutdownTimeoutMs },
    ...options.disposeEofGraceMs === undefined ? {} : { disposeEofGraceMs: options.disposeEofGraceMs },
    ...options.disposeGraceMs === undefined ? {} : { disposeGraceMs: options.disposeGraceMs },
  }
}
