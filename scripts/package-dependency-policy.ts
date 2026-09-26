/** Explicit exceptions and Host packages for the published dependency policy. */

/** Packages treated as Client/Host packages without declaring `nero.client`. */
const CLIENT_FACE_INCLUDE: readonly string[] = []

/** Packages exempted from automatic Client/Host treatment despite declaring `nero.client`. */
const CLIENT_FACE_EXCLUDE: readonly string[] = [
  '@nero/nero-api-session-controller',
  '@nero/nero-api-workspace-controller',
]

/** Host-only packages whose peer relays are deliberately flattened. */
const HOST_DEPENDENCY_PACKAGES: readonly string[] = [
  '@nero/nero-llm',
  '@nero/nero-session',
]

/** Development-only package relationships not represented by source imports. */
const CONFIGURATION_ONLY_DEV_DEPENDENCIES = {
  '@nero/nero-client-locale': ['@nero/nero-api-remotes'],
  '@nero/nero-client-ui-conversation': [
    '@nero/nero-api-remotes',
    '@nero/nero-client-ui-workspace',
  ],
  '@nero/nero-client-ui-model-selection': ['@nero/nero-client-ui-input-trigger'],
  '@nero/nero-client-ui-sidebar': ['@nero/nero-client-ui-workspace'],
  '@nero/nero-client-ui-subagent': ['@nero/nero-client-ui-input-trigger'],
  '@nero/nero-client-ui-theme': ['@nero/nero-api-remotes'],
  '@nero/nero-client-ui-tool': ['@nero/nero-api-remotes'],
} as const satisfies Readonly<Record<string, readonly string[]>>

/** Workspace packages whose complete runtime surface is safe across duplicate installations. */
const DUPLICATE_SAFE_PACKAGES: readonly string[] = [
  '@nero/nero-brand',
  '@nero/nero-lazy-require',
  '@nero/nero-typert-protocol',
  '@nero/nero-util-crypto',
  '@nero/nero-util-values',
]

/**
 * Runtime exports whose values remain valid when npm installs another package copy.
 * New entries are forbidden by default. Automated agents must not add an
 * exception; every addition requires explicit human review and a dedicated,
 * prominent heading in the pull request description.
 */
const SAFE_HOST_DEPENDENCY_EXPORTS = {
  '@nero/nero-credentials': ['credentialKey'],
  '@nero/nero-deque': ['Deque'],
  '@nero/nero-llm': ['callConfigEquals'],
  '@nero/nero-session-format': ['sessionFormatLogFilename'],
  '@nero/nero-timeout': ['MAX_TIMER_DELAY_MS'],
  '@nero/schemastery': ['default'],
} as const satisfies HostDependencyExports

/** Runtime exports that require every consumer to resolve the provider's shared peer instance. */
const PEER_REQUIRED_HOST_EXPORTS = {
  '@nero/nero-client-connection': ['OperatorPeer'],
  '@nero/nero-subprocess': ['SubprocessExecutableNotFoundError'],
  '@nero/nero-scope': ['carrierKeyOf', 'createScope', 'scopeOf', 'scopeTarget'],
  '@nero/nero-session': ['SESSION_FORMAT_VERSION'],
  '@nero/nero-session-persistence': ['SessionPersistenceNotFoundError'],
} as const satisfies HostDependencyExports

/** Exact import specifier to reviewed runtime exports. */
type HostDependencyExports = Readonly<Record<string, readonly string[]>>

/** Complete configurable input to package dependency classification. */
export interface PackageDependencyPolicy {
  readonly clientFaceInclude: readonly string[]
  readonly clientFaceExclude: readonly string[]
  readonly hostPackages: readonly string[]
  readonly configurationOnlyDevDependencies: Readonly<Record<string, readonly string[]>>
  readonly duplicateSafePackages?: readonly string[]
  readonly safeHostDependencyExports: HostDependencyExports
  readonly peerRequiredHostExports: HostDependencyExports
}

/** Repository dependency policy consumed by verification and benchmarking. */
export const PACKAGE_DEPENDENCY_POLICY: PackageDependencyPolicy = {
  clientFaceInclude: CLIENT_FACE_INCLUDE,
  clientFaceExclude: CLIENT_FACE_EXCLUDE,
  hostPackages: HOST_DEPENDENCY_PACKAGES,
  configurationOnlyDevDependencies: CONFIGURATION_ONLY_DEV_DEPENDENCIES,
  duplicateSafePackages: DUPLICATE_SAFE_PACKAGES,
  safeHostDependencyExports: SAFE_HOST_DEPENDENCY_EXPORTS,
  peerRequiredHostExports: PEER_REQUIRED_HOST_EXPORTS,
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

/** Whether a package manifest declares a dynamically loaded Client entry. */
export function hasClientDeclaration(neroField: unknown): boolean {
  return isRecord(neroField) && Object.hasOwn(neroField, 'client')
}

/** Whether the repository policy flattens one package's non-Cordis peers. */
export function usesFlattenedPackageDependencies(
  manifestPath: string,
  packageName: string,
  neroField: unknown,
  policy: PackageDependencyPolicy = PACKAGE_DEPENDENCY_POLICY,
): boolean {
  if (!manifestPath.startsWith('packages/') || manifestPath.startsWith('packages/experimental/')) return false
  if (policy.hostPackages.includes(packageName)) return true
  if (manifestPath.startsWith('packages/client/')) return true
  const included = hasClientDeclaration(neroField) || policy.clientFaceInclude.includes(packageName)
  return included && !policy.clientFaceExclude.includes(packageName)
}
