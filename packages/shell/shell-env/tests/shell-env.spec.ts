/**
 * Registry tests for `@nero/nero-shell-env`: built-in facts, contributor
 * ownership and validation, collection ordering, effect-scoped disposal, and
 * the explicit disposer contract.
 */

import { homedir } from 'node:os'
import { join, resolve } from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { Context } from '@nero/cordis'
import { ToolCallId } from '@nero/nero-llm'
import type { Agent } from '@nero/nero-agent'
import { SESSION_FORMAT_VERSION } from '@nero/nero-session'
import type { ToolExecution } from '@nero/nero-tools'
import { ShellEnvRegistry } from '@nero/nero-shell-env'
import * as BashEnvPlugin from '@nero/nero-shell-env'

const testToolSignal = new AbortController().signal

afterEach(() => vi.unstubAllEnvs())

function execution(sessionId?: string): ToolExecution {
  return {
    signal: testToolSignal,
    token: Symbol('bash-env-test') as ToolExecution['token'],
    callId: ToolCallId('bash-env-call'),
    rootCallId: ToolCallId('bash-env-call'),
    name: 'bash',
    arguments: { command: 'true' },
    ...(sessionId === undefined
      ? {}
      : {
        agent: {
          session: {
            header: { version: SESSION_FORMAT_VERSION, id: sessionId, createdAt: 0, isSeeded: false },
          },
        } as unknown as Agent,
      }),
  }
}

