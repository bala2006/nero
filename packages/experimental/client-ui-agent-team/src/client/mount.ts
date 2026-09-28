/** Source-safe Agent Teams browser registration and Remote mount lifecycle. */

import type {
  TeamMemberView as TeamRosterMember,
  TeamView,
} from '@nero/nero-experimental-agent-team/client'
import type {} from '@nero/nero-experimental-agent-team/remote'
import type { Context as ClientContext } from '@nero/cordis'
import type {} from '@nero/nero-api-remotes/client'
import type {} from '@nero/nero-api-session-controller/client'
import type { SessionId } from '@nero/nero-session/types'
import type {} from '@nero/nero-client-ui-conversation/client'
import type {} from '@nero/nero-client-locale/client'
import type {} from '@nero/nero-client-resources/client'
import type {} from '@nero/nero-client-ui-chat/client'
import type {} from '@nero/nero-client-ui-renderer/client'
import type {} from '@nero/nero-client-ui-sidebar-right/client'
import type {} from '@nero/nero-client-ui-workspace/client'
import type { TypertRemoteContribution } from '@nero/nero-typert-protocol'
import {
  TeamPanel, type TeamPanelInjected, type TeamPanelResult,
} from './TeamPanel.tsx'
import { TEAM_PANEL_ID, TEAM_PANEL_KIND, teamPanelDefinition } from './team-panel.ts'
import { AgentSwarmCard, type AgentSwarmCardInjected } from './SwarmCard.tsx'
import { agentSwarmDefinition } from './swarm-card.ts'
import {
  agentChatAddress, registerAgentChat, AgentChatConversation, AgentTrajectoryConversation,
  type AgentChatActions,
} from './agent-chat.tsx'
import { en, NS, zh, type TeamKey } from './locales.ts'

declare module '@nero/nero-client-ui-slots' {
  interface LocaleNamespaceMap {
    /** Agent Teams roster, task-board, and Agent Swarm copy. */
    'agent-team': TeamKey
  }
}

/** Required browser services for RPC, navigation, slots, Sidebar tabs, and localized copy. */
export const inject = [
  'sessions', 'uiWorkspace', 'uiConversation', 'remote', 'slots', 'locale',
  'resources', 'sidebarRight', 'sidebarRightTabs',
]

