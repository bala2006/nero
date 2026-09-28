/**
 * Stage one of this package's registration: what the `agent-team` tab type IS.
 *
 * The type is a page, not a viewer: it claims no resource address, because the
 * roster views whatever the tab's own Session leads. The guide page offers it as
 * an entry box, and picking that box opens it as a right-Sidebar tab.
 */
import type { TranslateNS } from '@nero/nero-client-locale/client'
import type { SidebarRightTabDefinition } from '@nero/nero-client-ui-sidebar-right/client'
import { IconUserOutlineRegular } from '@nero/nero-client-ui-primitives'
import type { NS } from './locales.ts'

/** The tab kind this package owns. */
export const TEAM_PANEL_KIND = 'agent-team'

/** This implementation's identity in the tab system, and the key its body registers under. */
export const TEAM_PANEL_ID = '@nero/nero-experimental-client-ui-agent-team'

/**
 * The roster type's registry definition.
 * @param t - namespace-bound translate, read fresh on every label call.
 * @returns the definition to register.
 */
export function teamPanelDefinition(t: TranslateNS<typeof NS>): SidebarRightTabDefinition {
  return {
    id: TEAM_PANEL_ID,
    kind: TEAM_PANEL_KIND,
    priority: 'builtin',
    title: () => t('typeLabel'),
    guide: [{
      id: 'roster',
      order: 20,
      title: () => t('typeLabel'),
      description: () => t('guideDescription'),
      icon: IconUserOutlineRegular,
    }],
  }
}
