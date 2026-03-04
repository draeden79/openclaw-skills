---
name: graph-office-suite
description: Operate Outlook email, calendar, contacts, and OneDrive via Microsoft Graph with assisted OAuth, plus push mail notifications via webhook adapter.
---

# Graph Office Suite Skill

## 1. Quick prerequisites
1. Python 3 with `requests` installed.
2. Default auth values:
   - Client ID (personal-account default): `952d1b34-682e-48ce-9c54-bac5a96cbd42`
   - Tenant (personal-account default): `consumers`
   - Default scopes: `Mail.ReadWrite Mail.Send Calendars.ReadWrite Files.ReadWrite.All Contacts.ReadWrite offline_access`
   - For work/school accounts, use `--tenant-id organizations` (or tenant GUID) and a tenant-approved `--client-id`.
3. Tokens are stored in `state/graph_auth.json` (ignored by git).

## 2. Assisted OAuth flow (Device Code)
1. Run:
   ```bash
   python graph-office-suite/scripts/graph_auth.py device-login \
     --client-id 952d1b34-682e-48ce-9c54-bac5a96cbd42 \
     --tenant-id consumers
   ```
2. The script prints a **URL** and **device code**.
3. Open `https://microsoft.com/devicelogin`, enter the code, and approve with the target account.
4. Check and manage auth state:
   - `python graph-office-suite/scripts/graph_auth.py status`  
   - `python graph-office-suite/scripts/graph_auth.py refresh`  
   - `python graph-office-suite/scripts/graph_auth.py clear`
5. Other scripts call `utils.get_access_token()`, which refreshes tokens automatically when needed.
6. Scope override is disabled in `graph_auth.py`; the skill always uses `DEFAULT_SCOPES`.

Detailed reference: [`references/auth.md`](references/auth.md).

## 3. Email operations
- **List/filter**: `python graph-office-suite/scripts/mail_fetch.py --folder Inbox --top 20 --unread`
- **Fetch specific message**: `... --id <messageId> --include-body --mark-read`
- **Move message**: add `--move-to <folderId>` to the command above.
- **Send email** (`saveToSentItems` enabled by default):
  ```bash
  python graph-office-suite/scripts/mail_send.py \
    --to user@example.com \
    --subject "Update" \
    --body-file replies/thais.html --html \
    --cc teammate@example.com \
    --attachment docs/proposal.pdf
  ```
- Use `--no-save-copy` only when you intentionally do not want Sent Items storage.

More examples and filters: [`references/mail.md`](references/mail.md).

## 4. Calendar operations
- **List custom date window**:
  ```bash
  python graph-office-suite/scripts/calendar_sync.py list \
    --start 2026-03-03T00:00Z --end 2026-03-05T23:59Z --top 50
  ```
- **Create Teams or in-person event**: use `create`; add `--online` for Teams link.
- For personal Microsoft accounts (`tenant=consumers`), Teams meeting provisioning via Graph might not return a join URL; create the Teams meeting in Outlook/Teams first and add the resulting link to the event body when needed.
- **Update/cancel** events by `event_id` returned in JSON output.

Full examples: [`references/calendar.md`](references/calendar.md).

## 5. OneDrive / Files
- **List folders/files**: `python graph-office-suite/scripts/drive_ops.py list --path /`
- **Upload**: `... upload --local notes/briefing.docx --remote /Clients/briefing.docx`
- **Download**: `... download --remote /Clients/briefing.docx --local /tmp/briefing.docx`
- **Move / share links**: use `move` and `share` subcommands.
- The script resolves localized/special-folder aliases (for example `Documents` and `Documentos`).

More details: [`references/drive.md`](references/drive.md).

## 6. Contacts
- **List/search**: `python graph-office-suite/scripts/contacts_ops.py list --top 20`
- **Create**: `... create --given-name Jane --surname Doe --email jane.doe@example.com`
- **Update/Delete**: `... update <contactId> ...` / `... delete <contactId>`
- Contacts are part of the default scope set and supported as a first-class workflow.

