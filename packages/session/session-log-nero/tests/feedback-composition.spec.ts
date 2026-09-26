import { mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'
import { afterEach, expect, it, vi } from 'vitest'
import { Context } from '@nero/cordis'
import Loader from '@nero/cordis-plugin-loader'
import Include from '@nero/cordis-plugin-include'
import SessionStore, { SessionId } from '@nero/nero-session'
import JsonlSessionPersistence from '@nero/nero-session-persistence-jsonl'
import MessageFeedback from '@nero/nero-message-feedback'
import { recordFeedback } from '@nero/nero-command-feedback'
import LlmRuntime, { createAssistantMessage, createUserMessage } from '@nero/nero-llm'
import * as LlmNero from '@nero/nero-llm-nero'
import NeroLlmApiExtensions from '@nero/nero-nero-llm-api-extensions'
import { startMockLlmServer, type MockLlmServer } from '@nero/nero-llm-mock-server'
import * as SessionLogNero from '../src/index.ts'
import type { NeroSessionLogExtension } from '../src/types.ts'

let root: string | undefined
let ctx: Context | undefined
let server: MockLlmServer | undefined

afterEach(async () => {
  await ctx?.fiber.dispose()
  await server?.close()
  if (root !== undefined) await rm(root, { recursive: true, force: true })
  ctx = undefined
  server = undefined
  root = undefined
  vi.unstubAllEnvs()
})

it('uploads freeform feedback and message put/edit/delete through the unchanged provider route', async () => {
  root = await mkdtemp(join(tmpdir(), 'nero-feedback-upload-'))
  vi.stubEnv('NERO_HOME', root)
  vi.stubEnv('NERO_API_KEY', 'feedback-test-key')
  server = await startMockLlmServer({ sequence: ['invalid_request', 'success', 'success'] })
  const modules = new Map<string, unknown>([
    ['@nero/nero-session', SessionStore],
    ['@nero/nero-session-persistence-jsonl', JsonlSessionPersistence],
    ['@nero/nero-message-feedback', MessageFeedback],
    ['@nero/nero-llm', LlmRuntime],
    ['@nero/nero-llm-nero', LlmNero],
    ['@nero/nero-nero-llm-api-extensions', NeroLlmApiExtensions],
    ['@nero/nero-session-log-nero', SessionLogNero],
  ])
  const config = join(root, 'cordis.yml')
  await writeFile(config, JSON.stringify([...modules.keys()].map(name => ({
    name,
    ...name === '@nero/nero-session-persistence-jsonl'
      ? { config: { root: join(root!, 'sessions'), compression: 'none' } }
      : name === '@nero/nero-message-feedback'
        ? { config: { maxNoteBytes: 1024 } }
        : name === '@nero/nero-llm-nero'
          ? { config: { baseURL: server!.baseURL } }
          : name === '@nero/nero-session-log-nero'
            ? { config: { enabled: true } }
            : {},
  }))))
  ctx = new Context()
  ctx.baseUrl = pathToFileURL(root).href + '/'
  await ctx.plugin(Loader)
  ctx.loader.builtins.include = Include
  ctx.loader.internal = {
    version: 'v2',
    async import(specifier: string) {
      if (!modules.has(specifier)) throw new Error(`unexpected Loader import: ${specifier}`)
      return modules.get(specifier)
    },
  } as unknown as NonNullable<typeof ctx.loader.internal>
  await ctx.loader.create({ name: 'cordis:include', config: { path: pathToFileURL(config).href } })
  await ctx.loader.await()
  expect([...ctx.loader.entries()].filter(entry => entry.fiber === undefined && !entry.disabled)).toEqual([])

  const session = ctx.sessions.create(SessionId('feedback-upload'))
  const handle = await ctx.sessionPersistence.create(session.header)
  try {
    const user = createUserMessage({ content: [{ type: 'text', text: 'Question' }], source: { kind: 'user' } })
    const assistant = createAssistantMessage({ content: [{ type: 'text', text: 'Answer' }], source: { provider: 'nero-official', model: 'nero-v4-flash' } })
    session.append('turn/start', { turn: 1 })
    session.append('step/start', { turn: 1, step: 1 })
    session.append('user/message', user, { surfaceOp: 'append' })
    session.append('assistant/message', { message: assistant, stream: [], turn: 1, step: 1 }, { surfaceOp: 'append' })
    session.append('step/end', { turn: 1, step: 1 })
    session.append('turn/end', { turn: 1, reason: { kind: 'completed' } })
    const messages = session.deriveMessages()
    recordFeedback(session, { text: '  The session needs a clearer explanation.  ' })
    const created = await ctx.messageFeedback.put({ sessionId: session.id, messageId: assistant.id, rating: 'negative', note: 'Explain the result.', ifVersion: null })
    if (!created.ok) throw new Error(created.error.code)
    const initialPrefix = session.snapshotEvents()
    const request = async () => {
      const chunks = []
      for await (const chunk of ctx!.llm.stream({ provider: 'nero-official', model: 'nero-v4-flash', sessionId: session.id, messages: session.deriveMessages() })) chunks.push(chunk)
      return chunks.at(-1)
    }
    expect(await request()).toMatchObject({ type: 'finish', reason: { kind: 'error' } })
    expect(SessionLogNero.acceptedThrough(session)).toBe(-1)
    expect(await request()).toMatchObject({ type: 'finish', reason: { kind: 'stop' } })
    const first = (server.requests[0]!.body as { nero_session_log: NeroSessionLogExtension }).nero_session_log
    const retry = (server.requests[1]!.body as { nero_session_log: NeroSessionLogExtension }).nero_session_log
    expect(retry).toEqual(first)
    expect(first.events).toEqual(initialPrefix)
    expect(first.events.slice(-2)).toMatchObject([
      { type: 'feedback/record', data: { text: 'The session needs a clearer explanation.' } },
      { type: 'feedback/message-put', data: { sessionId: session.id, item: created.value } },
    ])
    expect(SessionLogNero.acceptedThrough(session)).toBe(first.throughSeq)

    const edited = await ctx.messageFeedback.put({
      sessionId: session.id, messageId: assistant.id, rating: 'positive',
      note: 'The explanation is clear now.', ifVersion: created.value.version,
    })
    if (!edited.ok) throw new Error(edited.error.code)
    expect(await ctx.messageFeedback.delete({
      sessionId: session.id, messageId: assistant.id, ifVersion: edited.value.version,
    })).toEqual({ ok: true, value: { absent: true } })
    expect(await request()).toMatchObject({ type: 'finish', reason: { kind: 'stop' } })
    const suffix = (server.requests[2]!.body as { nero_session_log: NeroSessionLogExtension }).nero_session_log
    expect(suffix.afterSeq).toBe(first.throughSeq)
    expect(suffix.events).toMatchObject([
      { type: 'session-log-nero/delivery-accepted' },
      { type: 'feedback/message-put', data: { sessionId: session.id, item: edited.value } },
      { type: 'feedback/message-delete', data: { sessionId: session.id, messageId: assistant.id } },
    ])
    expect(suffix.events.every(event => event.seq > first.throughSeq)).toBe(true)
    expect(SessionLogNero.acceptedThrough(session)).toBe(suffix.throughSeq)
    expect(session.deriveMessages()).toEqual(messages)
    expect(await ctx.messageFeedback.list({ sessionId: session.id })).toEqual({ ok: true, value: { items: [] } })
    for (const wire of server.requests) {
      expect(wire.path).toBe('/v1/messages')
      expect(wire.body).not.toHaveProperty('nero_feedback')
      expect(wire.body).toMatchObject({ model: 'nero-v4-flash', messages: [
        { role: 'user', content: [{ type: 'text', text: 'Question' }] },
        { role: 'assistant', content: [{ type: 'text', text: 'Answer' }] },
      ] })
    }
    await ctx.sessions.flush(session)
    expect((await handle.read()).events).toEqual(session.snapshotEvents())
  } finally {
    await handle.close()
  }
})
