/**
 * Structured text view of a live document, shared by every carrier.
 *
 * The extractor is deliberately dependency-free and self-contained: it runs
 * in-process against a document a carrier already proved readable, and the
 * same source is injected into a page that only exposes script execution. It
 * reads nothing but element geometry, attributes, and text, so a visited
 * page's own scripting cannot influence the result.
 */

/** One reported interactive element. */
export interface SnapshotElement {
  /** Zero-based index usable as a stable handle within this snapshot. */
  readonly index: number
  /** Local tag name, lowercased. */
  readonly tag: string
  /** Visible label, value, or placeholder, whichever the element carries. */
  readonly label: string
  /** Address for links and form targets, when present. */
  readonly href?: string
  /** Input type, when the element declares one. */
  readonly inputType?: string
  /** Path selector that re-finds this element in a later evaluation. */
  readonly selector: string
}

/** Result of one document extraction. */
export interface DocumentSnapshot {
  /** Document title, or an empty string when it has none. */
  readonly title: string
  /** Document address as the reading context reports it. */
  readonly url: string
  /** Collapsed visible text of the document body, truncated to a bounded length. */
  readonly text: string
  /** Whether `text` was truncated. */
  readonly textTruncated: boolean
  /** Interactive elements in document order, truncated to a bounded count. */
  readonly elements: readonly SnapshotElement[]
  /** Whether `elements` was truncated. */
  readonly elementsTruncated: boolean
}

/**
 * Extract a bounded, plain-data view of one readable document.
 *
 * Self-contained by construction: every helper and limit lives inside this
 * body, so its own source can be evaluated inside a page that exposes script
 * execution without shipping anything else.
 * @returns title, address, visible text, and indexed interactive elements.
 */
export function extractDocument(document: Document): DocumentSnapshot {
  const MAX_ELEMENTS = 200
  const MAX_TEXT = 8000
  const MAX_LABEL = 160
  const collapse = (value: unknown, limit: number): string =>
    String(value ?? '').replace(/\s+/gu, ' ').trim().slice(0, limit)
  const path = (element: Element): string => {
    const parts: string[] = []
    let current: Element | null = element
    while (current !== null && current.parentElement !== null) {
      const tag = current.tagName.toLowerCase()
      const siblings = [...current.parentElement.children].filter(child => child.tagName === current?.tagName)
      parts.unshift(siblings.length > 1 ? tag + ':nth-of-type(' + String(siblings.indexOf(current) + 1) + ')' : tag)
      current = current.parentElement
    }
    return parts.join('/')
  }
  const body = document.body
  const raw = collapse(body === null || body === undefined ? '' : (body.innerText ?? body.textContent), MAX_TEXT + 1)
  const candidates = [...document.querySelectorAll(
    'a[href],button,input,select,textarea,[role="button"],[role="link"],[onclick]')]
  const elements = candidates.slice(0, MAX_ELEMENTS).map((element, index): SnapshotElement => {
    const href = element.getAttribute('href')
    const inputType = element.getAttribute('type')
    const value = 'value' in element && typeof element.value === 'string' ? element.value : ''
    const label = collapse(element.getAttribute('aria-label')
      ?? (value || element.getAttribute('placeholder') || element.textContent || element.getAttribute('name')), MAX_LABEL)
    return {
      index,
      tag: element.tagName.toLowerCase(),
      label,
      ...href === null ? {} : { href: collapse(href, 512) },
      ...inputType === null ? {} : { inputType: collapse(inputType, MAX_LABEL) },
      selector: path(element),
    }
  })
  return {
    title: collapse(document.title, MAX_LABEL),
    url: collapse(document.location?.href ?? '', 512),
    text: raw.slice(0, MAX_TEXT),
    textTruncated: raw.length > MAX_TEXT,
    elements,
    elementsTruncated: candidates.length > elements.length,
  }
}

/**
 * Script source that extracts the hosting document with {@link extractDocument}.
 * Injected verbatim where a carrier offers execution instead of DOM access.
 */
export const EXTRACT_SOURCE = `(${String(extractDocument)})(document)`

/**
 * Render a document snapshot as the text a caller receives.
 * @param snapshot - extraction result.
 * @returns a compact, line-oriented rendering.
 */
export function formatSnapshot(snapshot: DocumentSnapshot): string {
  const lines = [`# ${snapshot.title === '' ? '(untitled)' : snapshot.title}`, snapshot.url]
  if (snapshot.elements.length > 0) {
    lines.push('', '## Interactive elements')
    for (const element of snapshot.elements) {
      const details = [element.inputType, element.href].filter(value => value !== undefined).join(' ')
      lines.push(`[${String(element.index)}] <${element.tag}> ${element.label}${details === '' ? '' : ` — ${details}`}`)
    }
    if (snapshot.elementsTruncated) lines.push('… more elements omitted')
  }
  lines.push('', '## Text', snapshot.text)
  if (snapshot.textTruncated) lines.push('… text truncated')
  return lines.join('\n')
}
