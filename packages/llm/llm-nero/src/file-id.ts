/** Nero Files API identifiers. @module nero-llm-nero/file-id */

import type { Branded } from '@nero/nero-brand'

/** Opaque identifier returned by the Nero Files API. */
export type NeroFileId = Branded<'NeroFileId'>

/**
 * Brand a provider-returned file identifier after wire validation.
 * @param id - non-empty Files API identifier.
 * @returns the same string with its provider identity attached at type level.
 */
export function NeroFileId(id: string): NeroFileId {
  return id as NeroFileId
}

/** Non-secret digest identifying one endpoint and API-key file namespace. */
export type NeroFileScope = Branded<'NeroFileScope'>

/**
 * Brand a locally derived namespace digest.
 * @param scope - SHA-256 digest of endpoint and API key.
 * @returns the same string with namespace identity attached at type level.
 */
export function NeroFileScope(scope: string): NeroFileScope {
  return scope as NeroFileScope
}
