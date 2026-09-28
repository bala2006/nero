/** Browser entry binding the generated Team Remote artifact to its Client UI. */

import agentTeamsRemote from '@nero/nero-experimental-agent-team/remote'
import type { Context as ClientContext } from '@nero/cordis'
import { mountAgentTeamUi } from './mount.ts'

export { inject } from './mount.ts'
export type { TeamPanelInjected, TeamPanelProps, TeamPanelResult } from './TeamPanel.tsx'
export type { AgentSwarmCardInjected, AgentSwarmCardProps } from './SwarmCard.tsx'
export type { AgentSwarmChatData, AgentSwarmMember, AgentSwarmStatus } from './swarm-card.ts'
export { TEAM_PANEL_ID, TEAM_PANEL_KIND } from './team-panel.ts'
export type { TeamKey } from './locales.ts'

/** Mount the generated Team Remote contribution and its browser UI. */
export async function apply(ctx: ClientContext): Promise<() => Promise<void>> {
  return await mountAgentTeamUi(ctx, agentTeamsRemote)
}
