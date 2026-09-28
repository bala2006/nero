/**
 * Canvas node metrics: the facts one teammate Session carries in its durable
 * projections, shaped for the node card. Every figure comes from the Session
 * itself (`modelSelection`, `contextPressure`, `tokenUsage`, `sessionStats`,
 * `todos`), read out of the Session list row the Client already keeps — the
 * Agent Canvas never opens a teammate's history to draw a node.
 */
import type { SessionProjectionMap, SessionSummary } from '@nero/nero-api-session-controller/client'
import type { TranslateNS } from '@nero/nero-client-ui-slots'
// Type-only: the projection keys a node reads and the packages that register them.
import type {} from '@nero/nero-token-meter/client'
import type {} from '@nero/nero-session-stats/client'
import type {} from '@nero/nero-tool-todo/client'
import type { NS } from './locales.ts'

/** One metric tile: the value the node shows and its exact hover text. */
export interface NodeMetric {
  readonly value: string
  readonly title: string
}

/** The six tiles of one node card; a tile without a value renders as unavailable. */
export interface NodeMetrics {
  /** Context occupancy: the prompt size of the newest request against the route's window. */
  readonly context: NodeMetric
  /** Every token the Session has been billed for. */
  readonly tokens: NodeMetric
  /** Decode speed of the Session's output so far. */
  readonly speed: NodeMetric
  /** The model the Session runs, as a display label. */
  readonly model: NodeMetric
  /** Share of prompt tokens served from the provider cache. */
  readonly cacheHit: NodeMetric
  /** Completed to-dos out of the list the Session last wrote. */
  readonly todos: NodeMetric
}

/** A tile whose Session has not reported the fact yet. */
function unavailable(t: TranslateNS<typeof NS>): NodeMetric {
  return { value: '—', title: t('metric.unavailable') }
}

/**
 * Compact count for a tile: whole units only — 517 / 13K / 1.1M — because a
 * third of the card is a narrow column and a decimal would be clipped there.
 */
export function formatCount(value: number): string {
  if (value < 1_000) return String(Math.round(value))
  if (value < 1_000_000) return `${String(Math.round(value / 1_000))}K`
  const millions = value / 1_000_000
  return `${millions >= 100 ? String(Math.round(millions)) : String(Math.round(millions * 10) / 10)}M`
}

/** Exact digits with grouping, for the hover text: 1,100,000. */
function grouped(value: number): string {
  const digits = String(Math.max(0, Math.round(value)))
  const groups: string[] = []
  for (let end = digits.length; end > 0; end -= 3) {
    groups.unshift(digits.slice(Math.max(0, end - 3), end))
  }
  return groups.join(',')
}

/**
 * Display label for a model id. The Agent-bound model catalog is refused to an
 * addressed teammate, so the id the Session recorded is all the node has; this
 * only makes it readable (`gpt-6-luna` -> `GPT 6 Luna`).
 * @param model - provider model id.
 * @returns a human-readable label.
 */
export function modelLabel(model: string): string {
  const ACRONYMS = new Set(['ai', 'api', 'cli', 'glm', 'gpt', 'llm', 'sdk', 'ui'])
  return model
    .split(/[._-]/u)
    .filter(part => part !== '')
    .map(part => (ACRONYMS.has(part.toLowerCase())
      ? part.toUpperCase()
      : `${part.slice(0, 1).toUpperCase()}${part.slice(1)}`))
    .join(' ')
}

/** Sum the four disjoint provider-usage buckets. */
function tokenTotal(usage: SessionProjectionMap['tokenUsage'] | undefined): number | undefined {
  return usage === undefined
    ? undefined
    : usage.uncachedInputTokens + usage.outputTokens
      + usage.cacheReadTokens + usage.cacheWriteTokens
}

/** Every prompt token of the newest request, the denominator a cache hit is read against. */
function promptTotal(usage: SessionProjectionMap['tokenUsage'] | undefined): number | undefined {
  return usage === undefined
    ? undefined
    : usage.uncachedInputTokens + usage.cacheReadTokens + usage.cacheWriteTokens
}

/** Whole-percent cache-hit share, or undefined without prompt input. */
function cacheHitShare(usage: SessionProjectionMap['tokenUsage'] | undefined): number | undefined {
  const prompt = promptTotal(usage)
  if (usage === undefined || prompt === undefined || prompt === 0) return undefined
  return Math.min(100, Math.round((usage.cacheReadTokens / prompt) * 100))
}

/** Decode speed in tokens per second, undefined until a decode was measured. */
function decodeSpeed(stats: SessionProjectionMap['sessionStats'] | undefined): number | undefined {
  if (stats === undefined || stats.decodeMs <= 0) return undefined
  return Math.round(stats.decodeTokens / (stats.decodeMs / 1_000))
}

/**
 * Read one teammate row into the node card's six tiles.
 * @param summary - the teammate Session's list row, when the list has it.
 * @param fallbackModel - the roster's model id, used before the Session reports one.
 * @param t - Agent Teams translator for the tiles' hover text.
 * @returns the six tiles, each either reported or unavailable.
 */
export function nodeMetrics(
  summary: SessionSummary | undefined,
  fallbackModel: string | undefined,
  t: TranslateNS<typeof NS>,
): NodeMetrics {
  const values = summary?.projectionValues

  const pressure = values?.contextPressure
  const used = pressure?.projectedTokens ?? pressure?.pressureTokens
  const window = pressure?.contextWindow
  const context: NodeMetric = used === undefined
    ? unavailable(t)
    : window === undefined
      ? { value: formatCount(used), title: t('metric.contextWindowless', { used: grouped(used) }) }
      : {
        // Compact on purpose: a `used/window` pair shares a third of the card.
        value: `${formatCount(used)}/${formatCount(window)}`,
        title: t('metric.context', { used: grouped(used), window: grouped(window) }),
      }

  const tokens = tokenTotal(values?.tokenUsage)
  const cacheHit = cacheHitShare(values?.tokenUsage)
  const speed = decodeSpeed(values?.sessionStats)

  const rawModel = values?.modelSelection?.next?.model
    ?? values?.modelSelection?.lastUsed?.model
    ?? fallbackModel
  const todos = values?.todos

  return {
    context,
    tokens: tokens === undefined || tokens === 0
      ? unavailable(t)
      : { value: formatCount(tokens), title: t('metric.tokens', { count: grouped(tokens) }) },
    speed: speed === undefined
      ? unavailable(t)
      : { value: `${formatCount(speed)} t/s`, title: t('metric.speed', { count: grouped(speed) }) },
    model: rawModel === undefined || rawModel === ''
      ? unavailable(t)
      : { value: modelLabel(rawModel), title: t('metric.model', { model: rawModel }) },
    cacheHit: cacheHit === undefined
      ? unavailable(t)
      : { value: `${String(cacheHit)}%`, title: t('metric.cacheHit', { percent: String(cacheHit) }) },
    todos: todos === null || todos === undefined || todos.length === 0
      ? unavailable(t)
      : {
        value: `${todos.filter(todo => todo.status === 'completed').length} / ${todos.length}`,
        title: t('metric.todos', {
          done: String(todos.filter(todo => todo.status === 'completed').length),
          total: String(todos.length),
        }),
      },
  }
}
