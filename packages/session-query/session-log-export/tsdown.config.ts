import { clientBundle } from '../../client/tsdown.client.ts'

export default clientBundle(
  '@nero/nero-session-log-export',
  ['lib/types/index.js'],
  { hostPhase: true },
)
