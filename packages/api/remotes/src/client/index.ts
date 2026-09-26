/** Platform-neutral assembly of generated Host Remote contributions. */

import type { Context } from '@nero/cordis'
import agentPresetsRemote from '@nero/nero-agent-preset-registry/remote'
import commandsRemote from '@nero/nero-commands/remote'
import accountRemote from '@nero/nero-api-account-controller/remote'
import settingsControllerRemote from '@nero/nero-api-settings-controller/remote'
import officeToPdfRemote from '@nero/nero-office-to-pdf/remote'
import goalsRemote from '@nero/nero-goal/remote'
import llmRemote from '@nero/nero-llm/remote'
import dynamicRemote from '@nero/nero-cordis-host-runner/remote'
import pluginManagerRemote from '@nero/nero-plugin-manager/remote'
import pluginRegistryProbeRemote from '@nero/nero-client-ui-plugin-manager/remote'
import pluginInventoryRemote from '@nero/nero-host-plugin-inventory/remote'
import messageFeedbackRemote from '@nero/nero-message-feedback/remote'
import permissionPresetsRemote from '@nero/nero-permission-presets/remote'
import sessionFeedbackRemote from '@nero/nero-command-feedback/remote'
import fileUploadsRemote from '@nero/nero-client-file-upload/remote'
import sessionReferencesRemote from '@nero/nero-session-reference/remote'
import subagentsRemote from '@nero/nero-subagent/remote'
import sessionRemote from '@nero/nero-api-session-controller/remote'
import jobRemote from '@nero/nero-api-job-controller/remote'
import workspaceRemote from '@nero/nero-api-workspace-controller/remote'
import terminalRemote from '@nero/nero-api-terminal-controller/remote'
import workspaceFilesRemote from '@nero/nero-api-workspace-files/remote'
import type { ClientRemote } from '@nero/nero-api-gateway/client'

export type { ClientRemote } from '@nero/nero-api-gateway/client'
export type {
  BundleInfo, BundleRowInfo, ChangeResult, InspectOptions, InstallBundleOptions, InstallSpecKind, ManagementError, PackageResult,
  PluginCatalogEntry, PluginCatalogSource, PluginChange, PluginEntryId, PluginInfo, PluginInspectProblem, PluginInstallCancellation, PluginInstallFailureKind,
  PluginInstallLogChunk, PluginInstallProgress, PluginInstallRequestId, PluginRegistries, PluginSpecInspection, ReadOnlyReason, Registry,
} from '@nero/nero-plugin-manager/types'
export type {} from '@nero/nero-plugin-manager/remote'
export type {} from '@nero/nero-client-ui-plugin-manager/remote'
export type { PluginInventorySnapshot } from '@nero/nero-host-plugin-inventory/types'
export type {} from '@nero/nero-agent-preset-registry/remote'
export type {} from '@nero/nero-commands/remote'
export type {} from '@nero/nero-api-settings-controller/remote'
export type {} from '@nero/nero-api-account-controller/remote'
export type {} from '@nero/nero-goal/remote'
export type {} from '@nero/nero-office-to-pdf/remote'
export type {} from '@nero/nero-llm/remote'
export type {} from '@nero/nero-host-plugin-inventory/remote'
export type {} from '@nero/nero-message-feedback/remote'
export type {} from '@nero/nero-permission-presets/remote'
export type {} from '@nero/nero-command-feedback/remote'
export type {} from '@nero/nero-client-file-upload/remote'
export type {} from '@nero/nero-session-reference/remote'
export type {} from '@nero/nero-subagent/remote'
export type * from '@nero/nero-subagent/client'
export type {} from '@nero/nero-api-session-controller/remote'
export type * from '@nero/nero-api-session-controller/types'
export type {} from '@nero/nero-api-job-controller/remote'
export type * from '@nero/nero-api-job-controller/types'
export type {} from '@nero/nero-api-workspace-controller/remote'
export type * from '@nero/nero-api-workspace-controller/types'
export type {} from '@nero/nero-api-workspace-files/remote'
export type * from '@nero/nero-api-workspace-files/types'
export type {} from '@nero/nero-api-terminal-controller/remote'
export type * from '@nero/nero-api-terminal-controller/types'
// The forwarded-event allowlist's selection seat: without it in the consumer's
// compilation face `TypertRemoteEvent` is `never` and every `$on` call fails.
export type { ApiRemoteForwardedEvent } from '../types.ts'
// The owner packages' client-safe `./types` exports supply the `Events`
// signatures `$on` hands to a listener, so a consumer reads the very
// declaration the Host emits rather than a flattened restatement of it.
export type {} from '@nero/nero-commands/types'
export type {} from '@nero/nero-cordis-host-runner/types'
export type {} from '@nero/nero-credentials/types'
export type {} from '@nero/nero-llm/types'
export type {} from '@nero/nero-agent-preset-registry/types'
export type {} from '@nero/nero-permission-presets/types'
export type {} from '@nero/nero-settings/types'
export type {} from '@nero/nero-user-approval/types'
export type {} from '@nero/nero-user-questions/types'
export type {} from '@nero/nero-api-session-controller/types'

