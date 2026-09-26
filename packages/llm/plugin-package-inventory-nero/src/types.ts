/** Wire types for the active Nero plugin package inventory. */

/** One exact active plugin package version. */
export interface NeroPluginPackageIdentity {
  readonly name: string
  readonly version: string
}

/** Versioned full package inventory carried by each official Nero request. */
export interface NeroPluginPackageInventoryExtension {
  readonly version: 1
  readonly packages: readonly NeroPluginPackageIdentity[]
}

declare module '@nero/nero-nero-llm-api-extensions/types' {
  interface NeroLlmApiExtensionMap {
    nero_plugin_packages: NeroPluginPackageInventoryExtension
  }
}
