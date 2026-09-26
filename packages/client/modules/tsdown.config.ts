import { clientBundle } from '../tsdown.client.ts'

export default clientBundle(
  '@nero/nero-client-modules',
  ['lib/types/index.js', 'lib/types/invariant.js'],
)
