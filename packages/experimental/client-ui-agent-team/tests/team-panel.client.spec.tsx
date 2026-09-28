// @vitest-environment jsdom

import type { ReactNode } from 'react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import type { SessionReference } from '@nero/nero-api-session-controller/client'
import type { SessionId } from '@nero/nero-session/types'
import type { TeamView } from '@nero/nero-experimental-agent-team/client'
import { makeTranslate, RemoteError } from '@nero/nero-client-test-runtime'
import { zh as commonZh } from '@nero/nero-client-locale/src/locales/zh.ts'
import {
  resizeMiniWindow, TeamPanel, WINDOW_MIN,
  type TeamPanelInjected, type TeamPanelProps, type TeamPanelResult,
} from '../src/client/TeamPanel.tsx'
import { zh } from '../src/client/locales.ts'

afterEach(cleanup)

const SESSION = 'lead' as SessionId
const WORKER = 'worker-id' as SessionId
const view: TeamView = {
  members: [
    { id: SESSION, name: 'lead', role: 'lead', status: 'running', model: 'model-a', diagnostics: [] },
    {
      id: WORKER,
      name: 'worker',
      role: 'teammate',
      status: 'running',
      model: 'model-a',
      diagnostics: ['provider failed'],
    },
  ],
  tasks: [{
    id: 'task-1' as never,
    revision: 1,
    subject: 'Implement runtime',
    description: 'Build the Team runtime',
    status: 'in_progress',
    ownerName: 'worker',
    blockedBy: [],
    writeScopes: ['src'],
    ready: false,
    writeScopeWarnings: [],
  }],
}

function remoteFailure(message: string): TeamPanelResult<never> {
  return { ok: false, error: new RemoteError('gateway/internal', message, {}) }
}

const reference = { release: () => {} } as unknown as SessionReference
const renderSlot = vi.fn(() => null)

function props(
  actions: TeamPanelInjected,
  sessionId: SessionId = SESSION,
  byId: Record<string, unknown> = {},
): TeamPanelProps {
  return {
    sessionId,
    ...actions,
    renderSlot,
    SessionProvider: ({ children }: { children?: ReactNode }) => <>{children}</>,
    useSessions: (select: (state: unknown) => unknown) => select({ byId, ids: [] }),
    t: makeTranslate(zh, commonZh),
  } as unknown as TeamPanelProps
}

function actions(overrides: Partial<TeamPanelInjected> = {}): TeamPanelInjected {
  return {
    load: () => Promise.resolve({ ok: true, value: view }),
    updateRole: () => Promise.resolve({ ok: true, value: view.members[1]! }),
    send: () => Promise.resolve({ ok: true, value: { status: 'accepted' } }),
    openTeammate: () => {},
    retainChild: () => reference,
    refreshProjections: () => {},
    ...overrides,
  }
}

/** One teammate Session row carrying every figure a node card draws. */
function summary(): Record<string, unknown> {
  return {
    projectionValues: {
      modelSelection: { lastUsed: { provider: 'p', model: 'gpt-6-luna' }, next: null },
      contextPressure: { pressureTokens: 44_000, contextWindow: 200_000 },
      tokenUsage: { uncachedInputTokens: 4_000, outputTokens: 10_000, cacheReadTokens: 86_000, cacheWriteTokens: 0 },
      sessionStats: { decodeTokens: 1_100, decodeMs: 20_000 },
      todos: [{ content: 'a', status: 'completed' }, { content: 'b', status: 'pending' }],
    },
  }
}

describe('resizeMiniWindow', () => {
  const max = { w: 876, h: 776 }

  it('grows toward the corner the window is anchored on', () => {
    expect(resizeMiniWindow({ w: 380, h: 500 }, { dx: -100, dy: -60 }, max)).toEqual({ w: 480, h: 560 })
    expect(resizeMiniWindow({ w: 380, h: 500 }, { dx: 40, dy: 20 }, max)).toEqual({ w: 340, h: 480 })
  })

  it('holds the floor and the canvas ceiling', () => {
    expect(resizeMiniWindow({ w: 380, h: 500 }, { dx: 900, dy: 900 }, max)).toEqual(WINDOW_MIN)
    expect(resizeMiniWindow({ w: 380, h: 500 }, { dx: -900, dy: -900 }, max)).toEqual(max)
  })

  it('clamps a start already past the ceiling back into the canvas', () => {
    expect(resizeMiniWindow({ w: 4000, h: 3000 }, { dx: 0, dy: 0 }, max)).toEqual(max)
  })
})

