import { clientBundle } from '../../client/tsdown.client.ts'

export default clientBundle(
  '@nero/nero-api-job-controller',
  ['lib/types/index.js'],
  { hostPhase: true },
)
