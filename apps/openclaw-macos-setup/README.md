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

## Planned Next Steps

- render `prod/mac` config and `.env` files outside Git
- install and verify LiteLLM
- keep tracking upstream runtime startup contract changes from `openclaw/openclaw`
- wire Feishu and Telegram config generation deeper into the runtime config contract

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