function registerUi(ctx: ClientContext): void {
  ctx.effect(() => ctx.locale.register(NS, { zh, en }), 'client-ui-agent-team: dictionaries')
  const sessions = ctx.sessions
  const t = ctx.locale.bind(NS)
  const leadSessionId = (sessionId: SessionId): SessionId => {
    const address = sessions.binding(sessionId)?.session.getSnapshot().subagent?.address
    return address?.parentSessionId ?? sessionId
  }
  const load = async (sessionId: SessionId): Promise<TeamPanelResult<TeamView>> =>
    await ctx.remote.agentTeams.view(leadSessionId(sessionId))

  const openAside = (sessionId: SessionId, member: TeamRosterMember): void => {
    if (member.role !== 'teammate') return
    // A background or retained Conversation must not navigate the foreground
    // Sidebar; only the conversation the user is actually viewing may open one.
    if ((sessions.retainInfo(sessionId).getSnapshot().retainedBy.mainView ?? 0) === 0) return
    ctx.sidebarRight.openResource(agentChatAddress({
      parentSessionId: leadSessionId(sessionId),
      childSessionId: member.id,
      mode: 'continuable',
      member: member.name,
    }), { kind: 'agentchat', preferNewPane: true })
  }

  const chatActions: AgentChatActions = {
    load,
    async updateRole(sessionId: SessionId, request: { target: string; jobRole: string }) {
      return await ctx.remote.agentTeams.updateMemberRole(leadSessionId(sessionId), request)
    },
    async send(sessionId: SessionId, request: { target: string; text: string }) {
      return await ctx.remote.agentTeams.send(leadSessionId(sessionId), {
        target: request.target,
        content: [{ type: 'text', text: request.text }],
      })
    },
  }

  const panelActions: TeamPanelInjected = {
    ...chatActions,
    openTeammate(sessionId: SessionId, member: TeamRosterMember): void {
      if (member.role !== 'teammate') return
      openAside(sessionId, member)
    },
    retainChild(sessionId: SessionId, memberId: SessionId, signal: AbortSignal) {
      return sessions.retain({
        parentSessionId: leadSessionId(sessionId),
        childSessionId: memberId,
        mode: 'continuable',
      }, { source: 'agentChat', signal })
    },
    refreshProjections(memberId: SessionId): void {
      // A projection read, never a history open: the canvas shows what the
      // teammate Session already published without retaining it.
      void sessions.refreshProjections(memberId)
    },
  }

  const cardActions: AgentSwarmCardInjected = {
    // The transcript shows one Agent Teams box; the canvas it opens is the
    // page tab below, so the cards never navigate the Sidebar themselves.
    openTeamCanvas(): void {
      ctx.sidebarRight.openTab(TEAM_PANEL_KIND)
    },
  }

  // The Agent Canvas is a right-Sidebar page tab rather than a conversation
  // header action: the Sidebar is where the teammate chat it opens already
  // lives, and the guide page is what makes the type reachable.
  ctx.effect(() => ctx.sidebarRightTabs.register(teamPanelDefinition(t)), 'client-ui-agent-team: roster tab type')
  ctx.slots.inject('sidebar.right.pane.tab', () => ctx.slots.register({
    name: 'sidebar.right.pane.tab',
    key: TEAM_PANEL_ID,
    locale: NS,
    children: {
      'agent-team.canvas.chat': { kind: 'single', scope: 'session' },
      'agent-team.canvas.trajectory': { kind: 'single', scope: 'session' },
    },
    inject: (): TeamPanelInjected => panelActions,
  }, TeamPanel))
  ctx.effect(() => ctx.slots.inject('agent-team.canvas.chat', () => ctx.slots.register({
    name: 'agent-team.canvas.chat',
  }, AgentChatConversation)), 'client-ui-agent-team: canvas teammate chat')
  ctx.effect(() => ctx.slots.inject('agent-team.canvas.trajectory', () => ctx.slots.register({
    name: 'agent-team.canvas.trajectory',
  }, AgentTrajectoryConversation)), 'client-ui-agent-team: canvas teammate trajectory')
  ctx.uiConversation.events.register(agentSwarmDefinition)
  // The Agent Teams box in the transcript opens that tab; the chat node
  // renderer dispatches this face.
  ctx.slots.inject('conversation.chat.node', () => ctx.slots.register({
    name: 'conversation.chat.node',
    key: 'agent-swarm',
    locale: NS,
    inject: (): AgentSwarmCardInjected => cardActions,
  }, AgentSwarmCard))

  registerAgentChat(ctx, t, chatActions)
}

/**
 * Mount one generated Team Remote contribution, then register its browser UI.
 * @param ctx - Client Context carrying navigation, locale, slot, Sidebar, and Remote services.
 * @param contribution - generated Team descriptors selected by the browser entry.
 * @returns disposer for both the UI registrations and Remote namespace.
 */
export async function mountAgentTeamUi(
  ctx: ClientContext,
  contribution: TypertRemoteContribution,
): Promise<() => Promise<void>> {
  const disposeRemote = await ctx.remote.$mount(contribution)
  const ui = ctx.inject(
    ['sessions', 'uiWorkspace', 'uiConversation', 'remote.agentTeams', 'slots', 'locale', 'resources', 'sidebarRight', 'sidebarRightTabs'],
    registerUi,
  )
  try {
    await ui
  } catch (error) {
    await ui.dispose()
    await disposeRemote()
    throw error
  }
  return async () => {
    await ui.dispose()
    await disposeRemote()
  }
}
