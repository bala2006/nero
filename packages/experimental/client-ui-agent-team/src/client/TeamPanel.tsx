/** Right-Sidebar Agent Canvas: the Team as nodes, links, and one tabbed mini window per node. */
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import type { SessionReference } from '@nero/nero-api-session-controller/client'
import type { SessionId } from '@nero/nero-session/types'
import type {
  TeamMemberView as TeamRosterMember,
  TeamView,
} from '@nero/nero-experimental-agent-team/client'
import type { RemoteResult } from '@nero/nero-api-remotes/client'
import {
  IconAgentPresetOutlineRegular, IconBrowseOutlineRegular, IconCheckOutlineRegular,
  IconChecklistOutlineRegular, IconCloseOutlineRegular, IconCodeOutlineRegular,
  IconCopyOutlineRegular, IconDatabaseOutlineRegular, IconDeliverDocRegular,
  IconEllipsisOutlineRegular, IconGaugeOutlineRegular, IconGoalOutlineRegular,
  IconInspectOutlineRegular, IconLightOutlineRegular, IconPlanOutlineRegular, IconPlusOutlineRegular,
  IconRefreshOutlineRegular, IconSettingsOutlineRegular, IconShieldOutlineRegular,
  IconSparkleRegular, IconTrashOutlineRegular, IconUserOutlineRegular,
  Menu, MenuItemButton, StateDot, type StateDotState,
} from '@nero/nero-client-ui-primitives'
import type {
  PropsLocale, PropsRenderSlots, PropsRuntime, TranslateNS,
} from '@nero/nero-client-ui-slots'
import type {} from '@nero/nero-client-ui-sidebar-right/client'
import type { AgentChatActions } from './agent-chat.tsx'
import { nodeMetrics, type NodeMetric, type NodeMetrics } from './node-metrics.ts'
import { isPresetPrompt, ROLE_OPTIONS, rolePrompt } from './role-presets.ts'
import { NS, type TeamKey } from './locales.ts'
import css from './TeamPanel.module.css'

/** Generated Remote result consumed directly by the Team UI. */
export type TeamPanelResult<T> = RemoteResult<T>

/** One editable step of a member's local to-do list. */
export interface CanvasStep {
  readonly id: string
  readonly text: string
  readonly done: boolean
}

/** Business actions injected by the browser plugin. */
export interface TeamPanelInjected extends AgentChatActions {
  load: (sessionId: SessionId) => Promise<TeamPanelResult<TeamView>>
  openTeammate: (sessionId: SessionId, member: TeamRosterMember) => void
  /** Retain the member's child Session for as long as the mini window shows it. */
  retainChild: (sessionId: SessionId, memberId: SessionId, signal: AbortSignal) => SessionReference
  /**
   * Load one Session's projection baseline, so a node can show the figures its
   * child Session already published without opening that Session's history.
   * Idempotent per connection; a refused read stays retryable on the next call.
   */
  refreshProjections: (sessionId: SessionId) => void
}

/** Full props of the Agent Canvas tab body. */
export type TeamPanelProps =
  PropsRuntime<'sidebar.right.pane.tab'>
  & PropsRenderSlots<'agent-team.canvas.chat' | 'agent-team.canvas.trajectory'>
  & TeamPanelInjected
  & PropsLocale<typeof NS>

/**
 * Node card size and the spacing the canvas lays the hierarchy out with. The
 * card itself is designed at 320x140 (an identity row plus six metric tiles)
 * and drawn at half that by `.nodeScaler`, so these are the half-size boxes
 * the layout positions and links.
 */
const NODE_W = 180
const NODE_H = 70
const COLUMN_GAP = 22
const ROW_GAP = 116

/** Canvas zoom bounds, the click step, and how much one wheel pixel is worth. */
const MIN_ZOOM = 0.4
const MAX_ZOOM = 2.5
const ZOOM_STEP = 1.25
const ZOOM_PER_PIXEL = 0.005
/** One wheel event can move the zoom by at most a notch's worth of delta. */
const ZOOM_EVENT_CAP = 24

/** Hold one wheel delta inside the per-event budget. */
function clampDelta(delta: number): number {
  return Math.max(-ZOOM_EVENT_CAP, Math.min(ZOOM_EVENT_CAP, delta))
}

/** Hold one zoom factor inside the canvas's range. */
function clampZoom(zoom: number): number {
  return Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, Math.round(zoom * 100) / 100))
}

/** Movement, in CSS pixels, below which a canvas pointer gesture is still a tap. */
const PAN_SLOP = 3

/** The mini window's tab strip, in order. */
const TABS = ['edit', 'chat', 'trajectory'] as const
type CanvasTab = typeof TABS[number]

/** Window width and height in CSS pixels, as the user dragged them. */
export interface CanvasWindowSize {
  readonly w: number
  readonly h: number
}

/** Smallest window the grip allows, in CSS pixels. */
export const WINDOW_MIN: CanvasWindowSize = { w: 280, h: 220 }

/** Key versioned with the default it stores: a drag against an older default is not inherited. */
const WINDOW_SIZE_KEY = 'nero.agent-canvas.window.v2'

