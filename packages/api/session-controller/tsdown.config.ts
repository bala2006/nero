import { clientBundle } from '../../client/tsdown.client.ts'

export default clientBundle(
  '@nero/nero-api-session-controller',
  ['lib/types/index.js'],
  { hostPhase: true },
)
