/** Provider-specific JSON and contribution types for Nero request extensions. */

/** Lossless JSON value accepted by the Nero request body. */
export type NeroLlmApiJson =
  | null
  | boolean
  | number
  | string
  | NeroLlmApiJson[]
  | { [key: string]: NeroLlmApiJson }

/**
 * Merge-extensible table of top-level Nero request extension fields.
 * Contributor packages declaration-merge the field they own.
 */
export interface NeroLlmApiExtensionMap {}

/** Exact serialized request facts visible to extension providers. */
export interface NeroLlmApiExtensionRequest {
  /** Base Nero request body before extension fields are merged. */
  readonly body: Readonly<Record<string, NeroLlmApiJson>>
  /** Session identity carried by the model request, when present. */
  readonly sessionId?: string
  /** Auxiliary request classification, when present. */
  readonly purpose?: 'compaction' | 'session-title'
  /** Cancellation for request preparation; providers must stop promptly after abort. */
  readonly signal: AbortSignal
}

/** One prepared field value and its optional post-2xx commit. */
export interface PreparedNeroLlmApiExtension<T extends NeroLlmApiJson> {
  /** Detached value merged under the provider's registered field. */
  readonly value: T
  /** Commit state that depends on confirmed provider acceptance. */
  accept?(): void | Promise<void>
}

/** Provider registered under one key of {@link NeroLlmApiExtensionMap}. */
export interface NeroLlmApiExtensionProvider<T extends NeroLlmApiJson> {
  /**
   * Prepare one field for an exact serialized request.
   * @param request - immutable base request facts.
   * @returns the prepared field, or `undefined` when this request has no value for it.
   */
  prepare(
    request: NeroLlmApiExtensionRequest,
  ): PreparedNeroLlmApiExtension<T> | undefined | Promise<PreparedNeroLlmApiExtension<T> | undefined>
}

/** All fields prepared for one request plus their joint acceptance transaction. */
export interface PreparedNeroLlmApiExtensions {
  /** Detached top-level fields to merge into the base request. */
  readonly fields: Readonly<Partial<NeroLlmApiExtensionMap>>
  /**
   * Commit every captured provider after HTTP 2xx. Repeated calls join the same settlement.
   * @returns fulfillment after every commit succeeds.
   */
  accept(): Promise<void>
}
