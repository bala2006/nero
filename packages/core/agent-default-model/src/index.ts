/**
 * Default model selection for an Agent without a session-specific selection.
 *
 * @module @nero/nero-agent-default-model
 */
import type {} from '@nero/nero-settings'

import type { Volatile } from '@nero/cordis'

import { Context, Service } from '@nero/cordis'
import z from '@nero/schemastery'
import type { ModelSelection } from '@nero/nero-agent'
import { ReasoningEffortId } from '@nero/nero-llm'
import type {} from '@nero/nero-config-editor'

declare module '@nero/cordis' {
  interface Context {
    /** Default model selection for Agents created without an explicit model. */
    agentDefaultModel: AgentDefaultModelConfig
  }
}

/** Default model selection supplied by plugin configuration. */
export interface Config {
  /**
   * Registered provider route, or undefined while none is adopted. A deployment
   * that ships no provider of its own leaves this unset, and
   * {@link AgentDefaultModelConfig.adoptFirstAvailableRoute} fills it from the
   * first route a user configures.
   */
  provider: Volatile<string | undefined>
  /** Provider-owned model id, or undefined while none is adopted. */
  model: Volatile<string | undefined>
  /** Adapter-owned reasoning effort; omission follows the provider default. */
  reasoningEffort: Volatile<string | undefined>
}

/** Project stored settings onto the Agent-facing selection type. */
function selection(settings: { provider: string; model: string; reasoningEffort?: string }): ModelSelection {
  return {
    provider: settings.provider,
    model: settings.model,
    ...settings.reasoningEffort === undefined
      ? {}
      : { reasoningEffort: ReasoningEffortId(settings.reasoningEffort) },
  }
}

/**
 * Owns the default model selection independently of any Host or transport.
 * Each operation reads the owning Config references.
 */
export class AgentDefaultModelConfig extends Service {
  static Config = z.object({
    provider: z.string().volatile(),
    model: z.string().volatile(),
    reasoningEffort: z.string().volatile(),
  })

  constructor(private readonly ownerContext: Context, private config: Config) {
    super(ownerContext, 'agentDefaultModel')

    ownerContext.inject(['settings'], (child) => { child.effect(() => child.settings.configure({ auto: false }, ownerContext.fiber)) })
    // A deployment that ships no provider of its own has no default until a
    // user configures one. Route registration is that signal: llm announces
    // every change to the live route set, so the first route to appear is
    // adopted, and a later change re-runs the same guard.
    ownerContext.inject(['llm'], (child) => {
      child.effect(() => {
        const adopt = (): void => {
          void this.adoptFirstAvailableRoute().catch((error: unknown) => {
            child.logger.warn(`agent-default-model: adopting an available provider route failed: ${String(error)}`)
          })
        }
        adopt()
        return child.on('llm/adapters-updated', adopt)
      }, 'agent-default-model: adopt the first provider route')
    })
  }

  /**
   * Read the current default model selection.
   * @returns a detached provider, model, and optional reasoning selection, with
   * empty provider and model while no route has been adopted.
   */
  currentSelection(): ModelSelection {
    const reasoningEffort = this.config.reasoningEffort.get()
    return selection({
      provider: this.config.provider.get() ?? '', model: this.config.model.get() ?? '',
      ...reasoningEffort === undefined ? {} : { reasoningEffort },
    })
  }

  /**
   * Adopt the first live provider route and its first model when the configured
   * default names no route that is currently registered. A default whose route
   * is still live is left untouched, so a provider the user deleted — and not
   * one they merely switched away from — is what triggers re-adoption.
   * @returns fulfillment after the optional profile write settles.
   */
  async adoptFirstAvailableRoute(): Promise<void> {
    const llm = this.ownerContext.get('llm')
    if (llm === undefined) return
    const providers = llm.listProviders()
    if (providers.length === 0) return
    const configured = this.config.provider.get()
    if (configured !== undefined && configured !== '' && providers.some(entry => entry.id === configured)) return
    const first = providers[0]
    if (first === undefined) return
    const models = await llm.listModels(first.id)
    const model = models[0]
    if (model === undefined) return
    await this.saveSelection({ provider: first.id, model: model.id })
  }

  /**
   * Save the complete default model selection. A deployment without a configuration
   * editor keeps its composition entry.
   * @param next - resolved selection accepted by an entry point.
   * @returns fulfillment after the optional profile write settles.
   */
  async saveSelection(next: ModelSelection): Promise<void> {
    const entry = this.ownerContext.fiber.entry
    if (entry === undefined) return
    await this.ctx.get('configEditor')?.edit(entry, () => ({
      provider: next.provider, model: next.model,
      ...next.reasoningEffort === undefined ? {} : { reasoningEffort: String(next.reasoningEffort) },
    }))
  }
}

export default AgentDefaultModelConfig
