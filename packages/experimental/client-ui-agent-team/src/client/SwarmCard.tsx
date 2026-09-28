import { StateDot } from '@nero/nero-client-ui-primitives'
import type { PropsLocale, PropsRuntime } from '@nero/nero-client-ui-slots'
import type {} from '@nero/nero-client-ui-chat/client'
import { NS } from './locales.ts'
import css from './SwarmCard.module.css'

/** Business action injected by the browser plugin. */
export interface AgentSwarmCardInjected {
  /** Open the Agent Canvas tab in the right Sidebar. */
  openTeamCanvas: () => void
}

/** Complete keyed Chat renderer props of the Agent Teams box. */
export type AgentSwarmCardProps =
  PropsRuntime<'conversation.chat.node', 'agent-swarm'>
  & PropsLocale<typeof NS>
  & AgentSwarmCardInjected

/** Render the Team's one rounded box: a summary of the roster that opens the canvas. */
export function AgentSwarmCard({ node, openTeamCanvas, t }: AgentSwarmCardProps) {
  const { members } = node.data
  const running = members.filter(member => member.status === 'active').length
  return (
    <section className={css.row} data-agent-swarm="" data-agent-count={members.length}>
      <button type="button" className={css.box} title={t('openCanvas')} onClick={() => { openTeamCanvas() }}>
        <span className={css.head}>
          <span className={css.title}>{t('swarmTitle')}</span>
          <span className={css.count}>{members.length}</span>
          {running > 0 && <StateDot state="ongoing" />}
        </span>
        <span className={css.names}>{members.map(member => member.name).join(' · ')}</span>
        <span className={css.hint}>{t('openCanvas')}</span>
      </button>
    </section>
  )
}
