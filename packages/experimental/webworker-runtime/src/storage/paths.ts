/**
 * Virtual root of the worker host's in-memory filesystem. Kept
 * in one module so the process shim, the path/os shims, and the VFS image
 * collector cannot drift apart.
 */

/** Virtual filesystem root; `process.cwd()` and every absolute path start here. */
export const NERO_ROOT = '/nero'

/** `$NERO_HOME`: durable-state directory inside the image. */
export const NERO_HOME = `${NERO_ROOT}/home`

/** Flat, symlink-free package tree resolved by the worker module loader. */
export const NERO_NODE_MODULES = `${NERO_ROOT}/node_modules`

/** Directory holding the composed cordis.yml. */
export const NERO_CONFIG = `${NERO_ROOT}/config`

/** Default (empty) workspace directory. */
export const NERO_WORKSPACE = `${NERO_ROOT}/workspace`

/** Temporary directory reported by `os.tmpdir()`. */
export const NERO_TMP = `${NERO_ROOT}/tmp`
