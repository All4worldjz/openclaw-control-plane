# OpenClaw macOS Setup App

This app is the installer shell for the `prod/mac` OpenClaw environment.

## Current Scope

This scaffold currently includes:

- a Tauri desktop app skeleton
- a multi-step installation wizard
- installer state and summary views
- a Rust `doctor_check` command for macOS prerequisite checks
- a Rust `clone_openclaw_repo` command to clone or update the runtime repo
- a Rust `render_prod_mac_config` command to generate `prod/mac` config files and LaunchAgent plist templates
- a Rust `smoke_check_prod_mac` command to validate rendered files and local LiteLLM readiness
- a Rust `provision_litellm_prod_mac` command to install LiteLLM and generate local service scripts
- a Rust `provision_openclaw_runtime_prod_mac` command to follow the official OpenClaw source-build flow
- LaunchAgent `load` / `unload` / `status` commands for LiteLLM and the OpenClaw runtime service script

## Verified Status

The following checks have been completed in this branch:

- `pnpm install`
- `pnpm build`
- `cargo check`
- `pnpm tauri build`

The generated macOS app bundle is written to:

```text
src-tauri/target/release/bundle/macos/OpenClaw macOS Setup.app
```

## Local Development

Use the working Node runtime explicitly if your shell has multiple Node installs:

```bash
PATH="$HOME/.cargo/bin:/Users/whoami2023/.nvm/versions/node/v22.22.1/bin:$PATH"
```

Install dependencies:

```bash
pnpm install
```

Run the frontend build only:

```bash
pnpm build
```

Run the desktop app in development mode:

```bash
pnpm tauri dev
```

Build the macOS application bundle:

```bash
pnpm tauri build
```

Run a Rust-only backend check:

```bash
cd src-tauri
cargo check
```

## Acceptance Checklist

- The wizard opens and renders all setup steps.
- `Environment` step completes and reports missing prerequisites correctly.
- `OpenClaw Source` step clones or updates the runtime repo.
- `Review` step renders the `prod/mac` config bundle outside Git.
- LiteLLM provisioning writes executable service scripts.
- OpenClaw runtime provisioning completes `pnpm install`, `pnpm ui:build`, `pnpm build`, and `pnpm link --global`.
- LaunchAgent commands can `load`, `status`, and `unload` both `litellm` and `runtime`.
- Smoke checks validate generated config files and local readiness paths.

## Remaining Work

- keep tracking upstream runtime startup contract changes from `openclaw/openclaw`
- wire Feishu and Telegram config generation deeper into the runtime config contract
- replace hardcoded local tool paths with a cleaner runtime environment strategy inside the app
- add richer install diagnostics, repair flow, and upgrade flow
- replace the placeholder icon with production branding assets

## Expected Working Directory Layout

The app assumes generated files will live outside this repository, for example:

```text
~/Library/Application Support/OpenClaw/
  app/
  config/
  state/
  logs/
  backups/
```
