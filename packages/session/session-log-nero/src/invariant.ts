/** Package-owned invariants for Nero session-log acceptance watermarks. */

import type { Context } from '@nero/cordis'
import { SessionSeq } from '@nero/nero-session'
import type { Session, SessionEvent } from '@nero/nero-session'
import type { InvariantFailure, InvariantInstaller } from '@nero/nero-invariants'
import type {} from './types.ts'

const PACKAGE_NAME = '@nero/nero-session-log-nero'

/** Cordis companion plugin name. */
export const name = 'session-log-nero-invariant'
/** Service required before the companion can reserve package ownership. */
export const inject = ['invariants']

/** Validate one acceptance watermark against its containing event and session. */
function validateDeliveryAccepted(session: Session, event: SessionEvent<'session-log-nero/delivery-accepted'>, fail: InvariantFailure): void {
  const { sessionId, throughSeq } = event.data
  const acceptedFormatVersion = event.data.sessionFormatVersion ?? 0
  if (!Number.isSafeInteger(acceptedFormatVersion)
    || acceptedFormatVersion < 0
    || Object.is(acceptedFormatVersion, -0)) {
    fail(
      'session-log-nero/delivery-accepted sessionFormatVersion must be a non-negative safe integer'
      + `, got ${String(acceptedFormatVersion)}`,
    )
  }
  if (acceptedFormatVersion !== session.header.version) return
  const inherited = session.header.parentSession !== undefined
    && !session.isOwnSeq(event.seq)
  if (sessionId !== session.id && !inherited) {
    fail('a non-inherited session-log-nero/delivery-accepted event must name its containing session')
  }
  let acceptedSeq: ReturnType<typeof SessionSeq>
  try {
    acceptedSeq = SessionSeq(throughSeq)
  } catch {
    fail(`session-log-nero/delivery-accepted throughSeq must identify an earlier event, got ${throughSeq} at seq ${event.seq}`)
  }
  if (acceptedSeq >= event.seq) {
    fail(`session-log-nero/delivery-accepted throughSeq must identify an earlier event, got ${throughSeq} at seq ${event.seq}`)
  }
}

/** Validate acceptance watermarks already present in one Session. */
function validateSession(session: Session, fail: InvariantFailure): void {
  // oxlint-disable-next-line typescript/no-deprecated -- Existing Session history read; migration deferred.
  for (const event of session.snapshotEvents()) {
    if (event.type === 'session-log-nero/delivery-accepted') validateDeliveryAccepted(session, event, fail)
  }
}

/** Validate one live session-event dispatch. */
function validateDispatched(args: unknown[], fail: InvariantFailure): void {
  const [session, event] = args as [Session, SessionEvent]
  if (event.type === 'session-log-nero/delivery-accepted') validateDeliveryAccepted(session, event, fail)
}

/** Install validation for restored, newly created, and newly appended watermarks. */
const install: InvariantInstaller = Object.assign((ctx: Context, fail: InvariantFailure) => {
  const validateExisting = (session: Session): void => { validateSession(session, fail) }
  ctx.sessions.list().forEach(validateExisting)
  ctx.on('session/created', validateExisting, { global: true })
  ctx.on('internal/dispatch', (_mode, eventName, args) => {
    if (eventName === 'session/event') validateDispatched(args, fail)
  }, { global: true })
}, { inject: ['sessions'] })

/**
 * Register this package's invariant companion.
 * @param ctx - Cordis context carrying the invariant service.
 * @returns the installed registration's disposer after setup succeeds.
 */
export const apply = (ctx: Context): Promise<() => void> =>
  Promise.resolve(ctx.invariants.register(PACKAGE_NAME, install))
