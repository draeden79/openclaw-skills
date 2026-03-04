# Mail Webhook Adapter Reference

This guide documents the push architecture for mail notifications using Microsoft Graph + OpenClaw hooks.

## 1) Components

- `mail_webhook_adapter.py`: HTTP endpoint for Graph webhook delivery (handshake + enqueue).
- `mail_subscriptions.py`: Subscription lifecycle (`create`, `status`, `renew`, `delete`, `list`).
- `mail_webhook_worker.py`: Async queue processing with dedupe + Graph message fetch + POST to OpenClaw.

## 2) Webhook contract

Endpoint:

- `POST /graph/mail` (path is configurable in adapter)

Behavior:

1. If query contains `validationToken`, reply `200 text/plain` with exact token.
2. For normal notifications, validate `clientState`.
3. If accepted, enqueue minimal event:
   - `subscriptionId`
   - `messageId`
   - `changeType`
   - `receivedAt`
4. Reply quickly with `202`.

Security:

- Reject notifications with wrong `clientState`.
- Keep `clientState` secret and rotate periodically.
- Do not log full message payloads or tokens.

## 3) Manual vs automatic setup

### Manual (cannot be safely automated)

- [ ] DNS at registrar/provider (for example Namecheap): point `graphhook.<your-domain>` to EC2 public IP.
- [ ] Security group/firewall: allow inbound `80/tcp` and `443/tcp`.
- [ ] Microsoft Entra App Registration permissions/consent for mail scopes.
- [ ] First OAuth login (`graph_auth.py device-login`) with the mailbox account.
- [ ] Choose and securely store secrets:
  - [ ] `GRAPH_WEBHOOK_CLIENT_STATE`
  - [ ] `OPENCLAW_HOOK_TOKEN`
  - [ ] `OPENCLAW_SESSION_KEY`
- [ ] Confirm OpenClaw Hooks are enabled and token-protected (`/hooks/agent`).

### Automatic (scripted in this project)

Use:

```bash
sudo bash graph-office-suite/scripts/setup_mail_webhook_ec2.sh \
  --domain graphhook.example.com \
  --hook-url http://127.0.0.1:18789/hooks/agent \
  --hook-token "<OPENCLAW_HOOK_TOKEN>" \
  --session-key "hook:graph-mail" \
  --client-state "<GRAPH_WEBHOOK_CLIENT_STATE>" \
  --repo-root "$(pwd)"
```

The script automates:

- Caddy install/config (HTTPS reverse proxy to adapter)
- systemd service for webhook adapter
- systemd service for webhook worker
- renew timer/service scaffold for `mail_subscriptions.py renew`
- service enable/start

One-command setup for steps 2..6 (bootstrap + validation + create subscription + persist ID + restart + optional test mail):

```bash
sudo bash graph-office-suite/scripts/run_mail_webhook_e2e_setup.sh \
  --domain graphhook.example.com \
  --hook-token "<OPENCLAW_HOOK_TOKEN>" \
  --hook-url "http://127.0.0.1:18789/hooks/agent" \
  --session-key "hook:graph-mail" \
  --test-email "tar.alitar@outlook.com"
```

To also auto-configure OpenClaw hooks in the same run:

```bash
sudo bash graph-office-suite/scripts/run_mail_webhook_e2e_setup.sh \
  --domain graphhook.example.com \
  --hook-token "<OPENCLAW_HOOK_TOKEN>" \
  --configure-openclaw-hooks \
  --openclaw-config "/home/ubuntu/.openclaw/openclaw.json" \
  --openclaw-service-name "auto" \
  --openclaw-hooks-path "/hooks" \
  --openclaw-allow-request-session-key true \
  --test-email "tar.alitar@outlook.com"
```

This mode creates a backup of the OpenClaw config, patches/creates the `hooks` block, restarts OpenClaw, and executes `/hooks/wake` + `/hooks/agent` smoke tests.

Run minimal-input smoke tests any time:

```bash
bash graph-office-suite/scripts/run_mail_webhook_smoke_tests.sh \
  --domain graphhook.example.com \
  --create-subscription \
  --test-email tar.alitar@outlook.com
```

## 3.1) Start-to-finish runbook (manual + scripts)

Follow this exact order for a clean setup to full validation:

1. Manual prerequisites:
   - Configure DNS (`graphhook.<domain>` -> EC2 public IP).
   - Open inbound `80` and `443`.
   - Ensure OpenClaw Gateway is running locally on `127.0.0.1:18789`.
   - Complete OAuth device login once.
2. Run setup:
   - `setup_mail_webhook_ec2.sh` if you only want infrastructure/services.
   - `run_mail_webhook_e2e_setup.sh` for one-command full setup.
