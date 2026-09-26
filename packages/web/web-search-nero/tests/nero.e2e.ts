import { describe, expect, it } from 'vitest'
import {
  NeroSearchProvider,
  NERO_DEFAULT_API_VERSION,
  NERO_DEFAULT_BASE_URL,
  NERO_DEFAULT_MAX_TOKENS,
  NERO_DEFAULT_MAX_USES,
  NERO_DEFAULT_MODEL,
} from '@nero/nero-web-search-nero'

/** Construct the provider over a fixed options value; production passes a live thunk. */
import type { NeroSearchProviderOptions } from '@nero/nero-web-search-nero'

const searchProvider = (options: NeroSearchProviderOptions): NeroSearchProvider =>
  new NeroSearchProvider(() => options)

/**
 * Disabled real-API probe for the Nero search provider. The live endpoint
 * can complete without structured source blocks, so this is not a reliable
 * merge signal. Its body remains because mocks cannot confirm the wire shape.
 */
const apiKey = process.env.NERO_API_KEY
const maybe = apiKey !== undefined && apiKey.length > 0 ? describe : describe.skip

maybe('NeroSearchProvider real API', () => {
  it.skip('returns citeable sources for a live query via native web_search', async () => {
    const provider = searchProvider({
      apiKey: apiKey!,
      baseURL: process.env.NERO_SEARCH_BASE_URL ?? NERO_DEFAULT_BASE_URL,
      model: process.env.NERO_SEARCH_MODEL ?? NERO_DEFAULT_MODEL,
      apiVersion: NERO_DEFAULT_API_VERSION,
      maxTokens: NERO_DEFAULT_MAX_TOKENS,
      maxUses: NERO_DEFAULT_MAX_USES,
    })
    const result = await provider.search({ query: 'What is Nero Harness?', maxResults: 5 })
    expect(result.sources.length).toBeGreaterThan(0)
    for (const source of result.sources) expect(source.url).toMatch(/^https?:\/\//)
  }, 60_000)
})
