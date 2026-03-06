# openclaw-skills

Push-based Microsoft Graph for OpenClaw.

Stop waking an LLM just to ask whether a new email arrived.
This repository provides a webhook-driven Graph skill that wakes OpenClaw only when work actually happens, reducing recurring inbox polling overhead in self-hosted deployments.

![License](https://img.shields.io/badge/license-MIT-green.svg)
![Release](https://img.shields.io/badge/release-v0.1.1-blue.svg)
![CI](https://img.shields.io/badge/ci-github_actions-informational.svg)

## Why this exists

Polling-based inbox checks are expensive in practice:
- A cron/heartbeat loop keeps waking agents even when nothing changed.
- Those recurring turns consume tokens and increase operating cost.
- They also increase noise in operational logs and incident triage.

Microsoft Graph change notifications flip the model:
- Graph pushes an event when a message changes.
- The skill validates and deduplicates events.
- OpenClaw receives a wake signal only when there is new work.

Core message: replace recurring inbox polling with event-driven notifications.

## Cost model

Assume one lightweight inbox-check wake-up uses about `2,000` input tokens and `400` output tokens.

Using GPT-5.3-Codex pricing (`$1.75 / 1M` input, `$14.00 / 1M` output), each wake-up costs about **$0.0091**. 

- **2-minute polling** = `720` wake-ups/day = about **$6.55/day** = about **$196.56/month**
- **Push mode with 5 real events/day** = `5` wake-ups/day = about **$0.05/day** = about **$1.37/month**

In this example, push reduces recurring wake-up spend by about **99%**.

These numbers are illustrative. Push does not remove the cost of processing real email work — it mainly removes the cost of waking the agent repeatedly just to check whether anything changed.

## What is included

Skill:
- `graph-office-suite`

Capabilities:
- OAuth device-code auth with refresh handling
- Mail, calendar, drive, and contacts automation
- Graph webhook adapter + worker queue + dedupe
- OpenClaw wake integration via `/hooks/wake`
- EC2-oriented setup, smoke testing, and end-to-end diagnostics

## Architecture at a glance

`Microsoft Graph -> webhook endpoint -> queue -> dedupe worker -> /hooks/wake -> OpenClaw`

See full architecture and flow in `docs/architecture.md`.

## Public HTTPS webhook URL prerequisite

Graph can deliver notifications only to a public HTTPS endpoint. Conceptual setup steps:

1) Own a domain or subdomain for webhook traffic (for example `graphhook.yourdomain.com`).
2) Create DNS record (`A`/`AAAA`) pointing that hostname to your public server IP.
3) Open inbound ports `80` and `443` in cloud firewall/security group.
4) Configure TLS termination (for example Caddy or Nginx) with a valid certificate.
5) Route `https://<your-host>/graph/mail` to `mail_webhook_adapter.py` in your host.
6) Validate externally:
   - `GET https://<your-host>/graph/mail?validationToken=test` returns `200` + token echo.
   - Graph subscription creation succeeds with `notificationUrl` set to this endpoint.

After this prerequisite is in place, use the setup scripts in `graph-office-suite/scripts/` to automate the remaining pipeline.

## Quickstart (push-first)

1) Authenticate:
```bash
python graph-office-suite/scripts/graph_auth.py device-login \
  --client-id 952d1b34-682e-48ce-9c54-bac5a96cbd42 \
  --tenant-id consumers
```

2) Bootstrap production services (EC2 target):
```bash
sudo bash graph-office-suite/scripts/setup_mail_webhook_ec2.sh --help
# preview all privileged actions first
sudo bash graph-office-suite/scripts/setup_mail_webhook_ec2.sh --dry-run --help
```

3) Run one-command setup:
```bash
sudo bash graph-office-suite/scripts/run_mail_webhook_e2e_setup.sh --help
# optional safe preview mode
sudo bash graph-office-suite/scripts/run_mail_webhook_e2e_setup.sh --dry-run --help
```

4) Validate readiness:
```bash
bash graph-office-suite/scripts/diagnose_mail_webhook_e2e.sh --help
bash graph-office-suite/scripts/run_mail_webhook_smoke_tests.sh --help
```

Onboarding paths:
- Personal Outlook: `docs/quickstart-personal-outlook.md`
- Microsoft 365 work/school: `docs/quickstart-m365-work-school.md`

## Permission profiles and client ID guidance

- Permission profiles: `docs/permission-profiles.md`
- The default public `client_id` is for testing convenience.
- For production, use your own App Registration to control consent, lifecycle, and governance.

## Security and auditability

- Token-bearing files stay in `state/` and must never be committed.
- Webhook authentication requires dedicated hook token headers.
- Graph webhook integrity uses `GRAPH_WEBHOOK_CLIENT_STATE`.
- Push-mode runtime requires: `OPENCLAW_HOOK_URL`, `OPENCLAW_HOOK_TOKEN`, `GRAPH_WEBHOOK_CLIENT_STATE`, `OPENCLAW_SESSION_KEY`.
- The project is self-hosted and production-oriented, with explicit setup and diagnostics.
- See `SECURITY.md` for threat model and credential revocation guidance.

## Privileged operations boundary

Core Graph operations are unprivileged Python scripts.

Privileged automation is limited to:
- `graph-office-suite/scripts/setup_mail_webhook_ec2.sh`
- `graph-office-suite/scripts/run_mail_webhook_e2e_setup.sh`

Without `--dry-run`, these can write under `/etc`, create/enable systemd units, and optionally patch OpenClaw config + restart services. Review script output with `--dry-run` before applying changes on production hosts.

## Documentation map

- Main skill guide: `graph-office-suite/SKILL.md`
- Architecture: `docs/architecture.md`
- Permission profiles: `docs/permission-profiles.md`
- FAQ: `docs/faq.md`
- Troubleshooting: `docs/troubleshooting.md`
- Positioning guide: `docs/positioning.md`
- ClawHub publish guide: `docs/publish-clawhub.md`
- Release notes draft: `docs/release-v0.1.0.md`
- Auth reference: `graph-office-suite/references/auth.md`
- Mail reference: `graph-office-suite/references/mail.md`
- Mail webhook adapter reference: `graph-office-suite/references/mail_webhook_adapter.md`
- Calendar reference: `graph-office-suite/references/calendar.md`
- Drive reference: `graph-office-suite/references/drive.md`
- Contacts reference: `graph-office-suite/references/contacts.md`
