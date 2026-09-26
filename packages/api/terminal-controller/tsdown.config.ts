import { clientBundle } from '../../client/tsdown.client.ts'

export default clientBundle(
  '@nero/nero-api-terminal-controller',
  ['lib/types/index.js'],
  { hostPhase: true },
)