/** Distance the host keeps between the window and the canvas edge. */
const WINDOW_INSET = 12

/**
 * Resolve one grip drag into a window size. The window is anchored at its
 * bottom-right corner, so dragging up and left grows it.
 * @param start - size the drag began from.
 * @param pointer - pointer travel since the drag began.
 * @param max - largest size the canvas leaves room for.
 * @returns the clamped window size.
 */
export function resizeMiniWindow(
  start: CanvasWindowSize,
  pointer: { readonly dx: number; readonly dy: number },
  max: CanvasWindowSize,
): CanvasWindowSize {
  const clamp = (value: number, floor: number, ceiling: number): number =>
    Math.round(Math.min(Math.max(value, floor), Math.max(floor, ceiling)))
  return {
    w: clamp(start.w - pointer.dx, WINDOW_MIN.w, max.w),
    h: clamp(start.h - pointer.dy, WINDOW_MIN.h, max.h),
  }
}

/** Restore a dragged window size, or `undefined` for the default that fills the canvas. */
function readWindowSize(): CanvasWindowSize | undefined {
  try {
    const stored = globalThis.localStorage?.getItem(WINDOW_SIZE_KEY)
    if (stored === null || stored === undefined) return undefined
    const parsed = JSON.parse(stored) as CanvasWindowSize
    return Number.isFinite(parsed.w) && Number.isFinite(parsed.h)
      ? resizeMiniWindow({ w: parsed.w, h: parsed.h }, { dx: 0, dy: 0 }, { w: parsed.w, h: parsed.h })
      : undefined
  } catch (_unreadableStorage) {
    // A blocked or unparsable store costs the drag, not the window.
    return undefined
  }
}

function writeWindowSize(size: CanvasWindowSize | null): void {
  try {
    if (size === null) globalThis.localStorage?.removeItem(WINDOW_SIZE_KEY)
    else globalThis.localStorage?.setItem(WINDOW_SIZE_KEY, JSON.stringify(size))
  } catch (_unwritableStorage) {
    // A blocked store leaves the drag in memory only.
  }
}

/** Response-preference choices the Edit Agent tab offers. */
const RESPONSE_PREFERENCES = ['Concise', 'Detailed', 'Detailed with reasoning'] as const

/** One member's Edit Agent draft. Only `jobRole` reaches the Host today. */
interface CanvasDraft {
  readonly agentName: string
  readonly systemPrompt: string
  readonly responsePreference: string
  readonly steps: readonly CanvasStep[]
}

function draftKey(memberId: SessionId): string {
  return `nero.agent-canvas.v1.${memberId}`
}

function failureText(error: { readonly code: string; readonly message: string }): string {
  return `${error.message} (${error.code})`
}

/**
 * Hold the pointer for a canvas or grip drag. Engines without pointer capture
 * (and test environments) simply see the moves delivered to the same element.
 * @param target - element running the drag.
 * @param pointerId - pointer to capture.
 */
function capturePointer(target: Element, pointerId: number): void {
  if (typeof target.setPointerCapture === 'function') target.setPointerCapture(pointerId)
}

function releasePointer(target: Element, pointerId: number): void {
  if (typeof target.releasePointerCapture === 'function') target.releasePointerCapture(pointerId)
}

function memberStatusKey(status: TeamRosterMember['status']): TeamKey {
  switch (status) {
    case 'running': return 'memberStatus.running'
    case 'inactive': return 'memberStatus.inactive'
    case 'provisioning': return 'memberStatus.provisioning'
    case 'failed': return 'memberStatus.failed'
  }
}

function memberDotState(status: TeamRosterMember['status']): StateDotState {
  switch (status) {
    case 'running':
    case 'provisioning': return 'ongoing'
    case 'inactive': return 'idle'
    case 'failed': return 'error'
  }
}

/** Restore one member's draft, or `undefined` when nothing was stored or storage is unavailable. */
function readDraft(memberId: SessionId): CanvasDraft | undefined {
  try {
    const stored = globalThis.localStorage?.getItem(draftKey(memberId))
    if (stored === null || stored === undefined) return undefined
    return JSON.parse(stored) as CanvasDraft
  } catch (_unreadableStorage) {
    // A blocked or unparsable store costs the draft, not the window.
    return undefined
  }
}

function writeDraft(memberId: SessionId, draft: CanvasDraft): void {
  try {
    globalThis.localStorage?.setItem(draftKey(memberId), JSON.stringify(draft))
  } catch (_unwritableStorage) {
    // A blocked store leaves the edit in memory only.
  }
}

/** A minus glyph: the icon set ships a plus but no matching minus. */
function IconMinusGlyph() {
  return (
    <svg viewBox="0 0 16 16" width="14" height="14" xmlns="http://www.w3.org/2000/svg" aria-hidden>
      <rect x="3" y="7.25" width="10" height="1.5" rx="0.75" fill="currentColor" />
    </svg>
  )
}

/**
 * Avatar glyph for one node: the Lead wears the Agent mark, a teammate is
 * read through its job role so a node says what the agent does at a glance.
 */