/**
 * The carrier's Client-facing types, re-exported so a business package names one
 * assembly package instead of both this facade and the Connection plugin. Type-only:
 * the carrier's runtime values stay behind their own module edge.
 */
export type {
  ConnectionHandle, ConnectionSinks, ContentBlock,
  MessageId,
  RpcId, RpcRequest, RpcResponse, RpcResult, SessionId,
  StreamChunk,
} from '@nero/nero-client-connection/client'
export type {} from '@nero/nero-api-gateway/client'
export type {} from '@nero/nero-cordis-host-runner/remote'

// The payload vocabulary of the selected namespaces, re-exported so a Client
// contribution can name what it sends and receives without importing a Host
// package: this assembly is the one place both planes legitimately meet.
export type {
  ApprovalRequestId,
  CordisHalfState,
  CordisDynamicPackageId,
  CordisDynamicPluginId,
  CordisDynamicPluginRunId,
  CordisDynamicRunMode,
  CordisInspectMethodManifest,
  CordisInspectPlatform,
  CordisInspectProviderManifest,
  CordisInspectProviderView,
  CordisInspectQueryRequest,
  CordisInspectQueryResolution,
  CordisInspectQueryResolved,
  CordisInspectRequestId,
  CordisInspectResolveAck,
  CordisRunDiagnostic,
  CordisRunStatus,
  DynamicCordisClientSource,
  DynamicCordisHostHalfResult,
  DynamicCordisInventoryRow,
  DynamicCordisInvokeResult,
  DynamicCordisPackage,
  DynamicCordisRequestResolved,
  DynamicCordisResolveAck,
  DynamicCordisRetracted,
  DynamicCordisRunRequest,
  DynamicCordisRunResolution,
  DynamicCordisRunAttempt,
  DynamicCordisRunResponse,
  DynamicCordisStopResponse,
  DynamicCordisUndefineReceipt,
  RequestRunOutcome,
} from '@nero/nero-cordis-host-runner/types'
// Credential state vocabulary for the credentials namespace (values never ride it).
export type { CredentialInfo } from '@nero/nero-credentials/types'
// Redacted namespace vocabulary for the settings namespace (secrets never ride
// it). It travels with its seam, whose `./types` the Client face already reads.
export type {
  SettingsDescribeValue, SettingsNamespaceView, SettingsPathOpView, SettingsSecretView,
} from '@nero/nero-settings/types'
// Provider registry and discovery vocabulary for the llm namespace.
export type {
  LlmConfigurableProvider, LlmDiscoveredModel,
  LlmModelDiscoveryRequest, LlmProviderInfo,
} from '@nero/nero-llm/types'
// Reference-discovery result vocabulary for the fileReferences and
// sessionReferenceResolver namespaces.
export type { FileReferenceCandidate } from '@nero/nero-file-reference/types'
export type { SessionReferenceMentionCandidate } from '@nero/nero-session-reference/types'

// The Remote failure vocabulary, re-exported so business packages keep naming
// this assembly alone. Types only: a value export would make spec imports load
// this module's owner /remote artifacts; specs take RemoteError from
// nero-client-test-runtime instead.
export type {
  RemoteErrorCode, RemoteErrorDetailsMap, RemoteFailure, RemoteResult,
} from '@nero/nero-typert-protocol'
export type { RemoteHostFacts } from '@nero/nero-api-gateway/client'

declare module '@nero/cordis' {
  interface Context {
    /** Generated Remote namespaces selected by this Client assembly. */
    remote: ClientRemote
  }
}

/** Required service: the typed Client Remote contribution mount. */
export const inject = ['remote']

/**
 * Mount the Host capabilities explicitly selected for this Client assembly.
 * @param ctx - Client Cordis root carrying the typed API service.
 * @returns disposer after every selected Remote namespace is ready.
 */
export async function apply(ctx: Context): Promise<() => Promise<void>> {
  const disposers: Array<() => Promise<void>> = []
  try {
    for (const contribution of [
      agentPresetsRemote, commandsRemote, settingsControllerRemote, accountRemote, goalsRemote, llmRemote, dynamicRemote,
      pluginInventoryRemote, pluginManagerRemote, pluginRegistryProbeRemote, messageFeedbackRemote, sessionFeedbackRemote,
      fileUploadsRemote, sessionReferencesRemote,
      permissionPresetsRemote, subagentsRemote, sessionRemote, jobRemote, workspaceRemote, workspaceFilesRemote, terminalRemote,
      officeToPdfRemote,
    ]) {
      disposers.push(await ctx.remote.$mount(contribution))
    }
  } catch (error) {
    for (const dispose of disposers.reverse()) await dispose()
    throw error
  }
  // Unwound in reverse mount order, so a namespace never outlives one mounted
  // after it.
  return async () => {
    for (const dispose of disposers.reverse()) await dispose()
  }
}
