/** Right-Sidebar tab presenting one teammate's live chat, role, and message box. */
import { useEffect, useState } from 'react'
import type { Context } from '@nero/cordis'
import type { ISessions, SessionReference } from '@nero/nero-api-session-controller/client'
import type { ModelSelectionProjection } from '@nero/nero-api-session-controller/types'
import type { RemoteResult } from '@nero/nero-api-remotes/client'
import type { ResourceProvider } from '@nero/nero-client-resources/client'
import type { ConversationViewsProps } from '@nero/nero-client-ui-conversation/client'
import type { SidebarRightTabDefinition } from '@nero/nero-client-ui-sidebar-right/client'
import type {
  PropsRenderFactories, PropsRenderSlots, PropsRuntime, TranslateNS,
} from '@nero/nero-client-ui-slots'
import type { SessionId } from '@nero/nero-session/types'
import type { SubagentAddress } from '@nero/nero-subagent/client'
import type { TeamMemberView, TeamView } from '@nero/nero-experimental-agent-team/client'
import { NS } from './locales.ts'
import css from './AgentChat.module.css'

/** Stable implementation identity for the Sidebar tab body. */
export const AGENT_CHAT_ID = '@nero/nero-experimental-client-ui-agent-team/chat'

/** Resource-address prefix for an embedded teammate chat. */
export const AGENT_CHAT_ADDRESS = 'nero-resource://agentchat/session/'

/** Value retained by one live teammate-chat resource occurrence. */
export interface AgentChatResource {
  readonly address: AgentChatAddress
  readonly reference: SessionReference
}

/** Durable teammate chat identity plus the lead session that owns the Team. */
export type AgentChatAddress = SubagentAddress & {
  /** Durable teammate name, the target of role edits and direct messages. */
  readonly member: string
}

declare module '@nero/nero-api-session-controller/client' {
  interface SessionReferenceSourceMap {
    agentChat: unknown
  }
}

declare module '@nero/nero-client-ui-slots' {
  interface ResourceProtocolMap {
    agentchat: AgentChatResource
  }

  interface SlotMap {
    /** Session-scoped Conversation occurrence hosted by one teammate chat tab. */
    'agent-team.chat': { kind: 'single'; scope: 'session' }
    /** The same occurrence hosted by the Agent Canvas mini window. */
    'agent-team.canvas.chat': { kind: 'single'; scope: 'session' }
    /** The same occurrence projected as the teammate's Trajectory view. */
    'agent-team.canvas.trajectory': { kind: 'single'; scope: 'session' }
  }
}

/**
 * Read the model a Session actually runs from its durable projection. The
 * composer's model CATALOG is refused to addressed subagent sessions, but the
 * selection the Session already carries is local Session state.
 * @param selection - the Session's durable model-selection projection, when read.
 * @returns the model id, or undefined while the Session has not run yet.
 */
export function sessionModel(
  selection: ModelSelectionProjection | undefined,
): string | undefined {
  const chosen = selection?.next ?? selection?.lastUsed
  return chosen === null || chosen === undefined || chosen.model === '' ? undefined : chosen.model
}

/** Props supplied to the teammate model chip in the composer tool row. */
export type TeammateModelProps = PropsRuntime<'conversation.input.right'>

/**
 * Show the model a teammate Session is bound to. Addressed subagent Sessions
 * expose no model seat at all — the Agent-bound catalog RPCs are refused there
 * — so this fills the same row position with the binding the Session already
 * carries instead of leaving the tool row without a model. Ordinary Sessions
 * keep the real selector and render nothing here.
 * @param props - Session-scoped runtime props plus the bound translator.
 * @returns the read-only model chip, or null when the real seat owns the row.
 */
export function TeammateModelChip({
  useSession, useProjection, t,
}: TeammateModelProps & { readonly t: TranslateNS<typeof NS> }) {
  const addressed = useSession(snapshot => snapshot.subagent !== null)
  const model = sessionModel(useProjection('modelSelection'))
  if (!addressed || model === undefined) return null
  return (
    <span className={css.modelChip} data-agent-model="" title={t('modelFixed')} aria-label={t('modelFixed')}>
      {model}
    </span>
  )
}

