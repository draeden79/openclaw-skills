# Mail Reference

## Listing

```
python graph-office-suite/scripts/mail_fetch.py --folder Inbox --top 10 --unread
```

- `--filter` accepts OData expressions (`contains(subject,'Status')`).
- `--id <messageId>` fetches a specific message.
- `--include-body` returns full body content (HTML + text).
- `--mark-read` and `--move-to <folderId>` act on the message loaded with `--id`.

## Sending

```
python graph-office-suite/scripts/mail_send.py \
  --to user@example.com \
  --subject "Follow-up" \
  --body-file drafts/reply.html --html \
  --cc teammate@example.com \
  --attachment docs/proposal.pdf
```

- `saveToSentItems` is `True` by default. Use `--no-save-copy` to disable.
- Attachments are sent as `fileAttachment` and are limited on this endpoint; for large files, implement upload session flow.

## Useful folder IDs

List folders with:
```
curl -H "Authorization: Bearer <ACCESS_TOKEN>" \
  https://graph.microsoft.com/v1.0/me/mailFolders
```
Or query a known folder with `mail_fetch.py --folder SentItems`.

## Push mode (no inbox polling)

### Start webhook adapter

```
python graph-office-suite/scripts/mail_webhook_adapter.py serve \
  --host 0.0.0.0 \
  --port 8789 \
  --path /graph/mail \
  --client-state "$GRAPH_WEBHOOK_CLIENT_STATE"
```

### Create Graph subscription

```
python graph-office-suite/scripts/mail_subscriptions.py create \
  --notification-url "https://graph-hook.example.com/graph/mail" \
  --client-state "$GRAPH_WEBHOOK_CLIENT_STATE" \
  --minutes 4200
```

### Process notifications asynchronously

```
python graph-office-suite/scripts/mail_webhook_worker.py loop \
  --session-key "$OPENCLAW_SESSION_KEY" \
  --hook-url "$OPENCLAW_HOOK_URL" \
  --hook-token "$OPENCLAW_HOOK_TOKEN"
```

- Adapter responds to Graph validation (`validationToken`) and enqueues compact events.
- Worker performs dedupe by `subscriptionId/messageId/changeType`.
- Worker fetches full mail object from Graph and posts to OpenClaw `/hooks/agent`.
- Renew subscriptions before expiration:

```
python graph-office-suite/scripts/mail_subscriptions.py renew --id "<subscription-id>" --minutes 4200
```

See full setup, checklists, and troubleshooting in:
`graph-office-suite/references/mail_webhook_adapter.md`.