function avatarGlyph(member: TeamRosterMember): ReactNode {
  if (member.role === 'lead') return <IconAgentPresetOutlineRegular size={16} />
  const role = (member.jobRole ?? '').toLowerCase()
  if (role.includes('architect') || role.includes('plan')) return <IconPlanOutlineRegular size={16} />
  if (role.includes('review')) return <IconInspectOutlineRegular size={16} />
  if (role.includes('qa') || role.includes('test')) return <IconChecklistOutlineRegular size={16} />
  if (role.includes('research') || role.includes('explor')) return <IconBrowseOutlineRegular size={16} />
  if (role.includes('performance')) return <IconGaugeOutlineRegular size={16} />
  if (role.includes('security')) return <IconShieldOutlineRegular size={16} />
  if (role.includes('platform') || role.includes('devops') || role.includes('infra')) return <IconSettingsOutlineRegular size={16} />
  if (role.includes('data')) return <IconDatabaseOutlineRegular size={16} />
  if (role.includes('lead') || role.includes('manager')) return <IconGoalOutlineRegular size={16} />
  if (role.includes('design')) return <IconSparkleRegular size={16} />
  if (role.includes('writ') || role.includes('doc')) return <IconDeliverDocRegular size={16} />
  if (role.includes('develop') || role.includes('engineer') || role.includes('code')) return <IconCodeOutlineRegular size={16} />
  return <IconUserOutlineRegular size={16} />
}

/** The six metric tiles, in the order the node card draws them. */
const NODE_TILES: readonly {
  readonly key: 'context' | 'tokens' | 'speed' | 'model' | 'cacheHit' | 'todos'
  readonly tone: string
  readonly icon: ReactNode
}[] = [
  { key: 'context', tone: css.toneContext ?? '', icon: <IconGaugeOutlineRegular size={13} /> },
  { key: 'tokens', tone: css.toneTokens ?? '', icon: <IconDatabaseOutlineRegular size={13} /> },
  { key: 'speed', tone: css.toneSpeed ?? '', icon: <IconLightOutlineRegular size={13} /> },
  { key: 'model', tone: css.toneModel ?? '', icon: <IconSparkleRegular size={13} /> },
  { key: 'cacheHit', tone: css.toneCache ?? '', icon: <IconRefreshOutlineRegular size={13} /> },
  { key: 'todos', tone: css.toneTodos ?? '', icon: <IconChecklistOutlineRegular size={13} /> },
]

/** One agent's card on the canvas: identity, status, and its Session's live figures. */
function AgentNode({ member, metrics, x, y, selected, onSelect, onOpenFull, t }: {
  readonly member: TeamRosterMember
  readonly metrics: NodeMetrics
  readonly x: number
  readonly y: number
  readonly selected: boolean
  readonly onSelect: (id: SessionId) => void
  /** Absent on the Lead, whose own conversation is the one already on screen. */
  readonly onOpenFull?: () => void
  readonly t: TranslateNS<typeof NS>
}) {
  const [menuOpen, setMenuOpen] = useState(false)
  return (
    <div className={css.nodeShell} style={{ left: x, top: y, width: NODE_W, height: NODE_H }}>
      <div className={css.nodeScaler}>
        <button
          type="button"
          className={selected ? `${css.node} ${css.nodeSelected}` : css.node}
          data-agent-node={member.name}
          data-agent-role={member.role}
          data-agent-status={member.status}
          onClick={() => { onSelect(member.id) }}
        >
          <span className={css.nodeHead}>
            <span
              className={member.role === 'lead' ? `${css.nodeAvatar} ${css.nodeAvatarLead}` : css.nodeAvatar}
              aria-hidden
            >
              {avatarGlyph(member)}
            </span>
            <span className={css.nodeTitle}>
              <span className={css.nodeName}>{member.name}</span>
              <span className={css.nodeRole}>
                {member.jobRole === undefined || member.jobRole === '' ? member.description ?? t('unowned') : member.jobRole}
              </span>
            </span>
            <span className={css.nodeStatus} data-agent-node-status={member.status}>
              <StateDot state={memberDotState(member.status)} />
              {t(memberStatusKey(member.status))}
            </span>
          </span>
          <span className={css.nodeTiles}>
            {NODE_TILES.map((tile) => {
              const metric: NodeMetric = metrics[tile.key]
              return (
                <span key={tile.key} className={css.tile} data-agent-metric={tile.key} title={metric.title}>
                  <span className={`${css.tileIcon} ${tile.tone}`} aria-hidden>{tile.icon}</span>
                  <span className={css.tileValue}>{metric.value}</span>
                </span>
              )
            })}
          </span>
        </button>
        {/* The card's own menu sits beside the node button, not inside it: a
          button may not nest one. */}
        {onOpenFull === undefined ? null : <Menu
          open={menuOpen}
          onClose={() => { setMenuOpen(false) }}
          align="end"
          portal
          anchor={(
            <button
              type="button"
              className={css.nodeMenu}
              aria-haspopup="menu"
              aria-expanded={menuOpen}
              aria-label={t('nodeActions')}
              onClick={() => { setMenuOpen(open => !open) }}
            >
              <IconEllipsisOutlineRegular size={14} />
            </button>
          )}
        >
          <MenuItemButton onSelect={() => { setMenuOpen(false); onOpenFull() }}>
            {t('openFullChat')}
          </MenuItemButton>
        </Menu>}
      </div>
    </div>
  )
}

