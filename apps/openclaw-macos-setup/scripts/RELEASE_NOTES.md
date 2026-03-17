# OpenClaw macOS Setup App Release Notes

## Current Deliverable

This branch introduces the first working `Tauri` installer shell for `prod/mac`.

It includes:

- a desktop wizard UI
- OpenClaw runtime repo clone/update support
- `prod/mac` config and workspace template rendering
- LiteLLM provisioning helpers
- OpenClaw source-build helpers
- LaunchAgent control commands
- smoke-check commands
- a successful local `pnpm tauri build`

## Produced Artifact

```text
apps/openclaw-macos-setup/src-tauri/target/release/bundle/macos/OpenClaw macOS Setup.app
```

## Known Gaps

- Feishu and Telegram config are rendered, but still need deeper runtime contract alignment with upstream OpenClaw behavior.
- The generated icon is a placeholder asset.
- No signed or notarized macOS release flow has been added.
- The installer still assumes a local operator workflow rather than a consumer-grade packaged distribution.
