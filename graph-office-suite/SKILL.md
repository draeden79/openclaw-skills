---
name: graph-office-suite
description: Operate Outlook email, Calendar, and OneDrive via Microsoft Graph with assisted OAuth (device code). Includes email read/send, calendar operations, and file management.
---

# Graph Office Suite Skill

## 1. Quick prerequisites
1. Python 3 with `requests` installed.
2. Default auth values:
   - Client ID (personal-account default): `9e5f94bc-e8a4-4e73-b8be-63364c29d753`
   - Tenant (personal-account default): `consumers`
   - Default scopes: `Mail.ReadWrite Mail.Send Calendars.ReadWrite Files.ReadWrite.All Contacts.ReadWrite offline_access`
   - For work/school accounts, use `--tenant-id organizations` (or tenant GUID) and a tenant-approved `--client-id`.
3. Tokens are stored in `state/graph_auth.json` (ignored by git).

## 2. Assisted OAuth flow (Device Code)
1. Run:
   ```bash
   python graph-office-suite/scripts/graph_auth.py device-login \
     --client-id 9e5f94bc-e8a4-4e73-b8be-63364c29d753 \
     --tenant-id consumers \
     --scopes Mail.ReadWrite Mail.Send Calendars.ReadWrite Files.ReadWrite.All Contacts.ReadWrite offline_access
   ```
2. The script prints a **URL** and **device code**.
3. Open `https://microsoft.com/devicelogin`, enter the code, and approve with the target account.
4. Check and manage auth state:
   - `python graph-office-suite/scripts/graph_auth.py status`  
   - `python graph-office-suite/scripts/graph_auth.py refresh`  
   - `python graph-office-suite/scripts/graph_auth.py clear`
5. Other scripts call `utils.get_access_token()`, which refreshes tokens automatically when needed.

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

## 7. Logging and conventions
- Each script appends one JSON line to `state/graph_ops.log` with timestamp, action, and key parameters.
- Tokens and logs must never be committed.
- Commands assume execution from the repository root. Adjust paths if running elsewhere.

## 8. Troubleshooting
| Symptom | Action |
| --- | --- |
| 401/invalid_grant | Run `graph_auth.py refresh`; if it fails, run `clear` and repeat device login. |
| 403/AccessDenied | Missing scope or licensing/policy issue. Re-run device login with required scope(s). |
| 429/Throttled | Scripts do basic retry; wait a few seconds and retry. |
| `requests.exceptions.SSLError` | Verify local system date/time and TLS trust chain. |

This skill provides a single OAuth-driven workflow for email, calendar, and file operations via Microsoft Graph.
