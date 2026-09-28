// @vitest-environment jsdom

import { afterEach, describe, expect, it } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import type { SessionSnapshot } from '@nero/nero-api-session-controller/client'
import type { ModelSelectionProjection } from '@nero/nero-api-session-controller/types'
import type { SessionId } from '@nero/nero-session/types'
import type { SubagentAddress } from '@nero/nero-subagent/client'
import { makeTranslate } from '@nero/nero-client-test-runtime'
import { zh as commonZh } from '@nero/nero-client-locale/src/locales/zh.ts'
import { sessionModel, TeammateModelChip } from '../src/client/agent-chat.tsx'
import { zh } from '../src/client/locales.ts'

afterEach(cleanup)

const CHILD = 'child-session' as SessionId
const MAIN = 'main-session' as SessionId
const ADDRESS: SubagentAddress = {
  parentSessionId: MAIN, childSessionId: CHILD, mode: 'continuable',
}

function selection(lastUsed: ModelSelectionProjection['lastUsed'], next: ModelSelectionProjection['next']): ModelSelectionProjection {
  return { lastUsed, next }
}

/**
 * Mount the chip with the two standard-kit reads it makes: the Session's own
 * snapshot (is this an addressed child?) and one projection key.
 */
function chip(address: SubagentAddress | null, projection: ModelSelectionProjection | undefined) {
  const props = {
    sessionId: address?.childSessionId ?? MAIN,
    useSession: (select: (snapshot: SessionSnapshot) => unknown) => select({ subagent: address } as unknown as SessionSnapshot),
    useProjection: (key: string) => (key === 'modelSelection' ? projection : undefined),
    t: makeTranslate(zh, commonZh),
  } as unknown as Parameters<typeof TeammateModelChip>[0]
  return <TeammateModelChip {...props} />
}

describe('sessionModel', () => {
  it('prefers the selection the next request uses, then the last used one', () => {
    expect(sessionModel(selection({ provider: 'p', model: 'last' }, null))).toBe('last')
    expect(sessionModel(selection({ provider: 'p', model: 'last' }, { provider: 'p', model: 'next' }))).toBe('next')
  })

  it('reports nothing for a Session with no model yet', () => {
    expect(sessionModel(undefined)).toBeUndefined()
    expect(sessionModel(selection(null, null))).toBeUndefined()
    expect(sessionModel(selection({ provider: 'p', model: '' }, null))).toBeUndefined()
  })
})

describe('TeammateModelChip', () => {
  it('shows the model an addressed teammate Session is bound to', () => {
    render(chip(ADDRESS, selection(null, { provider: 'p', model: 'model-x' })))
    expect(screen.getByText('model-x')).toBeDefined()
  })

  it('stays out of the tool row where the real selector renders', () => {
    const { container } = render(chip(null, selection({ provider: 'p', model: 'model-x' }, null)))
    expect(container.innerHTML).toBe('')
  })

  it('renders nothing before a teammate has a model projection', () => {
    const { container } = render(chip(ADDRESS, undefined))
    expect(container.innerHTML).toBe('')
  })
})
