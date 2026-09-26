import type { TurnBoundaryProjection } from './types.ts'
import type {} from '@nero/nero-session-projection'

declare module '@nero/nero-session-projection/types' {
  interface SessionProjectionStateMap {
    /** The agent session's open/last turn and step boundary facts (whole value). */
    turnBoundary: TurnBoundaryProjection
  }
}

export {}
