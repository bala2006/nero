#!/usr/bin/env node

import { Context } from '@nero/cordis'
import { pathToFileURL } from 'node:url'
import Loader from '@nero/cordis-plugin-loader'

const ctx = new Context()
ctx.baseUrl = pathToFileURL(process.cwd()).href + '/'

await ctx.plugin(Loader)
await ctx.loader.create({
  name: '@nero/cordis-plugin-include',
  config: {
    path: './cordis.yml',
  },
})