/**
 * Address one teammate Session together with the routing facts needed to restore it.
 * @param address - teammate chat identity.
 * @returns canonical Sidebar resource address.
 */
export function agentChatAddress(address: AgentChatAddress): string {
  const query = new URLSearchParams({
    parent: address.parentSessionId,
    mode: address.mode,
    member: address.member,
  })
  return `${AGENT_CHAT_ADDRESS}${encodeURIComponent(address.childSessionId)}?${query}`
}

/**
 * Parse one canonical teammate-chat resource address.
 * @param value - possible teammate-chat resource address.
 * @returns the decoded teammate chat identity, or undefined for another or malformed resource.
 */
export function parseAgentChatAddress(value: string): AgentChatAddress | undefined {
  let url: URL
  try {
    url = new URL(value)
  } catch (_invalidUrl) {
    return undefined
  }
  if (url.protocol !== 'nero-resource:' || url.hostname.toLowerCase() !== 'agentchat') return undefined
  const parts = url.pathname.split('/').filter(Boolean)
  if (parts.length !== 2 || parts[0] !== 'session') return undefined
  const parentSessionId = url.searchParams.get('parent')
  const mode = url.searchParams.get('mode')
  const member = url.searchParams.get('member')
  if (parentSessionId === null || parentSessionId === '' || member === null || member === ''
    || (mode !== 'one-shot' && mode !== 'continuable' && mode !== 'unknown')) {
    return undefined
  }
  try {
    const childSessionId = decodeURIComponent(parts[1] as string)
    return {
      parentSessionId: parentSessionId as SessionId,
      childSessionId: childSessionId as SessionId,
      mode,
      member,
    }
  } catch (_invalidEncoding) {
    return undefined
  }
}

function waitForAbort(signal: AbortSignal): Promise<void> {
  if (signal.aborted) return Promise.resolve()
  return new Promise((resolve) => {
    signal.addEventListener('abort', () => { resolve() }, { once: true })
  })
}

function agentChatResourceProvider(sessions: ISessions): ResourceProvider<'agentchat'> {
  return {
    protocol: 'agentchat',
    async *open(resourceAddress, { signal }) {
      const address = parseAgentChatAddress(resourceAddress)
      if (address === undefined) throw new Error(`client-ui-agent-team: invalid chat resource address "${resourceAddress}"`)
      if (signal.aborted) return
      const reference = sessions.retain({
        parentSessionId: address.parentSessionId,
        childSessionId: address.childSessionId,
        mode: address.mode,
      }, { source: 'agentChat', signal })
      try {
        yield { ok: true, value: { address, reference } }
        await waitForAbort(signal)
      } finally {
        reference.release()
      }
    },
  }
}

/** One fixed view selection used by an embedded Conversation occurrence. */
function fixedView(view: string) {
  return function FixedConversationView(props: ConversationViewsProps) {
    return <>{props.renderSlot('conversation.session', { view })}</>
  }
}

/** Fixed Chat selection used by an embedded Conversation occurrence. */
export const FixedChatConversationView = fixedView('chat')
const FixedTrajectoryConversationView = fixedView('trajectory')

/** Props supplied to the teammate Conversation host. */
export type AgentChatConversationProps = PropsRuntime<'agent-team.chat'> & PropsRenderFactories

/** Render the shared Conversation content for one explicitly provided teammate Session. */
function sharedConversation(
  views: typeof FixedChatConversationView,
) {
  return function AgentConversation({
    sessionId, useSession, useConversation, useSessions, renderFactorySlot,
  }: AgentChatConversationProps) {
    const session = useSession(value => value)
    const conversation = useConversation(value => value)
    const active = conversation.activeTargets.size > 0
    || (!session.blank && !session.awaitingFirstTurn)
    || session.running
    const shellPhase = active ? 'active' : session.promptAttempted ? 'engaging' : 'blank'
    const summaryBlank = useSessions(state => state.byId[sessionId]?.blank)
    const parentAvailabilityPending = session.subagent?.address.mode === 'continuable'
    && session.subagent.parentAvailable === undefined
    const settling = (shellPhase === 'blank' && session.openState === 'loading' && summaryBlank !== true)
    || parentAvailabilityPending
    const hero = shellPhase === 'blank' && (session.openState === 'open' || summaryBlank === true)
    const phase = settling ? 'settling' : hero ? 'hero' : 'active'
    return renderFactorySlot('conversation.content', { variant: 'embedded', phase, hero }, {
      slots: { views },
    })
  }
}

