import { describe, expect, it } from 'vitest'
import { Context } from '@nero/cordis'
import InvariantRegistry from '@nero/nero-invariants'
import { credentialRef } from '../src/index.ts'
import * as CredentialsInvariant from '../src/invariant.ts'
import { MemoryCredentials } from './memory.ts'

const REF = credentialRef('NERO_API_KEY')

describe('credentials invariant companion', () => {
  it('accepts a committed change emitted by a live service', async () => {
    const ctx = new Context()
    await ctx.plugin(InvariantRegistry)
    await ctx.plugin(CredentialsInvariant)
    await ctx.plugin(MemoryCredentials)

    await expect(ctx.credentials.set(REF, 'sk-live')).resolves.toBeUndefined()
  })

  it('fails an update event emitted without a live service', async () => {
    const ctx = new Context()
    await ctx.plugin(InvariantRegistry)
    await ctx.plugin(CredentialsInvariant)

    expect(() => { ctx.emit('credentials/reference-updated', REF) }).toThrow(/invariant violated by "@nero\/nero-credentials"/)
  })

  it('reserves the package name against duplicate registration', async () => {
    const ctx = new Context()
    await ctx.plugin(InvariantRegistry)
    await ctx.plugin(CredentialsInvariant)

    expect(() => {
      ctx.invariants.register('@nero/nero-credentials', () => {})
    }).toThrow(/already registered/)
  })
})