/** The Edit Agent tab: the member's identity, role, prompt, preference, and to-do list. */
function EditAgent({ member, parentSessionId, actions, t }: {
  readonly member: TeamRosterMember
  readonly parentSessionId: SessionId
  readonly actions: AgentChatActions
  readonly t: TranslateNS<typeof NS>
}) {
  const [draft, setDraft] = useState<CanvasDraft>(() => readDraft(member.id) ?? {
    agentName: member.name,
    systemPrompt: '',
    responsePreference: RESPONSE_PREFERENCES[0],
    steps: [],
  })
  const [copied, setCopied] = useState(false)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  // The select follows the edit at once; the roster value arrives with the
  // Host's answer and re-syncs it.
  const [role, setRole] = useState(member.jobRole ?? '')
  useEffect(() => { setRole(member.jobRole ?? '') }, [member.id, member.jobRole])
  const [editingStep, setEditingStep] = useState<string | null>(null)
  const [pendingStep, setPendingStep] = useState('')
  /** A role's proposed prompt waiting on the user: only a typed prompt needs the ask. */
  const [offeredPrompt, setOfferedPrompt] = useState<{ role: string; prompt: string } | null>(null)

  const update = (next: Partial<CanvasDraft>): void => {
    const merged = { ...draft, ...next }
    setDraft(merged)
    writeDraft(member.id, merged)
    setNotice(t('unsaved'))
  }

  const saveRole = (jobRole: string): void => {
    setBusy(true)
    void actions.updateRole(parentSessionId, { target: member.name, jobRole })
      .then((result) => { setNotice(result.ok ? t('roleSaved') : failureText(result.error)) })
      .finally(() => { setBusy(false) })
  }

  /**
   * Persist a role edit and offer that role's system prompt. An empty or still
   * untouched preset draft is filled silently — there is nothing of the user's
   * to protect — while a prompt the user wrote is only proposed, never lost.
   */
  const changeRole = (jobRole: string): void => {
    setRole(jobRole)
    saveRole(jobRole)
    const prompt = rolePrompt(jobRole)
    if (prompt === undefined) { setOfferedPrompt(null); return }
    if (draft.systemPrompt.trim() === '' || isPresetPrompt(draft.systemPrompt)) {
      setOfferedPrompt(null)
      update({ systemPrompt: prompt })
      return
    }
    setOfferedPrompt({ role: jobRole, prompt })
  }

  /** The prompt the chosen role offers, for a draft that has none yet. */
  const suggestedPrompt = draft.systemPrompt.trim() === '' ? rolePrompt(role) : undefined

  const steps = draft.steps
  const setSteps = (next: readonly CanvasStep[]): void => { update({ steps: next }) }

  return (
    <div className={css.form} data-agent-edit="">
      <label className={css.field}>
        <span className={css.fieldLabel}>{t('agentName')}</span>
        <input
          className={css.roleInput}
          value={draft.agentName}
          placeholder={t('agentNamePlaceholder')}
          onChange={(event) => { update({ agentName: event.target.value }) }}
        />
      </label>
      <label className={css.field}>
        <span className={css.fieldLabel}>{t('chatId')}</span>
        <span className={css.idRow}>
          <input className={css.roleInput} value={member.id} readOnly disabled aria-label={t('chatId')} />
          <button
            type="button"
            className={css.iconButton}
            aria-label={copied ? t('copied') : t('copy')}
            onClick={() => {
              void navigator.clipboard?.writeText(member.id).then(() => {
                setCopied(true)
                setNotice(t('copied'))
              })
            }}
          >
            <IconCopyOutlineRegular size={14} />
          </button>
        </span>
        <span className={css.fieldHelp}>{t('chatIdHelp')}</span>
      </label>
      <label className={css.field}>
        <span className={css.fieldLabel}>{t('roleLabel')}</span>
        <select
          className={css.select}
          value={role}
          disabled={busy}
          onChange={(event) => { changeRole(event.target.value) }}
        >
          <option value="">{t('unowned')}</option>
          {[...new Set([...ROLE_OPTIONS, ...member.jobRole === undefined || member.jobRole === '' ? [] : [member.jobRole]])]
            .map(role => <option key={role} value={role}>{role}</option>)}
        </select>
      </label>
      {/* Outside the label: a button belongs to the offer, not to the select. */}
      {offeredPrompt !== null && (
        <div className={css.roleOffer} role="status" data-agent-role-prompt="offer">
          <span className={css.fieldHelp}>{t('rolePromptOffer', { role: offeredPrompt.role })}</span>
          <span className={css.offerActions}>
            <button
              type="button"
              className={css.addStep}
              onClick={() => { update({ systemPrompt: offeredPrompt.prompt }); setOfferedPrompt(null) }}
            >
              {t('rolePromptReplace')}
            </button>
            <button type="button" className={css.addStep} onClick={() => { setOfferedPrompt(null) }}>
              {t('rolePromptKeep')}
            </button>
          </span>
        </div>
      )}
      <label className={css.field}>
        <span className={css.fieldLabel}>{t('systemPrompt')}</span>
        <textarea
          className={css.textarea}
          value={draft.systemPrompt}
          placeholder={t('systemPromptPlaceholder')}
          rows={5}
          onChange={(event) => { update({ systemPrompt: event.target.value }) }}
        />
      </label>
      {suggestedPrompt !== undefined && (
        <button
          type="button"
          className={css.link}
          data-agent-role-prompt="suggest"
          onClick={() => { update({ systemPrompt: suggestedPrompt }) }}
        >
          {t('rolePromptUse', { role })}
        </button>
      )}
      <label className={css.field}>
        <span className={css.fieldLabel}>{t('responsePreference')}</span>
        <select
          className={css.select}
          value={draft.responsePreference}
          onChange={(event) => { update({ responsePreference: event.target.value }) }}
        >
          {RESPONSE_PREFERENCES.map(preference => (
            <option key={preference} value={preference}>{preference}</option>
          ))}
        </select>
      </label>
      <div className={css.field}>
        <span className={css.stepsHead}>
          <span className={css.fieldLabel}>{t('todoList')}</span>
          <span className={css.spacer} />
          <button type="button" className={css.addStep} onClick={() => { setPendingStep(' ') }}>{t('addStep')}</button>
        </span>
        {steps.length === 0 && pendingStep === '' && <span className={css.fieldHelp}>{t('noSteps')}</span>}
        {steps.map(step => (
          <span key={step.id} className={css.step}>
            <input
              type="checkbox"
              className={css.stepCheck}
              checked={step.done}
              aria-label={step.text}
              onChange={() => {
                setSteps(steps.map(candidate => candidate.id === step.id
                  ? { ...candidate, done: !candidate.done }
                  : candidate))
              }}
            />
            {editingStep === step.id
              ? (
                <input
                  className={css.roleInput}
                  value={step.text}
                  aria-label={t('editStep')}
                  autoFocus
                  onChange={(event) => {
                    setSteps(steps.map(candidate => candidate.id === step.id
                      ? { ...candidate, text: event.target.value }
                      : candidate))
                  }}
                  onBlur={() => { setEditingStep(null) }}
                  onKeyDown={(event) => { if (event.key === 'Enter') setEditingStep(null) }}
                />
              )
              : <span className={step.done ? `${css.stepText} ${css.stepDone}` : css.stepText}>{step.text}</span>}
            {editingStep !== step.id && (
              <button
                type="button"
                className={css.iconButton}
                aria-label={`${t('editStep')}: ${step.text}`}
                onClick={() => { setEditingStep(step.id) }}
              >
                <IconCheckOutlineRegular size={13} />
              </button>
            )}
            <button
              type="button"
              className={css.iconButton}
              aria-label={`${t('deleteStep')}: ${step.text}`}
              onClick={() => { setSteps(steps.filter(candidate => candidate.id !== step.id)) }}
            >
              <IconTrashOutlineRegular size={13} />
            </button>
          </span>
        ))}
        {pendingStep !== '' && (
          <span className={css.step}>
            <input
              className={css.roleInput}
              value={pendingStep}
              placeholder={t('stepPlaceholder')}
              aria-label={t('stepPlaceholder')}
              autoFocus
              onChange={(event) => { setPendingStep(event.target.value) }}
              onKeyDown={(event) => {
                if (event.key !== 'Enter' || pendingStep.trim() === '') return
                setSteps([...steps, { id: `${String(Date.now())}`, text: pendingStep.trim(), done: false }])
                setPendingStep('')
              }}
            />
          </span>
        )}
      </div>
      {notice !== null && <span className={css.fieldHelp} role="status">{notice}</span>}
    </div>
  )
}

