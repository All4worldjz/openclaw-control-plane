# openclaw-control-plane

This repository stores the control plane for two physically isolated OpenClaw systems:

- macOS Intel local instance
- GCP Singapore instance

It stores:
- templates
- scripts
- agent persona skeletons
- LiteLLM config templates
- OpenClaw config templates
- operational docs
- eval scaffolding

It does NOT store:
- real secrets
- real bot tokens
- real session history
- real memory files
- real vector DBs
- real runtime state

## Top-level structure

- `docs/` architecture, runbooks, ops notes, policies
- `scripts/` bootstrap / deploy / backup scripts
- `templates/` reusable config templates
- `env/` environment-specific config templates
- `evals/` smoke / regression / e2e scaffolding
- `hooks/` local git hooks
- `state/` placeholders only
- `backups/` placeholders only

## Environment model

- `prod/mac`
- `prod/gcp`
- `lab/mac`
- `lab/gcp`

## Usage principle

Commit only reproducible configuration and code.
Never commit runtime data or secrets.
