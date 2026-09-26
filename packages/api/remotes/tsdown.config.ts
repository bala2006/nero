import { clientBundle } from '../../client/tsdown.client.ts'

export default clientBundle(
  '@nero/nero-api-remotes',
  ['lib/types/index.js'],
  { hostPhase: true },
)
