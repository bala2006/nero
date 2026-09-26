/** Shared names for the desktop Platform bridge. */
/** Private desktop channels; the Platform renderer receives bootstrap and locale updates. */
export const PLATFORM_IPC = {
  bootstrap: 'nero-platform:bootstrap',
  localeChanged: 'nero-platform:locale-changed',
  open: 'nero-platform:open',
  bounds: 'nero-platform:bounds',
  close: 'nero-platform:close',
} as const

/** Resolved Platform language; Desktop resolves the system preference before sending it. */
export type PlatformLocale = 'en_US' | 'zh_CN'
