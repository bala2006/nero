/**
 * TypeScript client SDK for the Nero Harness runtime: spawn the
 * same-version `nero --profile sdk` runtime as a subprocess and drive agent
 * turns over stdio JSON-RPC. `NeroHarness` is the high-level run API;
 * `HarnessClient` is the lower-level protocol client. A pure library — it
 * registers nothing on a Cordis context; named profiles and ordered patch
 * files customize the runtime process it spawns.
 *
 * @module @nero/nero-sdk-client
 */

export { NeroHarness, HarnessSession } from './api.ts'
export type { RunOptions } from './api.ts'
export {
  HarnessClient,
  RequestTimeoutError,
  SdkProtocolError,
  TransportClosedError,
} from './client.ts'
export type { NotificationSubscription } from './client.ts'
export { JsonRpcResponseError } from '@nero/nero-sdk-protocol'
export type {
  ContentBlock,
  SdkPromptContentBlock,
  NeroHarnessOptions,
  HarnessClientOptions,
  HarnessNotification,
  NotificationFilter,
  RunResult,
} from './types.ts'
