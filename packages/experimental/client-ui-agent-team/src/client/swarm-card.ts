/** The Team roster folded into one Chat Node that opens the Agent Canvas. */

import type {
  ConversationLocation, ConversationNodeContext, ConversationNodeDefinition,
} from '@nero/nero-client-ui-conversation/client'
import type { ChatConversationViewNode } from '@nero/nero-client-ui-chat/client'
import type { SessionId } from '@nero/nero-session/types'
import type { TeamMemberSnapshot } from '@nero/nero-experimental-agent-team/client'

/** Renderer status for one teammate node. */
export type AgentSwarmStatus = 'provisioning' | 'active' | 'failed'

/** Final renderer payload for one teammate node. */
export interface AgentSwarmMember {
  /** Child Session identity, used to open the teammate's Sidebar tab. */
  readonly id: SessionId
  readonly name: string
  readonly status: AgentSwarmStatus
  readonly description: string
  readonly jobRole?: string
}

/** Final renderer payload for the Team's single Chat row. */
export interface AgentSwarmChatData {
  readonly members: readonly AgentSwarmMember[]
}

declare module '@nero/nero-client-ui-chat/client' {
  interface ChatNodeDataMap {
    /** The Team's one durable roster row. */
    'agent-swarm': AgentSwarmChatData
  }
}

/** Folded state of the Team's durable member records. */
interface AgentSwarmState {
  readonly members: readonly TeamMemberSnapshot[]
}

/** The one node key every `team/member` record folds into. */
const TEAM_NODE_ID = 'agent-team'

function locationOf(context: ConversationNodeContext): ConversationLocation {
  return context.start?.location ?? context.matches[0]?.location ?? { kind: 'unresolved' }
}

function viewData(member: TeamMemberSnapshot): AgentSwarmMember {
  const row: AgentSwarmMember = {
    id: member.id,
    name: member.name,
    status: member.phase,
    description: member.description,
  }
  // `exactOptionalPropertyTypes` forbids assigning an explicit undefined.
  if (member.jobRole === undefined || member.jobRole === '') return row
  return { ...row, jobRole: member.jobRole }
}

/**
 * Fold every durable `team/member` event into ONE Chat row for the whole Team.
 *
 * A teammate's first durable record is its provisioning snapshot, emitted
 * exactly once, so it is the unique start; the settled `active` snapshot and
 * any later job-role edit re-emit the same topic as updates. Every member folds
 * into the same node, so the transcript shows one Agent Teams box that opens the
 * Agent Canvas rather than one row per teammate.
 */
export const agentSwarmDefinition: ConversationNodeDefinition<AgentSwarmState> = {
  kind: 'agent-swarm',
  target: 'chat',
  match: (event) => {
    if (event.type !== 'team/member') return null
    return {
      id: TEAM_NODE_ID,
      role: event.data.member.phase === 'provisioning' ? 'start' : 'update',
    }
  },
  start: (_context, match) => {
    if (match.event.type !== 'team/member') throw new Error('agent-swarm start requires team/member')
    return { members: [match.event.data.member] }
  },
  update: (context, match) => {
    if (match.event.type !== 'team/member') return context.state
    const settled = match.event.data.member
    const known = context.state?.members ?? []
    const members = known.some(member => member.id === settled.id)
      ? known.map(member => (member.id === settled.id ? settled : member))
      : [...known, settled]
    return { members }
  },
  buildViewNode: (context): ChatConversationViewNode | null => {
    if (context.state === undefined) return null
    return {
      key: context.key,
      kind: 'agent-swarm',
      id: context.id,
      target: 'chat',
      anchorSeq: context.start?.event.seq ?? 0,
      location: locationOf(context),
      visibility: 'visible',
      data: { members: context.state.members.map(viewData) },
    }
  },
}