describe('TeamPanel', () => {
  it('draws the hierarchy and opens one tabbed mini window per node', async () => {
    const openTeammate = vi.fn()
    render(<TeamPanel {...props(actions({ openTeammate }))} />)

    const nodes = await screen.findAllByRole('button', { name: /lead|worker/u })
    expect(nodes.map(node => node.getAttribute('data-agent-role'))).toEqual(['lead', 'teammate'])
    expect(document.querySelectorAll('[data-agent-edge]').length).toBe(1)
    expect(document.querySelector('[data-agent-mini-chat]')).toBeNull()

    fireEvent.click(screen.getByRole('button', { name: /worker/u }))
    expect(document.querySelector('[data-agent-mini-chat="worker"]')).not.toBeNull()

    // A node opens on the teammate's chat: the window is worth reading first,
    // and the Edit Agent form is one click away.
    await waitFor(() => { expect(renderSlot).toHaveBeenCalledWith('agent-team.canvas.chat', {}) })
    expect(document.querySelector('[data-agent-mini-chat="worker"]')?.getAttribute('data-agent-mini-tab'))
      .toBe('chat')
    // The window carries the conversation's own composer, so it never renders a
    // second message box of its own.
    expect(screen.queryByLabelText(zh.dmLabel)).toBeNull()

    fireEvent.click(screen.getByRole('button', { name: zh.openFullChat }))
    expect(openTeammate).toHaveBeenCalledWith(SESSION, view.members[1])

    fireEvent.click(screen.getByRole('button', { name: zh.close }))
    expect(document.querySelector('[data-agent-mini-chat]')).toBeNull()
  })

  it('draws each node as an agent card carrying that Session figures', async () => {
    const refreshProjections = vi.fn()
    const row = summary()
    render(<TeamPanel {...props(actions({ refreshProjections }), SESSION, { [SESSION]: row, [WORKER]: row })} />)

    const node = await screen.findByRole('button', { name: /worker/u })
    const tiles = [...node.querySelectorAll('[data-agent-metric]')]
      .map(tile => [tile.getAttribute('data-agent-metric'), tile.textContent])
    expect(tiles).toEqual([
      ['context', '44K/200K'],
      ['tokens', '100K'],
      ['speed', '55 t/s'],
      ['model', 'GPT 6 Luna'],
      ['cacheHit', '96%'],
      ['todos', '1 / 2'],
    ])
    // A node shows what the Session published; the canvas asks for exactly that.
    await waitFor(() => {
      expect(refreshProjections).toHaveBeenCalledWith(SESSION)
      expect(refreshProjections).toHaveBeenCalledWith(WORKER)
    })
    // The Lead has no menu: its own conversation is the one already on screen.
    const lead = screen.getByRole('button', { name: /lead/u })
    expect(lead.parentElement?.querySelectorAll('[aria-haspopup="menu"]').length).toBe(0)
    expect(node.parentElement?.querySelectorAll('[aria-haspopup="menu"]').length).toBe(1)
  })

  it('renders a tile as unavailable until its Session reports the fact', async () => {
    render(<TeamPanel {...props(actions(), SESSION, { [WORKER]: { projectionValues: {} }, [SESSION]: {} })} />)
    const node = await screen.findByRole('button', { name: /worker/u })
    // Only the roster's own model id survives without a Session projection.
    expect([...node.querySelectorAll('[data-agent-metric]')].map(tile => tile.textContent))
      .toEqual(['—', '—', '—', 'Model A', '—', '—'])
  })

  it('closes the open mini window when the empty canvas is tapped', async () => {
    render(<TeamPanel {...props(actions())} />)
    fireEvent.click(await screen.findByRole('button', { name: /worker/u }))
    const card = () => document.querySelector('[data-agent-mini-chat="worker"]')
    expect(card()).not.toBeNull()

    const canvas = document.querySelector<HTMLElement>('[data-agent-canvas]')!
    // Dragging the ground is a pan, not a tap: the window stays open.
    fireEvent.pointerDown(canvas, { button: 0, pointerId: 3, clientX: 200, clientY: 200 })
    fireEvent.pointerMove(canvas, { pointerId: 3, clientX: 240, clientY: 210 })
    fireEvent.pointerUp(canvas, { pointerId: 3, clientX: 240, clientY: 210 })
    fireEvent.click(canvas, { clientX: 240, clientY: 210 })
    expect(card()).not.toBeNull()

    // A click inside the window belongs to the window.
    fireEvent.click(card()!)
    expect(card()).not.toBeNull()

    // Tapping the ground away from every node closes it.
    fireEvent.click(canvas, { clientX: 120, clientY: 90 })
    expect(card()).toBeNull()
  })

  it('opens the selected agent in a three-tab mini window, Chat first', async () => {
    const updateRole = vi.fn(() => Promise.resolve({ ok: true as const, value: view.members[1]! }))
    const retainChild = vi.fn(() => reference)
    render(<TeamPanel {...props(actions({ updateRole, retainChild }))} />)
    fireEvent.click(await screen.findByRole('button', { name: /worker/u }))

    const tabs = screen.getAllByRole('tab')
    expect(tabs.map(tab => tab.textContent)).toEqual([zh['tab.edit'], zh['tab.chat'], zh['tab.trajectory']])
    expect(screen.getByRole('tab', { name: zh['tab.chat'] }).getAttribute('aria-selected')).toBe('true')
    // Opening on the chat holds the child Session straight away.
    expect(retainChild).toHaveBeenCalled()

    fireEvent.click(screen.getByRole('tab', { name: zh['tab.edit'] }))
    expect(screen.getByLabelText(zh.agentName)).toHaveProperty('value', 'worker')
    expect(screen.getByLabelText(zh.chatId)).toHaveProperty('value', WORKER)
    expect(screen.getByLabelText(zh.chatId)).toHaveProperty('disabled', true)
    expect(screen.getByLabelText(zh.systemPrompt)).toBeTruthy()
    expect(screen.getByText(zh.todoList)).toBeTruthy()

    fireEvent.change(screen.getByLabelText(zh.roleLabel), { target: { value: 'QA tester' } })
    await waitFor(() => {
      expect(updateRole).toHaveBeenCalledWith(SESSION, { target: 'worker', jobRole: 'QA tester' })
    })

    fireEvent.click(screen.getByRole('tab', { name: zh['tab.trajectory'] }))
    await waitFor(() => { expect(retainChild).toHaveBeenCalled() })
    expect(renderSlot).toHaveBeenCalledWith('agent-team.canvas.trajectory', {})
    expect(document.querySelector('[data-agent-mini-chat="worker"]')?.getAttribute('data-agent-mini-tab'))
      .toBe('trajectory')
    // The chat tab's own message box goes away with the tab that owns it.
    expect(screen.queryByLabelText(zh.dmLabel)).toBeNull()
  })

  it('adds, edits, and deletes a to-do step', async () => {
    render(<TeamPanel {...props(actions())} />)
    fireEvent.click(await screen.findByRole('button', { name: /worker/u }))
    fireEvent.click(screen.getByRole('tab', { name: zh['tab.edit'] }))
    fireEvent.click(screen.getByRole('button', { name: zh.addStep }))
    const draft = screen.getByLabelText(zh.stepPlaceholder)
    fireEvent.change(draft, { target: { value: 'Benchmark the results' } })
    fireEvent.keyDown(draft, { key: 'Enter' })
    expect(screen.getByText('Benchmark the results')).toBeTruthy()

    fireEvent.click(screen.getByRole('button', { name: `${zh.editStep}: Benchmark the results` }))
    const editing = screen.getByLabelText(zh.editStep)
    fireEvent.change(editing, { target: { value: 'Benchmark twice' } })
    fireEvent.keyDown(editing, { key: 'Enter' })
    expect(screen.getByText('Benchmark twice')).toBeTruthy()

    fireEvent.click(screen.getByRole('button', { name: `${zh.deleteStep}: Benchmark twice` }))
    expect(screen.queryByText('Benchmark twice')).toBeNull()
  })

  it('ignores a stale Team load after the tab switches sessions', async () => {
    const nextSession = 'next-lead' as SessionId
    const firstLoad = Promise.withResolvers<{ ok: true; value: TeamView }>()
    const nextView: TeamView = {
      ...view,
      members: [{ id: nextSession, name: 'next-lead', role: 'lead', status: 'running', diagnostics: [] }],
    }
    const load = vi.fn((sessionId: SessionId) => sessionId === SESSION
      ? firstLoad.promise
      : Promise.resolve({ ok: true as const, value: nextView }))
    const injected = actions({ load })
    const rendered = render(<TeamPanel {...props(injected)} />)

    rendered.rerender(<TeamPanel {...props(injected, nextSession)} />)
    expect((await screen.findAllByRole('button', { name: /next-lead/u })).length).toBeGreaterThan(0)
    firstLoad.resolve({ ok: true, value: view })
    await Promise.resolve()

    expect(screen.queryByRole('button', { name: /worker/u })).toBeNull()
  })

  it('keeps only the newest overlapping refresh for one session', async () => {
    const older = Promise.withResolvers<TeamPanelResult<TeamView>>()
    const newer = Promise.withResolvers<TeamPanelResult<TeamView>>()
    const nextView: TeamView = {
      ...view,
      members: [...view.members, { id: 'later' as SessionId, name: 'later-worker', role: 'teammate', status: 'running', diagnostics: [] }],
    }
    const load = vi.fn()
      .mockResolvedValueOnce({ ok: true, value: view })
      .mockImplementationOnce(() => older.promise)
      .mockImplementationOnce(() => newer.promise)
    render(<TeamPanel {...props(actions({ load }))} />)
    await screen.findByRole('button', { name: /worker/u })

    const refresh = screen.getByRole('button', { name: zh.refresh })
    fireEvent.click(refresh)
    fireEvent.click(refresh)
    newer.resolve({ ok: true, value: nextView })
    expect(await screen.findByRole('button', { name: /later-worker/u })).toBeTruthy()
    older.resolve({ ok: true, value: view })
    await Promise.resolve()

    expect(screen.getByRole('button', { name: /later-worker/u })).toBeTruthy()
    expect(document.querySelectorAll('[data-agent-node="worker"]').length).toBe(1)
  })

  it('resizes the mini window from its corner grip, in every tab', async () => {
    localStorage.clear()
    const cardRect = { width: 380, height: 500 }
    const hostRect = { width: 900, height: 800 }
    vi.spyOn(Element.prototype, 'getBoundingClientRect').mockImplementation(function (this: Element) {
      const box = this.hasAttribute('data-agent-canvas') ? hostRect : cardRect
      return {
        width: box.width,
        height: box.height,
        top: 0,
        left: 0,
        right: box.width,
        bottom: box.height,
        x: 0,
        y: 0,
        toJSON: () => ({}),
      } as DOMRect
    })
    render(<TeamPanel {...props(actions())} />)
    fireEvent.click(await screen.findByRole('button', { name: /worker/u }))

    const grip = document.querySelector('[data-agent-resize]')
    expect(grip).not.toBeNull()
    fireEvent.pointerDown(grip!, { button: 0, pointerId: 7, clientX: 1000, clientY: 800 })
    // Dragging the corner up and left grows the window; the canvas caps it.
    fireEvent.pointerMove(grip!, { pointerId: 7, clientX: 900, clientY: 700 })
    const card = document.querySelector<HTMLElement>('[data-agent-mini-chat="worker"]')
    expect(card?.style.width).toBe('480px')
    expect(card?.style.height).toBe('600px')
    fireEvent.pointerUp(grip!, { pointerId: 7, clientX: 900, clientY: 700 })

    // The window keeps one size across tabs, and the drag survives a reopen.
    fireEvent.click(screen.getByRole('tab', { name: zh['tab.edit'] }))
    expect(document.querySelector<HTMLElement>('[data-agent-mini-chat="worker"]')?.style.height).toBe('600px')
    fireEvent.click(screen.getByRole('tab', { name: zh['tab.chat'] }))
    expect(document.querySelector<HTMLElement>('[data-agent-mini-chat="worker"]')?.style.height).toBe('600px')
    fireEvent.click(screen.getByRole('button', { name: zh.close }))
    fireEvent.click(screen.getByRole('button', { name: /worker/u }))
    expect(document.querySelector<HTMLElement>('[data-agent-mini-chat="worker"]')?.style.width).toBe('480px')
  })

  it('shows load failures', async () => {
    render(<TeamPanel {...props(actions({
      load: () => Promise.resolve(remoteFailure('load failed')),
    }))} />)
    expect(await screen.findByRole('alert')).toHaveProperty('textContent', 'load failed (gateway/internal)')
  })
})
