# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [0.1.2] - 2026-03-06

### Changed
- Updated `graph-office-suite/SKILL.md` description to a push-first value proposition so ClawHub listing matches repository positioning.
- Fixed CI link checker workflow by removing unsupported Lychee CLI flag (`--exclude-mail`) from `.github/workflows/link-check.yml`.

## [0.1.1] - 2026-03-06

### Changed
- Moved skill runtime requirements to `metadata.openclaw.requires` / `metadata.openclaw.primaryEnv` for registry-aligned capability gating.
- Added explicit privileged-operations boundary documentation in `README.md` and `graph-office-suite/SKILL.md`.
- Added `--dry-run` support to `setup_mail_webhook_ec2.sh` and `run_mail_webhook_e2e_setup.sh` to preview writes and service actions before execution.

## [0.1.0] - 2026-03-06

### Added
- Push-first Microsoft Graph workflow for OpenClaw with webhook adapter, queue, and worker.
- EC2 setup automation, smoke tests, and full pipeline diagnostics scripts.
- Mail subscription lifecycle CLI (`create`, `status`, `renew`, `delete`, `list`).
- Wake-first integration with OpenClaw hooks (`/hooks/wake` default mode).

### Changed
- Default subscription resource updated to `me/messages` for broader delivery coverage.
- Documentation refocused on cost-aware, event-driven operation and self-hosted production setup.
- Diagnostics now include human-readable UTC timestamps for webhook operation logs.

### Security
- Documented secret handling and explicit hook token/clientState validation guidance.
- Added publish-scope controls and release hardening documentation.
