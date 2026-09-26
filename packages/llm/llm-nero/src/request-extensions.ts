/** Prepare plugin-contributed request fields and commit their delivery after HTTP acceptance. */

import { LlmError } from '@nero/nero-llm'
import type { NeroLlmApiExtensionRequest, PreparedNeroLlmApiExtensions } from '@nero/nero-nero-llm-api-extensions'
import type { NeroAdapterOptions } from './types.ts'

/**
 * Merge contributions without replacing Messages fields. Preparation and
 * acceptance failures report REQUEST_EXTENSION.
 * @param body - serialized Messages request before extension fields.
 * @param options - request identity, purpose, and cancellation.
 * @param prepare - contributor registry captured for this adapter.
 * @returns HTTP payload and a commit to invoke only after a successful HTTP response.
 */
export async function prepareRequestExtensions(
  body: NeroLlmApiExtensionRequest['body'],
  options: Omit<NeroLlmApiExtensionRequest, 'body'>,
  prepare: NeroAdapterOptions['prepareExtensions'],
): Promise<{ payload: string; accept(): Promise<void> }> {
  let extensions: PreparedNeroLlmApiExtensions
  try {
    extensions = await prepare({ body, ...options })
  } catch (error) {
    throw new LlmError('Nero request extension preparation failed', 'REQUEST_EXTENSION', { cause: error })
  }
  for (const field of Object.keys(extensions.fields)) {
    if (Object.hasOwn(body, field)) {
      throw new LlmError(`Nero request extension field ${JSON.stringify(field)} collides with the base request`, 'REQUEST_EXTENSION')
    }
  }
  return {
    payload: JSON.stringify({ ...body, ...extensions.fields }),
    async accept() {
      try {
        await extensions.accept()
      } catch (error) {
        throw new LlmError('Nero request extension acceptance failed', 'REQUEST_EXTENSION', { cause: error })
      }
    },
  }
}