/** Render the shared Conversation content for one explicitly provided teammate Session. */
export const AgentChatConversation = sharedConversation(FixedChatConversationView)

/** Render the same teammate Session as its Trajectory view. */
export const AgentTrajectoryConversation = sharedConversation(FixedTrajectoryConversationView)

/** Workbench actions a teammate chat tab performs for the user. */
export interface AgentChatActions {
  /** Read the current Team view through the generated Remote API. */
  load: (sessionId: SessionId) => Promise<RemoteResult<TeamView>>
  /** Persist one teammate job-role edit. */
  updateRole: (sessionId: SessionId, request: { target: string; jobRole: string }) => Promise<RemoteResult<TeamMemberView>>
  /** Queue one durable direct message to the teammate. */
  send: (sessionId: SessionId, request: { target: string; text: string }) => Promise<RemoteResult<{ status: 'accepted' | 'queued' }>>
}

/** Props supplied to the parent-Session Sidebar tab body. */
export type AgentChatTabProps =
  PropsRuntime<'sidebar.right.pane.tab'>
  & PropsRenderSlots<'agent-team.chat'>

/** Mini-chat control assigning one teammate's job role. */
export function RoleEditor({ member, actions, parentSessionId, t }: {
  readonly member: TeamMemberView
  readonly actions: AgentChatActions
  readonly parentSessionId: SessionId
  readonly t: TranslateNS<typeof NS>
}) {
  const [role, setRole] = useState(member.jobRole ?? '')
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  useEffect(() => { setRole(member.jobRole ?? '') }, [member.id, member.jobRole])
  const dirty = role.trim() !== (member.jobRole ?? '')
  return (
    <form
      className={css.panel}
      data-agent-role=""
      onSubmit={(event) => {
        event.preventDefault()
        if (busy || !dirty || role.trim() === '') return
        setBusy(true)
        void actions.updateRole(parentSessionId, { target: member.name, jobRole: role.trim() })
          .then((result) => { setNotice(result.ok ? t('roleSaved') : `${result.error.message} (${result.error.code})`) })
          .finally(() => { setBusy(false) })
      }}
    >
      <label className={css.label} htmlFor="agent-team-role">{t('roleLabel')}</label>
      <input
        id="agent-team-role"
        className={css.input}
        value={role}
        placeholder={t('rolePlaceholder')}
        maxLength={200}
        onChange={(event) => { setRole(event.target.value); setNotice(null) }}
      />
      <button type="submit" className={css.button} disabled={busy || !dirty || role.trim() === ''}>
        {busy ? t('roleSaving') : t('roleSave')}
      </button>
      {notice !== null && <span className={css.notice} role="status">{notice}</span>}
    </form>
  )
}

/** Mini-chat control queueing one durable message to a member. */
export function DirectMessage({ member, actions, parentSessionId, t }: {
  readonly member: TeamMemberView
  readonly actions: AgentChatActions
  readonly parentSessionId: SessionId
  readonly t: TranslateNS<typeof NS>
}) {
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  return (
    <form
      className={css.panel}
      data-agent-message=""
      onSubmit={(event) => {
        event.preventDefault()
        const body = text.trim()
        if (busy || body === '') return
        setBusy(true)
        void actions.send(parentSessionId, { target: member.name, text: body })
          .then((result) => {
            if (!result.ok) { setNotice(`${result.error.message} (${result.error.code})`); return }
            setText('')
            setNotice(result.value.status === 'accepted' ? t('dmAccepted') : t('dmQueued'))
          })
          .finally(() => { setBusy(false) })
      }}
    >
      <label className={css.label} htmlFor="agent-team-message">{t('dmLabel')}</label>
      <textarea
        id="agent-team-message"
        className={css.textarea}
        value={text}
        placeholder={t('dmPlaceholder')}
        rows={2}
        onChange={(event) => { setText(event.target.value); setNotice(null) }}
      />
      <button type="submit" className={css.button} disabled={busy || text.trim() === ''}>
        {busy ? t('dmSending') : t('dmSend')}
      </button>
      {notice !== null && <span className={css.notice} role="status">{notice}</span>}
    </form>
  )
}