describe('ShellEnvRegistry', () => {
  it('collects unconditional shell facts and the current agent session id', () => {
    const ctx = new Context()
    const registry = new ShellEnvRegistry(ctx, { neroHome: './test-nero-home' })

    expect(registry.collect(execution())).toEqual({
      NERO_HOME: resolve('./test-nero-home'),
      NERO_SHELL: '1',
    })
    expect(registry.collect(execution('session-a'))).toEqual({
      NERO_HOME: resolve('./test-nero-home'),
      NERO_SESSION_ID: 'session-a',
      NERO_SHELL: '1',
    })
  })

  it('collects the launcher-provided profile name and directory when a profile context exists', () => {
    const ctx = new Context()
    ctx.provide('profileContext', {
      name: 'web', dir: '/profiles/web', patchPath: '/profiles/web/cordis.patch.yml', installAnchor: '/nero/package.json',
      cwd: '/work', home: '/home', startedBundles: [], overlays: [], telemetryDisabledEnv: undefined,
    })
    const registry = new ShellEnvRegistry(ctx, { neroHome: './test-nero-home' })
    expect(registry.collect(execution())).toMatchObject({ NERO_PROFILE: 'web', NERO_PROFILE_DIR: '/profiles/web' })
    expect(() => registry.register({
      name: 'profile-claimer',
      variables: { NERO_PROFILE: { description: 'Reserved key.' } },
      resolve: () => ({}),
    })).toThrow(/reserved key "NERO_PROFILE"/)
  })

  it('resolves NERO_HOME from the ambient override or the user-home default', () => {
    vi.stubEnv('NERO_HOME', './ambient-nero-home')
    const fromEnvironment = new ShellEnvRegistry(new Context())
    expect(fromEnvironment.collect(execution()).NERO_HOME).toBe(resolve('./ambient-nero-home'))

    vi.stubEnv('NERO_HOME', undefined)
    const fromDefault = new ShellEnvRegistry(new Context())
    expect(fromDefault.collect(execution()).NERO_HOME).toBe(join(homedir(), '.nero'))
  })

  it('collects declared contributor variables and omits unavailable values', () => {
    const ctx = new Context()
    const registry = new ShellEnvRegistry(ctx, { neroHome: './test-nero-home' })
    registry.register({
      name: 'optional-session-fact',
      variables: {
        NERO_SESSION_OPTIONAL: { description: 'Optional session-scoped test fact.' },
      },
      resolve: exec => exec.agent === undefined ? {} : { NERO_SESSION_OPTIONAL: exec.agent.session.header.id },
    })
    registry.register({
      name: 'always-available-fact',
      variables: {
        NERO_ALWAYS_AVAILABLE: { description: 'Always-available test fact.' },
      },
      resolve: () => ({ NERO_ALWAYS_AVAILABLE: 'yes' }),
    })

    expect(registry.collect(execution())).not.toHaveProperty('NERO_SESSION_OPTIONAL')
    expect(registry.collect(execution()).NERO_ALWAYS_AVAILABLE).toBe('yes')
    expect(registry.collect(execution('session-b')).NERO_SESSION_OPTIONAL).toBe('session-b')
    expect(registry.list()).toEqual([
      {
        contributor: 'always-available-fact',
        description: 'Always-available test fact.',
        key: 'NERO_ALWAYS_AVAILABLE',
      },
      {
        contributor: 'optional-session-fact',
        description: 'Optional session-scoped test fact.',
        key: 'NERO_SESSION_OPTIONAL',
      },
    ])
  })

  it('rejects duplicate variable ownership at registration time', () => {
    const ctx = new Context()
    const registry = new ShellEnvRegistry(ctx, { neroHome: './test-nero-home' })
    registry.register({
      name: 'first',
      variables: { NERO_SHARED: { description: 'First owner.' } },
      resolve: () => ({ NERO_SHARED: 'first' }),
    })

    expect(() => registry.register({
      name: 'second',
      variables: { NERO_SHARED: { description: 'Second owner.' } },
      resolve: () => ({ NERO_SHARED: 'second' }),
    })).toThrow(/NERO_SHARED.*first.*second|NERO_SHARED.*second.*first/)
  })

  it('rejects duplicate contributor names and malformed declarations', () => {
    const registry = new ShellEnvRegistry(new Context(), { neroHome: './test-nero-home' })
    registry.register({
      name: 'declared',
      variables: { NERO_DECLARED: { description: 'Declared fact.' } },
      resolve: () => ({}),
    })

    expect(() => registry.register({
      name: 'declared',
      variables: { NERO_ANOTHER: { description: 'Another fact.' } },
      resolve: () => ({}),
    })).toThrow(/already registered/)
    expect(() => registry.register({
      name: ' ',
      variables: { NERO_BLANK_NAME: { description: 'Blank owner.' } },
      resolve: () => ({}),
    })).toThrow(/name must be non-empty/)
    expect(() => registry.register({
      name: 'invalid-key',
      variables: { nero_invalid: { description: 'Invalid key.' } } as unknown as Record<'NERO_INVALID', { description: string }>,
      resolve: () => ({}),
    })).toThrow(/invalid key/)
    expect(() => registry.register({
      name: 'reserved-key',
      variables: { NERO_HOME: { description: 'Reserved key.' } },
      resolve: () => ({}),
    })).toThrow(/reserved key/)
    expect(() => registry.register({
      name: 'blank-description',
      variables: { NERO_BLANK_DESCRIPTION: { description: ' ' } },
      resolve: () => ({}),
    })).toThrow(/must describe/)
  })

  it('rejects undeclared variables returned by a contributor', () => {
    const ctx = new Context()
    const registry = new ShellEnvRegistry(ctx, { neroHome: './test-nero-home' })
    registry.register({
      name: 'drifted-provider',
      variables: { NERO_DECLARED: { description: 'Declared fact.' } },
      resolve: () => ({ NERO_UNDECLARED: 'bad' }),
    })

    expect(() => registry.collect(execution())).toThrow(/drifted-provider.*NERO_UNDECLARED/)
  })

  it('rejects non-string values returned by a contributor', () => {
    const registry = new ShellEnvRegistry(new Context(), { neroHome: './test-nero-home' })
    registry.register({
      name: 'wrong-value-type',
      variables: { NERO_STRING: { description: 'String fact.' } },
      resolve: () => ({ NERO_STRING: 42 }) as unknown as Record<'NERO_STRING', string>,
    })

    expect(() => registry.collect(execution())).toThrow(/wrong-value-type.*non-string.*NERO_STRING/)
  })

  it('removes an effect-scoped contributor when its plugin is disposed', async () => {
    const ctx = new Context()
    const registry = new ShellEnvRegistry(ctx, { neroHome: './test-nero-home' })
    const fiber = await ctx.plugin({
      inject: ['shellEnv'],
      apply(inner: Context) {
        inner.shellEnv.register({
          name: 'temporary',
          variables: { NERO_TEMPORARY: { description: 'Temporary fact.' } },
          resolve: () => ({ NERO_TEMPORARY: 'present' }),
        })
      },
    })

    expect(registry.collect(execution()).NERO_TEMPORARY).toBe('present')
    await fiber.dispose()
    expect(registry.collect(execution())).not.toHaveProperty('NERO_TEMPORARY')
  })

  it('returns an explicit contributor disposer', () => {
    const registry = new ShellEnvRegistry(new Context(), { neroHome: './test-nero-home' })
    const dispose = registry.register({
      name: 'explicit-disposal',
      variables: { NERO_EXPLICIT_DISPOSAL: { description: 'Explicitly disposed fact.' } },
      resolve: () => ({ NERO_EXPLICIT_DISPOSAL: 'present' }),
    })

    expect(registry.collect(execution()).NERO_EXPLICIT_DISPOSAL).toBe('present')
    dispose()
    expect(registry.collect(execution())).not.toHaveProperty('NERO_EXPLICIT_DISPOSAL')
  })

  it('the plugin registers the service with no contributors on load', async () => {
    const ctx = new Context()
    await ctx.plugin(BashEnvPlugin)
    expect(ctx.shellEnv).toBeInstanceOf(ShellEnvRegistry)
    expect(ctx.shellEnv.list()).toEqual([])
  })
})