/** One agent's tabbed mini window: Edit Agent, Chat, and Trajectory. */
function MiniChat({
  member, actions, parentSessionId, retainChild, renderSlot, SessionProvider,
  size, onResize, onOpenFull, onClose, t,
}: {
  readonly member: TeamRosterMember
  readonly actions: AgentChatActions
  readonly parentSessionId: SessionId
  readonly retainChild: TeamPanelInjected['retainChild']
  readonly renderSlot: TeamPanelProps['renderSlot']
  readonly SessionProvider: TeamPanelProps['SessionProvider']
  readonly size: CanvasWindowSize | null
  readonly onResize: (size: CanvasWindowSize | null) => void
  readonly onOpenFull: (member: TeamRosterMember) => void
  readonly onClose: () => void
  readonly t: TranslateNS<typeof NS>
}) {
  const [tab, setTab] = useState<CanvasTab>('chat')
  const [reference, setReference] = useState<SessionReference | null>(null)
  const drag = useRef<{ pointerId: number; fromX: number; fromY: number; start: CanvasWindowSize; max: CanvasWindowSize } | null>(null)
  const embedded = tab === 'chat' || tab === 'trajectory'

  // The live occurrence only retains the child Session while one of its two tabs
  // is on screen; leaving them releases the hold.
  useEffect(() => {
    if (!embedded) return
    const controller = new AbortController()
    const held = retainChild(parentSessionId, member.id, controller.signal)
    setReference(held)
    return () => {
      controller.abort()
      held.release()
      setReference(null)
    }
  }, [embedded, member.id, parentSessionId, retainChild])

  return (
    <div
      className={css.card}
      style={size === null ? undefined : { width: size.w, height: size.h }}
      data-agent-mini-chat={member.name}
      data-agent-mini-tab={tab}
      // Double-clicking the window must not reach the canvas gesture beneath it.
      onDoubleClick={(event) => { event.stopPropagation() }}
    >
      <div className={css.cardHead}>
        <span className={css.avatar} aria-hidden>{member.name.slice(0, 1).toUpperCase()}</span>
        <span className={css.cardTitle}>
          <span className={css.cardName}>{member.name}</span>
          <span className={css.cardMeta}>
            <StateDot state={memberDotState(member.status)} />
            {member.jobRole === undefined || member.jobRole === ''
              ? t(memberStatusKey(member.status))
              : member.jobRole}
          </span>
        </span>
        <span className={css.spacer} />
        {member.role === 'teammate' && (
          <button
            type="button"
            className={css.iconButton}
            aria-label={t('openFullChat')}
            onClick={() => { onOpenFull(member) }}
          >
            <IconCopyOutlineRegular size={13} />
          </button>
        )}
        <button type="button" className={css.iconButton} aria-label={t('close')} onClick={onClose}>
          <IconCloseOutlineRegular size={13} />
        </button>
      </div>
      <div className={css.tabStrip} role="tablist">
        {TABS.map(candidate => (
          <button
            key={candidate}
            type="button"
            role="tab"
            aria-selected={tab === candidate}
            className={tab === candidate ? `${css.tab} ${css.tabActive}` : css.tab}
            onClick={() => { setTab(candidate) }}
          >
            {t(candidate === 'edit' ? 'tab.edit' : candidate === 'chat' ? 'tab.chat' : 'tab.trajectory')}
          </button>
        ))}
      </div>
      <div className={embedded ? `${css.tabBody} ${css.tabBodyEmbedded}` : css.tabBody}>
        {tab === 'edit' && (
          <EditAgent member={member} parentSessionId={parentSessionId} actions={actions} t={t} />
        )}
        {embedded && (
          reference === null
            ? <span className={css.fieldHelp}>{t('loading')}</span>
            : (
              <SessionProvider session={reference}>
                {renderSlot(tab === 'chat' ? 'agent-team.canvas.chat' : 'agent-team.canvas.trajectory', {})}
              </SessionProvider>
            )
        )}
      </div>
      <span className={css.cardFoot}>{member.description}</span>
      <button
        type="button"
        className={css.grip}
        data-agent-resize=""
        aria-label={t('resizeWindow')}
        onPointerDown={(event) => {
          if (event.button !== 0) return
          event.preventDefault()
          event.stopPropagation()
          const card = event.currentTarget.closest('[data-agent-mini-chat]')
          if (!(card instanceof HTMLElement)) return
          const host = card.closest('[data-agent-canvas]')
          const box = card.getBoundingClientRect()
          const hostBox = host instanceof HTMLElement ? host.getBoundingClientRect() : box
          capturePointer(event.currentTarget, event.pointerId)
          drag.current = {
            pointerId: event.pointerId,
            fromX: event.clientX,
            fromY: event.clientY,
            start: { w: box.width === 0 ? WINDOW_MIN.w : box.width, h: box.height === 0 ? WINDOW_MIN.h : box.height },
            max: {
              w: Math.max(WINDOW_MIN.w, hostBox.width - WINDOW_INSET * 2),
              h: Math.max(WINDOW_MIN.h, hostBox.height - WINDOW_INSET * 2),
            },
          }
        }}
        onPointerMove={(event) => {
          const active = drag.current
          if (active === null || active.pointerId !== event.pointerId) return
          onResize(resizeMiniWindow(active.start, {
            dx: event.clientX - active.fromX,
            dy: event.clientY - active.fromY,
          }, active.max))
        }}
        onPointerUp={(event) => {
          if (drag.current?.pointerId !== event.pointerId) return
          drag.current = null
          releasePointer(event.currentTarget, event.pointerId)
        }}
        onPointerCancel={() => { drag.current = null }}
        onDoubleClick={(event) => { event.stopPropagation(); onResize(null) }}
      />
    </div>
  )
}

