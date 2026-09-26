/** The standalone SDK-minimal bundle's complete declared Cordis tree. */

import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import * as yaml from 'js-yaml'
import { describe, expect, it } from 'vitest'
import { entryListSchema } from '@nero/cordis-plugin-include'

function packageName(specifier: string): string {
  return specifier.startsWith('@') ? specifier.split('/').slice(0, 2).join('/') : specifier.split('/')[0]!
}

describe('nero-sdk-minimal bundle', () => {
  it('declares one standalone allowlisted tree with every row dependency', () => {
    const root = fileURLToPath(new URL('..', import.meta.url))
    const manifest = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8')) as {
      dependencies?: Record<string, string>
      nero?: { bundle?: { patch?: string } }
    }
    expect(manifest.nero?.bundle?.patch).toBe('./cordis.patch.yml')
    const patches = yaml.load(
      readFileSync(resolve(root, manifest.nero!.bundle!.patch!), 'utf8'),
      { schema: entryListSchema },
    ) as Array<{ insert?: Array<{ id?: string; inject?: string[]; name?: string; config?: Record<string, unknown>; disabled?: unknown }> }>
    expect(patches).toHaveLength(1)
    const rows = patches[0]?.insert ?? []
    expect(rows.map(row => [row.id, row.name])).toEqual([
      ['sdk-app-startup', '@nero/nero-sdk-app'],
      ['sdk-jsonrpc-server', '@nero/nero-sdk-jsonrpc-server'],
      ['nero-llm-api-extensions', '@nero/nero-nero-llm-api-extensions'],
      ['session-log-nero', '@nero/nero-session-log-nero'],
      ['plugin-package-inventory-nero', '@nero/nero-plugin-package-inventory-nero'],
      ['sandbox', '@nero/nero-sandbox-local'],
      ['session-projection', '@nero/nero-session-projection'],
      ['sandbox-policy', '@nero/nero-sandbox-policy'],
      ['subprocess', '@nero/nero-subprocess-local'],
      ['pty', '@nero/nero-terminal'],
      ['terminal-bash', '@nero/nero-terminal-bash'],
      ['terminal-pwsh', '@nero/nero-terminal-bash'],
      ['timer', '@nero/cordis-plugin-timer'],
      ['llm', '@nero/nero-llm'],
      ['session', '@nero/nero-session'],
      ['session-title', '@nero/nero-session-title'],
      ['system-prompt', '@nero/nero-system-prompt'],
      ['tools', '@nero/nero-tools'],
      ['mcp-resources', '@nero/nero-mcp-resources'],
      ['agent', '@nero/nero-agent'],
      ['llm-retry', '@nero/nero-llm-retry'],
      ['jobs', '@nero/nero-jobs-local'],
      ['invariants', '@nero/nero-invariants'],
      ['session-invariant', '@nero/nero-session/invariant'],
      ['agent-invariant', '@nero/nero-agent/invariant'],
      ['scope-invariant', '@nero/nero-scope/invariant'],
      ['agent-loop-invariant', '@nero/nero-agent-loop/invariant'],
      ['agent-loop', '@nero/nero-agent-loop'],
      ['persistent-bash', '@nero/nero-tool-bash-persistent'],
      ['persistent-pwsh', '@nero/nero-tool-pwsh-persistent'],
      ['sessions', '@nero/nero-session-persistence-jsonl'],
    ])
    expect(rows.find(row => row.id === 'sdk-app-startup')?.config).toEqual({ profile: 'sdk-minimal' })
    expect(rows.find(row => row.id === 'sdk-jsonrpc-server')).toMatchObject({
      inject: ['sdkAppStartup', 'loader'],
      config: { maxTokensAsSuccess: false },
    })
    expect(rows.find(row => row.id === 'system-prompt')?.config).toEqual({
      includeHarnessIdentity: false,
      includeRuntimeContext: false,
      personaPrefix: { __jsExpr: "process.env.NERO_SYSTEM_PROMPT ?? 'You are a helpful software engineer assistant.'" },
    })
    expect(rows.find(row => row.id === 'agent-loop')?.config).toEqual({ agents: [] })
    expect(rows.find(row => row.id === 'terminal-bash')).toMatchObject({
      disabled: { __jsExpr: "process.platform === 'win32'" },
    })
    expect(rows.find(row => row.id === 'terminal-pwsh')).toMatchObject({
      disabled: { __jsExpr: "process.platform !== 'win32'" },
      config: { shellDialect: 'pwsh', timeoutMs: 300000 },
    })
    expect(Object.keys(manifest.dependencies ?? {}).sort()).toEqual(
      [...new Set(rows.map(row => row.name).filter((name): name is string => name !== undefined).map(packageName))].sort(),
    )
  })
})
