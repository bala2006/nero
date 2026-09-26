# Agent Note: A deployment-owned plugin catalog in the install dialog

Status: implemented

English | [中文](2026-09-23-plugin-install-catalog.zh.md)

## Problem

The Plugins page's **Add plugin** dialog accepts one install spec: a package name, a git address, a tarball, or an absolute path. A person who does not already know a plugin's package name cannot add one, and the page offered no way to see what a deployment makes available. Querying the registry for candidates was not available either: npm's search answers by name, keywords, and popularity, and nothing in a published package manifest marks a package as a Nero bundle.

## Decision

`plugin-manager` gains a `catalog` config field: an ordered list of `{ spec, title, description }`, defaulting to the published experimental auto-review package. `pluginManager.catalog()` answers those entries, adding whether this profile's bundles and dependencies, or the installation's own dependencies, already hold the package each spec names. A spec's package name is read without installing it: a registry name as the spec spells it, or a local directory's own manifest name. A git address and a tarball name their package only once pnpm has fetched it, so such an entry is never reported as installed.

The Web dialog reads the catalog when it opens and lists it under the spec field, each entry carrying its own **Install** that fills the field and runs the check and install path a typed spec takes. An entry the profile or the installation already holds reads **Installed** and offers no control: the Host states that rather than hiding the entry, so a person sees that the plugin they are looking for is already there. A deployment whose list is empty shows no list.

The catalog carries deployment data, not product copy. Entry text is shown as written in every Client language, and a deployment replaces the list in its profile patch, so offering a further plugin needs no Client change.

## Alternatives considered

**Query the registry's search from the dialog.** npm's public search has no marker for these packages, and no `@nero/*` package is published, so a keyword search answers with unrelated packages from other ecosystems. Each result would also need the existing spec check before anything could be installed, leaving the dialog with a list that only sometimes installs.

**Keep the list as a constant in the Client package.** The UI bundle would then decide what a deployment offers, so changing the list would take a fork and a rebuild of the Client, and the Client cannot tell which entries the profile already holds.

**Derive the list from the installation's own packages.** Only the bundles the launcher names in `OPTIONAL_BUNDLES` ([shipped optional bundles](../process/2026-09-15-shipped-optional-bundles.md)) ship switched off, and the Official group already lists them with switches; every other bundle is either built into a profile or absent, so a derived list would restate that group.

**Widen `OPTIONAL_BUNDLES` instead.** That mechanism offers a bundle the installation already ships, which a third-party plugin is not; it also cannot carry the text that presents an entry.

## Consequences

A deployment, or a person's own profile patch, decides what the dialog offers. The shipped default names a package that is not published to npm in a source checkout, where installing it ends in the existing `not-found` sentence; pointing an entry at a private registry, a git address, or an absolute path is the deployment's own choice of edit.

Each dialog open costs one `catalog()` read, plus one manifest read per entry that names a local directory. The list carries no safety promise of its own: an entry installs through the same check, registry choice, and pnpm run as a typed spec, under the same warning the dialog shows for both.

Host tests cover the shipped default, a configured list, the package name read from a directory, and the reading that leaves a git address, a tarball, a directory without a readable manifest, and a refused spec uninstalled. Client tests cover the list's entries, one-click install of an entry's spec, the installed reading, entries without a title, and the refused, closed, and disposed reads that leave the list unshown.
