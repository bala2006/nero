import { Fragment, memo, useMemo } from 'react'
import type { ReactNode } from 'react'
import { JsonBlock, MarkdownText } from '@nero/nero-client-ui-primitives'
import type { MarkdownFileMentions, MarkdownPathImages } from '@nero/nero-client-ui-primitives'
import type { ChatNodeOwnerProps, ChatViewSlotProps, UseDisclosure, UsePresentation } from '../contract/slots.ts'
import type { AssistantBlock } from '../contract/snapshot.ts'
import { markdownLabels } from '../markdown-labels.ts'
import { ReasoningRow } from './ReasoningRow.tsx'
import { useSearchableHidden } from './searchable-hidden.ts'
import css from './AssistantMarkdown.module.css'

/**
 * Resolve an authored POSIX image path against the document's file API.
 * @param base - canonical `document.baseURI` at render time.
 * @param value - authored markdown destination.
 * @returns an absolute HTTP(S) file-API URL, or undefined for unsupported
 * protocols and non-local paths.
 */
export function localPathMediaUrl(base: string, value: string): string | undefined {
  if (!value.startsWith('/') || value.startsWith('//')) return undefined
  if (!base.startsWith('http:') && !base.startsWith('https:')) return undefined
  return new URL(`api/file?path=${encodeURIComponent(value)}`, base).href
}

export interface AssistantMarkdownProps {
  /** Render only the requested business portion, preserving original block indexes. */
  groupPart?: string | undefined
  /** Stable Hook forwarded to each independently expandable reasoning block. */
  useDisclosure: UseDisclosure
  blocks: readonly AssistantBlock[]
  streaming: boolean
  /** Frozen partial of an aborted turn: rendered with a stopped marker. */
  interrupted?: boolean | undefined
  /** Render consecutive image blocks through the attachment slot. */
  renderMessageImages: ChatNodeOwnerProps['renderMessageImages']
  /** Hide reasoning that belongs to the Turn-level process disclosure. */
  reasoningHidden?: boolean | undefined
  /** Live display policy for reasoning summaries. */
  usePresentation: UsePresentation
  /** Reveal the disclosure that hides this reasoning. */
  revealProcess?: (() => void) | undefined
  /** Resolved prose file mentions for this Assistant's closing turn. */
  mentions?: MarkdownFileMentions | undefined
  /** The owning view's locale seat, passed down as a plain prop. */
  t: ChatViewSlotProps['t']
}

/** Reasoning block as the Think variant summary row (figma 39:28304). */
export const AssistantMarkdown = memo(function AssistantMarkdown({
  blocks, streaming, interrupted, renderMessageImages, groupPart, useDisclosure,
  reasoningHidden = false, usePresentation, revealProcess, mentions, t,
}: AssistantMarkdownProps) {
  // Stable per locale revision (t identity changes on switch): a fresh object
  // per render would rebuild MarkdownText's component table every chunk.
  const labels = useMemo(() => markdownLabels(t), [t])
  // MarkdownText memoizes its vocabulary; keep its identity stable across renders.
  const pathImages = useMemo<MarkdownPathImages>(() => {
    return { resolve: value => localPathMediaUrl(document.baseURI, value) }
  }, [])
  const last = blocks.length - 1
  // Tool-call heads render as tool rows in the chat view's grouping pass, so
  // a node that is only those heads (or empty) would paint an empty root
  // between tool groups — skip the shell unless something visible remains. A
  // reasoning block carrying no summary paints nothing either, so it cannot
  // keep the shell alive on its own.
  const hasVisible = streaming
    || interrupted === true
    || blocks.some(block => block.kind !== 'tool-call'
      && !(block.kind === 'reasoning' && block.text.trim() === ''))
  if (!hasVisible) return null
  const rendered: ReactNode[] = []
  for (let i = 0; i < blocks.length; i++) {
    const block = blocks[i]
    if (block === undefined) continue
    if (groupPart === 'reasoning' && block.kind !== 'reasoning') continue
    if (groupPart === 'response' && block.kind === 'reasoning') continue
    switch (block.kind) {
      case 'text':
        rendered.push(
          <MarkdownText
            key={i}
            text={block.text}
            streaming={streaming}
            labels={labels}
            fileMentions={mentions}
            pathImages={pathImages}
          />,
        )
        break
      case 'reasoning': {
        // One row per reasoning RUN, not per block. pi-ai materializes a block
        // per provider reasoning item, and a single agentic step routinely
        // carries twenty of them, which painted a wall of identical "Think"
        // rows. Blocks whose text is empty carry no summary — reasoning the
        // provider returned encrypted-only — so they contribute nothing to the
        // run's text and are dropped outright once the run settles, matching
        // the Turn process layer, which already counts an empty reasoning block
        // as invisible. The live tail is the exception: it stays so the row
        // still signals that the model is thinking before its first summary
        // paragraph arrives.
        const start = i
        const parts: string[] = []
        while (i < blocks.length) {
          const candidate = blocks[i]
          if (candidate === undefined || candidate.kind !== 'reasoning') break
          if (candidate.text.trim() !== '') parts.push(candidate.text)
          i += 1
        }
        // The walk stopped on a non-reasoning block; step back so the loop's
        // own increment re-reads it as its own case.
        i -= 1
        const running = streaming && i === last
        if (parts.length === 0 && !running) break
        rendered.push(
          <ProcessReasoning
            key={start}
            hidden={reasoningHidden}
            reveal={revealProcess}
          >
            <ReasoningRow text={parts.join('\n\n')} running={running} usePresentation={usePresentation}
              useDisclosure={useDisclosure} t={t} />
          </ProcessReasoning>,
        )
        break
      }
      case 'image': {
        // Consecutive image blocks share one gallery so several images tile
        // into rows instead of each opening a one-image group of its own.
        // Keyed by the group's FIRST block index: a streaming append that
        // extends the group then only grows `images` instead of remounting
        // the gallery under a shifted key.
        const start = i
        const group = [block]
        while (i + 1 < blocks.length) {
          const next = blocks[i + 1]
          if (next === undefined || next.kind !== 'image') break
          group.push(next)
          i += 1
        }
        rendered.push(
          <Fragment key={start}>
            {renderMessageImages({
              images: group.map(({ attachment }) => ({ attachment })),
              align: 'start',
            })}
          </Fragment>,
        )
        break
      }
      // Grouped into tool rows by ChatView; hasVisible above skips an empty shell.
      case 'tool-call':
        break
      default:
        rendered.push(
          <JsonBlock
            key={i}
            label={t('message.unknownBlock')}
            payload={block.block}
            truncatedLabel={total => t('json.truncated', { total })}
          />,
        )
    }
  }
  return (
    <div className={css.root} data-streaming={streaming || undefined}>
      <div className={css.body}>
        {rendered}
        {interrupted && (groupPart === undefined || groupPart === 'response'
          || !blocks.some(block => block.kind !== 'reasoning' && block.kind !== 'tool-call'))
          && <span className={css.stopped}>{t('message.stopped')}</span>}
      </div>
    </div>
  )
})

function ProcessReasoning({ hidden, reveal, children }: {
  hidden: boolean
  reveal?: (() => void) | undefined
  children: ReactNode
}) {
  const ref = useSearchableHidden(hidden, reveal ?? NOOP)
  return <div ref={ref} data-turn-process-inline={hidden || undefined}>{children}</div>
}

const NOOP = (): void => {}
