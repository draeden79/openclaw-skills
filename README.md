# openclaw-skills

Microsoft Graph automation skill focused on email, calendar, and OneDrive workflows.

## Included skill

- `graph-office-suite`

## What this skill supports

- OAuth device-code authentication with refresh-token handling
- Mail operations (list, filter, fetch, send)
- Mail push notifications via Graph webhook adapter (no polling)
- Calendar operations (list, create, update, cancel)
- OneDrive operations (list, upload, download, move, share)
- Contacts operations (list, create, get, update, delete)

## Quick start

1. Authenticate:
   ```bash
   python graph-office-suite/scripts/graph_auth.py device-login \
     --client-id 952d1b34-682e-48ce-9c54-bac5a96cbd42 \
     --tenant-id consumers
   ```
2. Run an operation:
   ```bash
   python graph-office-suite/scripts/mail_fetch.py --folder Inbox --top 10
   ```
3. Optional: enable push mode (webhook + worker):
   ```bash
   python graph-office-suite/scripts/mail_webhook_adapter.py serve --client-state "$GRAPH_WEBHOOK_CLIENT_STATE"
   python graph-office-suite/scripts/mail_subscriptions.py create --notification-url "https://<your-domain>/graph/mail" --client-state "$GRAPH_WEBHOOK_CLIENT_STATE"
   python graph-office-suite/scripts/mail_webhook_worker.py loop --session-key "$OPENCLAW_SESSION_KEY" --hook-url "$OPENCLAW_HOOK_URL" --hook-token "$OPENCLAW_HOOK_TOKEN"
   ```
4. Optional: EC2 production bootstrap script (automates Caddy + services):
   ```bash
   sudo bash graph-office-suite/scripts/setup_mail_webhook_ec2.sh --help
   ```

## Security and privacy

- OAuth state and operation logs are written to `state/`.
- Never commit `state/graph_auth.json` or any token-bearing artifacts.
- This repository ignores local auth/cache files via `.gitignore`.
- Before publishing changes, check for accidental secrets:
  - `access_token`
  - `refresh_token`
  - `client_secret`
  - raw `Authorization: Bearer ...` values

## Documentation

- Main skill guide: `graph-office-suite/SKILL.md`
- Auth reference: `graph-office-suite/references/auth.md`
- Mail reference: `graph-office-suite/references/mail.md`
- Mail webhook adapter reference: `graph-office-suite/references/mail_webhook_adapter.md`
- Calendar reference: `graph-office-suite/references/calendar.md`
- Drive reference: `graph-office-suite/references/drive.md`