More details: [`references/contacts.md`](references/contacts.md).

## 7. Mail push mode (Webhook Adapter)
- **Adapter server** (Graph handshake + `clientState` validation + enqueue):
  ```bash
  python graph-office-suite/scripts/mail_webhook_adapter.py serve \
    --host 0.0.0.0 --port 8789 --path /graph/mail \
    --client-state "$GRAPH_WEBHOOK_CLIENT_STATE"
  ```
- **Subscription lifecycle** (`create/status/renew/delete/list`):
  ```bash
  python graph-office-suite/scripts/mail_subscriptions.py create \
    --notification-url "https://graph-hook.example.com/graph/mail" \
    --client-state "$GRAPH_WEBHOOK_CLIENT_STATE" \
    --minutes 4200
  ```
- **Async worker** (dedupe + fetch message + call OpenClaw `/hooks/agent`):
  ```bash
  python graph-office-suite/scripts/mail_webhook_worker.py loop \
    --session-key "$OPENCLAW_SESSION_KEY" \
    --hook-url "$OPENCLAW_HOOK_URL" \
    --hook-token "$OPENCLAW_HOOK_TOKEN"
  ```
- Worker queue files:
  - `state/mail_webhook_queue.jsonl`
  - `state/mail_webhook_dedupe.json`
- **Automated EC2 bootstrap** (Caddy + systemd + renew timer):
  ```bash
  sudo bash graph-office-suite/scripts/setup_mail_webhook_ec2.sh \
    --domain graphhook.example.com \
    --hook-url http://127.0.0.1:18789/hooks/agent \
    --hook-token "<OPENCLAW_HOOK_TOKEN>" \
    --session-key "hook:graph-mail" \
    --client-state "<GRAPH_WEBHOOK_CLIENT_STATE>" \
    --repo-root "$(pwd)"
  ```
- **One-command setup (steps 2..6)**:
  ```bash
  sudo bash graph-office-suite/scripts/run_mail_webhook_e2e_setup.sh \
    --domain graphhook.example.com \
    --hook-token "<OPENCLAW_HOOK_TOKEN>" \
    --hook-url "http://127.0.0.1:18789/hooks/agent" \
    --session-key "hook:graph-mail" \
    --test-email "tar.alitar@outlook.com"
  ```
- **Include OpenClaw hook config in automation**:
  ```bash
  sudo bash graph-office-suite/scripts/run_mail_webhook_e2e_setup.sh \
    --domain graphhook.example.com \
    --hook-token "<OPENCLAW_HOOK_TOKEN>" \
    --configure-openclaw-hooks \
    --openclaw-config "/etc/openclaw/config.json5" \
    --openclaw-service-name "openclaw" \
    --openclaw-hooks-path "/hooks" \
    --openclaw-allow-request-session-key true \
    --test-email "tar.alitar@outlook.com"
  ```
- Setup and runbook: [`references/mail_webhook_adapter.md`](references/mail_webhook_adapter.md).

## 8. Logging and conventions
- Each script appends one JSON line to `state/graph_ops.log` with timestamp, action, and key parameters.
- Tokens and logs must never be committed.
- Commands assume execution from the repository root. Adjust paths if running elsewhere.

## 9. Troubleshooting
| Symptom | Action |
| --- | --- |
| 401/invalid_grant | Run `graph_auth.py refresh`; if it fails, run `clear` and repeat device login. |
| 403/AccessDenied | Missing scope or licensing/policy issue. Re-run device login with required scope(s). |
| 429/Throttled | Scripts do basic retry; wait a few seconds and retry. |
| `requests.exceptions.SSLError` | Verify local system date/time and TLS trust chain. |

This skill provides OAuth-driven workflows for email, calendar, files, contacts, and push-based mail automation via Microsoft Graph.