/** Render the Team hierarchy and the tabbed mini window of whichever node is selected. */
export function TeamPanel({
  sessionId, load, updateRole, send, openTeammate, retainChild, refreshProjections,
  renderSlot, SessionProvider, useSessions, t,
}: TeamPanelProps) {
  const [loading, setLoading] = useState(false)
  const [view, setView] = useState<TeamView | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [selected, setSelected] = useState<SessionId | null>(null)
  const [windowSize, setWindowSize] = useState<CanvasWindowSize | null>(() => readWindowSize() ?? null)
  const resizeWindow = useCallback((size: CanvasWindowSize | null): void => {
    setWindowSize(size)
    writeWindowSize(size)
  }, [])
  /**
   * The canvas camera: pan in canvas pixels plus the graph's zoom factor.
   * `{ 0, 0, 1 }` is the home position — the graph centered in the panel.
   */
  const [camera, setCamera] = useState<{ x: number; y: number; z: number }>({ x: 0, y: 0, z: 1 })
  const zoomBy = useCallback((factor: number): void => {
    setCamera(current => ({ ...current, z: clampZoom(current.z * factor) }))
  }, [])
  const homeCamera = useCallback((): void => { setCamera({ x: 0, y: 0, z: 1 }) }, [])
  const canvasRef = useRef<HTMLDivElement>(null)
  const drag = useRef<{ pointerId: number; fromX: number; fromY: number; originX: number; originY: number } | null>(null)
  /** Whether the live canvas gesture moved far enough to be a pan, not a tap. */
  const panned = useRef(false)
  const sessionRef = useRef(sessionId)
  const refreshGeneration = useRef(0)
  sessionRef.current = sessionId

  const refresh = useCallback(async (): Promise<void> => {
    const requestedSession = sessionId
    const generation = ++refreshGeneration.current
    setLoading(true)
    const result = await load(requestedSession)
    if (sessionRef.current !== requestedSession || refreshGeneration.current !== generation) return
    setLoading(false)
    if (result.ok) {
      setView(result.value)
      setError(null)
    } else {
      setError(failureText(result.error))
    }
  }, [load, sessionId])

  // The tab body has no open gesture of its own: mounting it IS the read. The
  // generation bump drops a response already in flight for a previous Session.
  useEffect(() => {
    refreshGeneration.current += 1
    setView(null)
    setSelected(null)
    setCamera({ x: 0, y: 0, z: 1 })
    setError(null)
    void refresh()
  }, [refresh])

  const summaries = useSessions(state => state.byId)
  const members = view?.members ?? []
  const memberKey = members.map(member => member.id).join(',')
  // A node draws the child Session's own figures; asking for its projection
  // baseline is what makes them present without activating its history.
  useEffect(() => {
    for (const id of memberKey === '' ? [] : memberKey.split(',')) refreshProjections(id as SessionId)
  }, [memberKey, refreshProjections])
  const leadMember = members.find(member => member.role === 'lead')
  const teammates = members.filter(member => member.role === 'teammate')
  const columns = Math.max(teammates.length, 1)
  const width = columns * NODE_W + (columns - 1) * COLUMN_GAP
  const height = ROW_GAP + NODE_H
  const leadX = (width - NODE_W) / 2
  const selectedMember = members.find(member => member.id === selected) ?? null
  const chatActions: AgentChatActions = useMemo(() => ({ load, updateRole, send }), [load, send, updateRole])

  // The wheel zooms the canvas about the pointer, with or without Ctrl/Cmd: the
  // ground has nothing of its own to scroll, so the gesture has one meaning
  // here, and the listener is native and non-passive so it can suppress the
  // browser's own zoom and the pane's scroll alike.
  const canvasMounted = view !== null
  useEffect(() => {
    const canvas = canvasRef.current
    if (canvas === null) return
    const onWheel = (event: WheelEvent): void => {
      // A line-mode wheel reports whole lines; bring it onto the pixel scale a
      // notch is worth, then cap one event so a coarse device cannot jump.
      const delta = clampDelta((event.deltaMode === 0 ? event.deltaY : event.deltaY * 16))
      if (delta === 0) return
      event.preventDefault()
      const rect = canvas.getBoundingClientRect()
      const pointerX = event.clientX - (rect.left + rect.width / 2)
      const pointerY = event.clientY - (rect.top + rect.height / 2)
      setCamera((current) => {
        const next = clampZoom(current.z * Math.exp(-delta * ZOOM_PER_PIXEL))
        if (next === current.z) return current
        // The graph is centered in the canvas, so pointer offsets are measured
        // from that home point: hold the graph point under the cursor still.
        const graphX = (pointerX - current.x) / current.z
        const graphY = (pointerY - current.y) / current.z
        return { x: pointerX - graphX * next, y: pointerY - graphY * next, z: next }
      })
    }
    canvas.addEventListener('wheel', onWheel, { passive: false })
    return () => { canvas.removeEventListener('wheel', onWheel) }
  }, [canvasMounted])

  return (
    <div className={css.root} data-team-panel>
      <div className={css.toolbar}>
        <strong>{t('typeLabel')}</strong>
        {teammates.length > 0 && <span className={css.count}>{teammates.length}</span>}
        {view !== null && <span className={css.meta}>{t('tasks')}: {view.tasks.length}</span>}
        <span className={css.spacer} />
        {loading && view !== null && (
          <span role="status" aria-label={t('loading')}><StateDot state="ongoing" /></span>
        )}
        {view !== null && (
          <div className={css.zoom} data-agent-zoom-controls>
            <button type="button" className={css.zoomButton} aria-label={t('zoomOut')} onClick={() => { zoomBy(1 / ZOOM_STEP) }}>
              <IconMinusGlyph />
            </button>
            <button
              type="button"
              className={css.zoomValue}
              aria-label={t('zoomReset')}
              onClick={() => { homeCamera() }}
            >
              {`${String(Math.round(camera.z * 100))}%`}
            </button>
            <button type="button" className={css.zoomButton} aria-label={t('zoomIn')} onClick={() => { zoomBy(ZOOM_STEP) }}>
              <IconPlusOutlineRegular size={14} />
            </button>
          </div>
        )}
        <button
          type="button"
          className={css.iconButton}
          aria-label={t('refresh')}
          onClick={() => { void refresh() }}
        >
          <IconRefreshOutlineRegular size={14} />
        </button>
      </div>
      <div className={css.body}>
        {error !== null && (
          <div className={css.error} role="alert"><StateDot state="error" />{error}</div>
        )}
        {loading && view === null && (
          <div className={css.notice} role="status"><StateDot state="ongoing" />{t('loading')}</div>
        )}
        {view !== null && (
          <div
            ref={canvasRef}
            className={css.canvas}
            data-agent-canvas
            data-agent-zoom={camera.z}
            // Double-clicking the ground returns the camera home: the graph
            // centered at full size.
            onDoubleClick={() => { homeCamera() }}
            onPointerDown={(event) => {
              // Dragging the empty canvas pans it; a node and the mini window
              // keep their own pointers.
              if (event.target instanceof Element
                && event.target.closest('[data-agent-node], [data-agent-mini-chat]') !== null) return
              capturePointer(event.currentTarget, event.pointerId)
              panned.current = false
              drag.current = {
                pointerId: event.pointerId,
                fromX: event.clientX,
                fromY: event.clientY,
                originX: camera.x,
                originY: camera.y,
              }
            }}
            // Tapping the empty canvas deselects: an open mini window belongs to
            // the node it was opened from, so clicking away from every node
            // closes it. A pan is not a tap, and a node or the window itself
            // keeps its own clicks.
            onClick={(event) => {
              if (event.target instanceof Element
                && event.target.closest('[data-agent-node], [data-agent-mini-chat]') !== null) return
              if (panned.current) { panned.current = false; return }
              setSelected(null)
            }}
            onPointerMove={(event) => {
              const active = drag.current
              if (active === null || active.pointerId !== event.pointerId) return
              if (Math.abs(event.clientX - active.fromX) > PAN_SLOP
                || Math.abs(event.clientY - active.fromY) > PAN_SLOP) {
                panned.current = true
              }
              setCamera(current => ({
                ...current,
                x: active.originX + (event.clientX - active.fromX),
                y: active.originY + (event.clientY - active.fromY),
              }))
            }}
            onPointerUp={(event) => {
              if (drag.current?.pointerId !== event.pointerId) return
              drag.current = null
              releasePointer(event.currentTarget, event.pointerId)
            }}
            onPointerCancel={() => { drag.current = null }}
          >
            <div
              className={css.graph}
              style={{ width, height, transform: `translate(${camera.x}px, ${camera.y}px) scale(${camera.z})` }}
            >
              <svg className={css.edges} width={width} height={height} aria-hidden>
                {teammates.map((member, index) => {
                  const fromX = leadX + NODE_W / 2
                  const toX = index * (NODE_W + COLUMN_GAP) + NODE_W / 2
                  const midY = (NODE_H + ROW_GAP) / 2
                  return (
                    <path
                      key={member.id}
                      className={css.edge}
                      data-agent-edge={member.name}
                      d={`M ${fromX} ${NODE_H} C ${fromX} ${midY}, ${toX} ${midY}, ${toX} ${ROW_GAP}`}
                    />
                  )
                })}
              </svg>
              {leadMember !== undefined && (
                <AgentNode
                  member={leadMember}
                  metrics={nodeMetrics(summaries[leadMember.id], leadMember.model, t)}
                  x={leadX}
                  y={0}
                  selected={selected === leadMember.id}
                  onSelect={setSelected}
                  t={t}
                />
              )}
              {teammates.map((member, index) => (
                <AgentNode
                  key={member.id}
                  member={member}
                  metrics={nodeMetrics(summaries[member.id], member.model, t)}
                  x={index * (NODE_W + COLUMN_GAP)}
                  y={ROW_GAP}
                  selected={selected === member.id}
                  onSelect={setSelected}
                  onOpenFull={() => { openTeammate(sessionId, member) }}
                  t={t}
                />
              ))}
            </div>
            {selectedMember !== null && (
              <div className={css.miniHost}>
                <MiniChat
                  key={selectedMember.id}
                  member={selectedMember}
                  actions={chatActions}
                  parentSessionId={sessionId}
                  retainChild={retainChild}
                  renderSlot={renderSlot}
                  SessionProvider={SessionProvider}
                  size={windowSize}
                  onResize={resizeWindow}
                  onOpenFull={(member) => { openTeammate(sessionId, member) }}
                  onClose={() => { setSelected(null) }}
                  t={t}
                />
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
