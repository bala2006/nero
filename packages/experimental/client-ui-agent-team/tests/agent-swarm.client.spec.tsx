// @vitest-environment jsdom

import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render } from '@testing-library/react'
import type { SessionId } from '@nero/nero-session/types'
import type {
  ConversationLocation, ConversationNodeContext, ConversationStartMatch,
} from '@nero/nero-client-ui-conversation/client'
import type { TeamMemberSnapshot } from '@nero/nero-experimental-agent-team/client'
import { makeTranslate } from '@nero/nero-client-test-runtime'
import { zh as commonZh } from '@nero/nero-client-locale/src/locales/zh.ts'
import {
  AGENT_CHAT_ADDRESS, agentChatAddress, parseAgentChatAddress,
} from '../src/client/agent-chat.tsx'
import { agentSwarmDefinition, type AgentSwarmChatData } from '../src/client/swarm-card.ts'
import { AgentSwarmCard, type AgentSwarmCardProps } from '../src/client/SwarmCard.tsx'
import { zh } from '../src/client/locales.ts'

afterEach(cleanup)

const LEAD = 'lead' as SessionId
const CHILD = 'child-a' as SessionId
const ADDRESS = {
  parentSessionId: LEAD,
  childSessionId: CHILD,
  mode: 'continuable' as const,
  member: 'worker-a',
}

function member(overrides: Partial<TeamMemberSnapshot> = {}): TeamMemberSnapshot {
  return {
    id: CHILD,
    name: 'worker-a',
    description: 'Implement the runtime',
    provider: 'spawn',
    context: 'fresh',
    phase: 'provisioning',
    ...overrides,
  }
}

function memberEvent(snapshot: TeamMemberSnapshot, seq: number) {
  return {
    type: 'team/member',
    seq,
    time: seq,
    data: { version: 2, teamId: LEAD as never, member: snapshot },
  } as never
}

const UNRESOLVED: ConversationLocation = { kind: 'unresolved' }

function startMatch(event: never): ConversationStartMatch {
  return { event, role: 'start', location: UNRESOLVED } as unknown as ConversationStartMatch
}

function updateMatch(event: never) {
  return { event, role: 'update', location: UNRESOLVED } as never
}

/** The folded definition state, structurally matching the plugin-private one. */
type SwarmState = { readonly members: readonly TeamMemberSnapshot[] }

function context<S>(
  matches: readonly unknown[],
  start: ConversationStartMatch | undefined,
  state: S,
): ConversationNodeContext<S> & { readonly state: S } {
  return {
    key: 'agent-swarm:agent-team',
    kind: 'agent-swarm',
    id: 'agent-team',
    matches,
    start,
    state,
    current: new Map(),
  } as unknown as ConversationNodeContext<S> & { readonly state: S }
}

const reader = { previous: () => undefined }

describe('teammate chat address', () => {
  it('round-trips a teammate chat resource address', () => {
    expect(parseAgentChatAddress(agentChatAddress(ADDRESS))).toEqual(ADDRESS)
    expect(agentChatAddress(ADDRESS)).toContain(AGENT_CHAT_ADDRESS)
  })

  it.each([
    'not an address',
    'https://agentchat/session/child?parent=lead&mode=continuable&member=worker',
    'nero-resource://other/session/child?parent=lead&mode=continuable&member=worker',
    'nero-resource://agentchat/other/child?parent=lead&mode=continuable&member=worker',
    'nero-resource://agentchat/session/child?mode=continuable&member=worker',
    'nero-resource://agentchat/session/child?parent=lead&mode=invalid&member=worker',
    'nero-resource://agentchat/session/child?parent=lead&mode=continuable',
  ])('rejects %s', (address) => {
    expect(parseAgentChatAddress(address)).toBeUndefined()
  })
})

describe('Agent Swarm card definition', () => {
  it('folds every teammate into one Agent Teams row', () => {
    const provisioning = memberEvent(member(), 0)
    const active = memberEvent(member({ phase: 'active', jobRole: 'QA tester' }), 1)
    const second = memberEvent(
      { ...member({ phase: 'active' }), id: 'child-b' as SessionId, name: 'worker-b' },
      2,
    )

    expect(agentSwarmDefinition.match(provisioning)).toEqual({ id: 'agent-team', role: 'start' })
    expect(agentSwarmDefinition.match(active)).toEqual({ id: 'agent-team', role: 'update' })

    const start = startMatch(provisioning)
    const settle = updateMatch(active)
    let state = agentSwarmDefinition.start(context<SwarmState>([start], start, undefined as never), start, reader)
    state = agentSwarmDefinition.update(context<SwarmState>([start, settle], start, state), settle)
    const added = updateMatch(second)
    state = agentSwarmDefinition.update(context<SwarmState>([start, settle, added], start, state), added)
    // `buildViewNode` is only ever reached with a settled state.
    const node = agentSwarmDefinition.buildViewNode!(context<SwarmState>([start], start, state as SwarmState))
    expect(node).toMatchObject({
      kind: 'agent-swarm',
      id: 'agent-team',
      target: 'chat',
      anchorSeq: 0,
      visibility: 'visible',
      data: {
        members: [
          {
            id: CHILD,
            name: 'worker-a',
            status: 'active',
            description: 'Implement the runtime',
            jobRole: 'QA tester',
          },
          { id: 'child-b', name: 'worker-b', status: 'active' },
        ],
      },
    })
  })

  it('publishes no node before its unique start', () => {
    expect(agentSwarmDefinition.buildViewNode!(context<SwarmState>([], undefined, undefined as never))).toBeNull()
    expect(agentSwarmDefinition.match({ type: 'team/task' } as never)).toBeNull()
  })
})

describe('AgentSwarmCard', () => {
  const data: AgentSwarmChatData = {
    members: [
      { id: CHILD, name: 'worker-a', status: 'active', description: 'Implement the runtime' },
      { id: 'child-b' as SessionId, name: 'worker-b', status: 'provisioning', description: 'Review it' },
    ],
  }

  function props(openTeamCanvas: AgentSwarmCardProps['openTeamCanvas']): AgentSwarmCardProps {
    return {
      node: { data },
      sessionId: LEAD,
      openTeamCanvas,
      t: makeTranslate(zh, commonZh),
    } as unknown as AgentSwarmCardProps
  }

  it('renders one Agent Teams box that opens the canvas', () => {
    const openTeamCanvas = vi.fn()
    const view = render(<AgentSwarmCard {...props(openTeamCanvas)} />)
    expect(view.getByText(zh.swarmTitle)).toBeTruthy()
    expect(view.getByText('worker-a · worker-b')).toBeTruthy()
    expect(view.getByText(zh.openCanvas)).toBeTruthy()
    expect(view.container.querySelectorAll('[data-agent-swarm]').length).toBe(1)

    fireEvent.click(view.getByRole('button'))
    expect(openTeamCanvas).toHaveBeenCalledExactlyOnceWith()
  })
})
