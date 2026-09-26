import { clientBundle } from '../../client/tsdown.client.ts'

export default clientBundle(
  '@nero/nero-api-workspace-controller',
  ['lib/types/index.js'],
  { hostPhase: true },
)
