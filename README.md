# openclaw-skills

Microsoft Graph automation skill focused on email, calendar, and OneDrive workflows.

## Included skill

- `graph-office-suite`

## What this skill supports

- OAuth device-code authentication with refresh-token handling
- Mail operations (list, filter, fetch, send)
- Calendar operations (list, create, update, cancel)
- OneDrive operations (list, upload, download, move, share)
- Contacts operations (list, create, get, update, delete)

## Quick start

1. Authenticate:
   ```bash
   python graph-office-suite/scripts/graph_auth.py device-login \
     --client-id 9e5f94bc-e8a4-4e73-b8be-63364c29d753 \
     --tenant-id consumers \
     --scopes Mail.ReadWrite Mail.Send Calendars.ReadWrite Files.ReadWrite.All offline_access
   ```
2. Run an operation:
   ```bash
   python graph-office-suite/scripts/mail_fetch.py --folder Inbox --top 10
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
- Calendar reference: `graph-office-suite/references/calendar.md`
- Drive reference: `graph-office-suite/references/drive.md`
