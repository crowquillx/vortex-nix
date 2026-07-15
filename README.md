# Vortex for NixOS

This repository builds Nexus Mods' tagged Vortex source directly on NixOS. It
currently packages Vortex 2.3.0 with nixpkgs' Electron 42 runtime.

Run it from this checkout with:

```console
nix run path:.
```

Or install it into your user profile:

```console
nix profile install --accept-flake-config github:crowquillx/vortex-nix#vortex
vortex
```

## Binary cache

Successful builds from the `main` branch are published to the public
`vortex-nix` Cachix cache. Passing `--accept-flake-config` lets Nix use the
cache URL and signing key declared by this flake instead of rebuilding Vortex
locally.

When consuming this package as an input of another flake, add the cache to the
root flake because Nix only applies `nixConfig` from the flake being invoked:

```nix
nixConfig = {
  extra-substituters = [ "https://vortex-nix.cachix.org" ];
  extra-trusted-public-keys = [
    "vortex-nix.cachix.org-1:7+ZVU0umNp8sz1JqZV/bRcbVgemNuNtzN5KiJxihFRY="
  ];
};
```

The package registers the `nxm://` URL scheme through its desktop entry. When
Vortex launches Proton or a Windows modding tool through Proton, it routes the
generic Linux Proton executable through `steam-run`, providing the FHS
environment it needs on NixOS.

## Proton game support

The NixOS loader problem is handled by this package, and the Proton execution
path has been tested with a locally installed GE-Proton build. Mod deployment
itself operates on the Linux-visible Steam library and Proton prefix.

Vortex's native Linux support is still new, however, and compatibility remains
game- and extension-specific. Some bundled game plugins still perform
Windows-only registry discovery and may need a manually selected game folder
or may not work yet. Keep a game's staging folder on the same filesystem as
the game when using hardlink deployment.

Two optional bundled extensions try to download third-party Windows tools at
build time (`ARCtool` and `quickbms`). Nix builds are network-isolated, so those
tools are not included yet; this does not affect the core manager or its Proton
launcher.