3. Confirm setup verdict:
   - Script prints `READY_FOR_PUSH` or `PARTIAL` status at the end.
4. Run smoke tests:
   - `run_mail_webhook_smoke_tests.sh --domain ... --create-subscription --test-email ...`
5. Confirm test verdict:
   - Script prints `READINESS VERDICT: READY_FOR_PUSH` only when critical + live email checks pass.

If verdict is `PARTIAL`, the script output lists exactly what is missing.

## 4) External setup checklist (EC2 / production)

- [ ] Public DNS record for the adapter host (for example `graph-hook.example.com`).
- [ ] Valid HTTPS certificate (AWS ACM + ALB, Nginx + Let's Encrypt, or equivalent).
- [ ] Port `443` open in security groups / firewall / WAF path rules.
- [ ] `notificationUrl` publicly reachable from Microsoft Graph.
- [ ] Azure App Registration configured for delegated mail scopes:
  - [ ] `Mail.ReadWrite`
  - [ ] `offline_access`
  - [ ] (Optional) `Mail.Send`
- [ ] Consent granted for required scopes (user/admin depending on tenant policy).
- [ ] Secrets managed outside code (`hooks.token`, `GRAPH_WEBHOOK_CLIENT_STATE`, auth file protection).

## 5) Internal setup checklist (host)

- [ ] Python runtime with dependencies installed (`requests`).
- [ ] OAuth device login completed and token available at `state/graph_auth.json`.
- [ ] Adapter process running as service (systemd, pm2, supervisor, container).
- [ ] Worker process running (loop mode) with retry/backoff defaults.
- [ ] Renewal job scheduled before expiration (cron/systemd timer).
- [ ] Structured logs enabled; no sensitive payload logging.
- [ ] Health/observability: queue length, worker failures, renewal status.

## 6) Environment and runtime values

Recommended values to keep in service environment:

- `GRAPH_WEBHOOK_CLIENT_STATE`: shared secret used in Graph subscription and adapter validation.
- `OPENCLAW_HOOK_URL`: OpenClaw endpoint (`/hooks/agent`).
- `OPENCLAW_HOOK_TOKEN`: hook token expected by OpenClaw.
- `OPENCLAW_SESSION_KEY`: target session key for routing notifications.

## 7) Operational commands

Start adapter:

```bash
python graph-office-suite/scripts/mail_webhook_adapter.py serve \
  --host 0.0.0.0 \
  --port 8789 \
  --path /graph/mail \
  --client-state "$GRAPH_WEBHOOK_CLIENT_STATE"
```

Create subscription:

```bash
python graph-office-suite/scripts/mail_subscriptions.py create \
  --notification-url "https://graph-hook.example.com/graph/mail" \
  --client-state "$GRAPH_WEBHOOK_CLIENT_STATE" \
  --minutes 4200
```

Renew subscription:

```bash
python graph-office-suite/scripts/mail_subscriptions.py renew \
  --id "<subscription-id>" \
  --minutes 4200
```

Run worker:

```bash
python graph-office-suite/scripts/mail_webhook_worker.py loop \
  --session-key "$OPENCLAW_SESSION_KEY" \
  --hook-url "$OPENCLAW_HOOK_URL" \
  --hook-token "$OPENCLAW_HOOK_TOKEN"
```

## 8) Acceptance test runbook

1. **Handshake**
   - Create subscription and verify adapter receives validation request.
   - Confirm adapter answers with plain-text token and subscription is created.
2. **Delivery**
   - Send one new test email to inbox.
   - Confirm one queue entry is appended in `state/mail_webhook_queue.jsonl`.
3. **Processing**
   - Run worker once/loop and validate:
     - Graph message fetch succeeds.
     - OpenClaw hook call returns success.
4. **Idempotency**
   - Re-deliver same notification payload (or duplicate event).
   - Confirm worker reports duplicate and avoids second hook delivery.
5. **Renewal**
   - Renew subscription and verify new `expirationDateTime`.
6. **Failure handling**
   - Stop OpenClaw hook endpoint temporarily.
   - Confirm retries increase and event remains queued until success or max retries.

## 9) Troubleshooting

- `400 ValidationError` on subscription create:
  - `notificationUrl` must be public HTTPS and return token immediately.
- `401/403` during message fetch:
  - Token/scopes missing; re-run auth and confirm `Mail.ReadWrite`.
- Queue grows continuously:
  - Worker unavailable or hook endpoint failing.
- Frequent duplicates:
  - Validate Graph retry behavior and dedupe window settings.
- Subscription expires:
  - Increase renewal automation frequency (for Outlook resources max is short-lived).
