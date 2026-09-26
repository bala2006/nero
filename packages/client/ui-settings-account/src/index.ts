/** Host configuration for the account settings client. */
import type { Context } from '@nero/cordis'
import type {} from '@nero/nero-host-webserver'
import { type Config, CONTACT_CONFIG_GLOBAL } from './contact-config.ts'
export { Config } from './contact-config.ts'

/**
 * Publish public questionnaire options before browser plugins activate.
 * @param ctx - Host context collecting page initialization data.
 * @param config - validated deployment options.
 */
export function apply(ctx: Context, config: Config): void {
  ctx.on('webserver/index-inject', (table) => {
    table.push({ kind: 'global', name: CONTACT_CONFIG_GLOBAL, value: config })
  })
}