/** Bind a teammate chat resource's child reference around its Conversation slot. */
export function AgentChatTab({
  useResource, useTabInfo, SessionProvider, renderSlot, actions, t,
}: AgentChatTabProps & { readonly actions: AgentChatActions; readonly t: TranslateNS<typeof NS> }) {
  const { tab } = useTabInfo()
  const resource = useResource<'agentchat'>(tab.contentId)
  const address = parseAgentChatAddress(tab.contentId)
  const [member, setMember] = useState<TeamMemberView | null>(null)
  const parentSessionId = address?.parentSessionId
  useEffect(() => {
    if (parentSessionId === undefined || address === undefined) return
    let alive = true
    void actions.load(parentSessionId).then((result) => {
      if (!alive || !result.ok) return
      setMember(result.value.members.find(candidate => candidate.name === address.member) ?? null)
    })
    return () => { alive = false }
  }, [actions, parentSessionId, address?.member])
  return (
    <div className={css.root} data-agent-chat="">
      {member !== null && parentSessionId !== undefined && (
        <div className={css.header}>
          <RoleEditor member={member} actions={actions} parentSessionId={parentSessionId} t={t} />
          <DirectMessage member={member} actions={actions} parentSessionId={parentSessionId} t={t} />
        </div>
      )}
      {resource.value === undefined
        ? null
        : (
          <SessionProvider session={resource.value.reference}>
            {renderSlot('agent-team.chat', {})}
          </SessionProvider>
        )}
    </div>
  )
}

/**
 * Register the teammate-chat resource owner, its right-Sidebar type, and its body.
 * @param ctx - Client root carrying Sessions, resources, Slots, Sidebar registries, and Remote.
 * @param t - Agent Teams namespace translator used for tab titles and control copy.
 * @param actions - Remote-backed workbench actions the tab performs.
 */
export function registerAgentChat(
  ctx: Context,
  t: TranslateNS<typeof NS>,
  actions: AgentChatActions,
): void {
  ctx.effect(
    () => ctx.resources.register(agentChatResourceProvider(ctx.sessions)),
    'client-ui-agent-team: teammate chat resources',
  )
  ctx.effect(() => ctx.sidebarRightTabs.register({
    id: AGENT_CHAT_ID,
    kind: 'agentchat',
    patterns: [`${AGENT_CHAT_ADDRESS}**`],
    priority: 'builtin',
    canOpen: address => parseAgentChatAddress(address) !== undefined,
    title: (address) => {
      const parsed = parseAgentChatAddress(address)
      if (parsed === undefined) return t('tabTitle')
      const label = ctx.sessions.list.getSnapshot().byId[parsed.childSessionId]?.projectionValues?.subagent?.label
      return label ?? parsed.member
    },
  } satisfies SidebarRightTabDefinition), 'client-ui-agent-team: teammate chat type')
  // The tab body is bound to this plugin's own actions and translator rather
  // than an inject face: the pane seat's declared inject carries only the
  // framework's live tab information.
  const TabBody = (props: AgentChatTabProps) => <AgentChatTab {...props} actions={actions} t={t} />
  ctx.effect(() => ctx.slots.inject('sidebar.right.pane.tab', () => ctx.slots.register({
    name: 'sidebar.right.pane.tab',
    key: AGENT_CHAT_ID,
    children: { 'agent-team.chat': { kind: 'single', scope: 'session' } },
  }, TabBody)), 'client-ui-agent-team: teammate chat body')
  ctx.effect(() => ctx.slots.inject('agent-team.chat', () => ctx.slots.register({
    name: 'agent-team.chat',
  }, AgentChatConversation)), 'client-ui-agent-team: teammate conversation')
  // The composer's model seat renders nothing for a teammate, so the tool row
  // carries the teammate's bound model here, immediately before that seat.
  const ModelChip = (props: TeammateModelProps) => <TeammateModelChip {...props} t={t} />
  ctx.effect(() => ctx.slots.inject('conversation.input.right', () => ctx.slots.register({
    name: 'conversation.input.right',
    id: 'agent-team-model',
    order: 0,
    locale: NS,
  }, ModelChip)), 'client-ui-agent-team: teammate model chip')
}
