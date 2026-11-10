---
title: Repo bootstrap and packaging
type: grilling
status: closed
assignee: EllianCarlos
blocked_by: []
---

## Question

How the new repo is created with gh and bootstrapped (Cargo workspace, devenv and direnv, flake), how it is built reproducibly and shipped: Nix package, home-manager module with the systemd user unit and socket activation, import into this dotfiles repo, crates.io publishing of the core crate, and release binaries for other package managers.

## Resolution

Decided with the owner (all seven proposals accepted).

- **Repo identity**: `EllianCarlos/pizza-delivery`, public, dual-licensed MIT OR Apache-2.0. Created with `gh repo create` as the first implementation step, not during planning.
- **Workspace layout**: `crates/pizza-delivery-core` (pure, publishable), `crates/pizza-delivery` (binary with daemon, CLI and the `tui` feature), `web/` (Bun, React, Cloudscape), `prompts/` (stage templates embedded in the binary), `docs/` (design spec, glossary, ADRs). Root: `devenv.nix`, `.envrc`, `flake.nix`. Workspace `[lints]` deny `unwrap`, `expect` and `panic`; rustfmt for formatting.
- **Web assets**: the built web UI is embedded in the binary so the daemon serves it with no separate install. The crates.io package includes a prebuilt `web/dist` generated at release time and not committed to main. Bun is needed only for development and for the Nix and release builds.
- **Type generation**: TypeScript types generated from the `core` API and view-model types with `ts-rs`, committed under `web/src/generated/`; CI fails on drift.
- **Nix and dotfiles import**: the flake builds with crane (cached dependencies, the web build a separate derivation embedded in the binary) and exposes `packages.default`, `overlays.default` and `homeManagerModules.default`. The module adds `services.pizza-delivery` with `enable`, `package` and a `settings` attrset rendered to the TOML config, and a socket-activated systemd user unit pair on `default.target` with `Restart=on-failure`, never `graphical-session.target`. Dotfiles consumes it through a pinned entry in `pins.nix` with the existing `builtins.getFlake` pattern, so `check-nix-pins` covers bumps, preferring tags.
- **Releases**: a tag `vX.Y.Z` triggers GitHub Actions that publish `pizza-delivery-core` then `pizza-delivery` to crates.io (`cargo install pizza-delivery`), build binaries with cargo-dist for Linux (x86_64, aarch64) and macOS with checksums and an installer script, and update a Homebrew tap. AUR and other managers come later. A `pizza-delivery install-service` subcommand writes the systemd user units for non-Nix Linux users. macOS runs the daemon manually until launchd support exists. SemVer, starting at 0.x.
- **CI and seed contents**: CI runs fmt, `clippy -D warnings`, tests, `nix build`, the web typecheck and the type-drift check. The new repo's first commit holds the final design spec in `docs/designs/`, the glossary, and ADRs only for the hard-to-reverse choices (Rust core plus TypeScript web, ledger as source of truth, one daemon with a child process per stage). The wayfinder map, tickets and research branches stay in dotfiles as history, linked from the spec.
