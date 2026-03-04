#!/usr/bin/env bash
set -euo pipefail

# One-command setup for steps 2..6:
# 2) Run EC2 bootstrap script
# 3) Validate public HTTPS endpoint handshake
# 4) Create Graph subscription
# 5) Persist subscription id + restart renew services
# 6) Optional real email send test

usage() {
  cat <<'EOF'
Usage:
  sudo bash graph-office-suite/scripts/run_mail_webhook_e2e_setup.sh \
    --domain graphhook.alitar.one \
    --hook-token "<OPENCLAW_HOOK_TOKEN>" \
    [--configure-openclaw-hooks] \
    [--openclaw-config /path/to/openclaw.json] \
    [--openclaw-service-name auto] \
    [--openclaw-hooks-path /hooks] \
    [--openclaw-allow-request-session-key true] \
    [--hook-url http://127.0.0.1:18789/hooks/agent] \
    [--session-key hook:graph-mail] \
    [--client-state "<GRAPH_WEBHOOK_CLIENT_STATE>"] \
    [--repo-root /path/to/openclaw-skills] \
    [--minutes 4200] \
    [--test-email tar.alitar@outlook.com]

Notes:
  - Must run on Linux host where OpenClaw + this repo are installed.
  - Must run as root (or via sudo), because it writes /etc/default and systemd units.
  - If --client-state is omitted, a strong value is auto-generated.
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

ok() { echo "[OK] $1"; }
info() { echo "[INFO] $1"; }

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

DOMAIN=""
HOOK_URL="http://127.0.0.1:18789/hooks/agent"
HOOK_URL_PROVIDED="false"
HOOK_TOKEN=""
SESSION_KEY="hook:graph-mail"
CLIENT_STATE=""
REPO_ROOT="$(pwd)"
MINUTES="4200"
TEST_EMAIL=""
CONFIGURE_OPENCLAW_HOOKS="false"
OPENCLAW_CONFIG=""
OPENCLAW_SERVICE_NAME="auto"
OPENCLAW_HOOKS_PATH="/hooks"
OPENCLAW_ALLOW_REQUEST_SESSION_KEY="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --hook-url) HOOK_URL="$2"; HOOK_URL_PROVIDED="true"; shift 2 ;;
    --hook-token) HOOK_TOKEN="$2"; shift 2 ;;
    --configure-openclaw-hooks) CONFIGURE_OPENCLAW_HOOKS="true"; shift 1 ;;
    --openclaw-config) OPENCLAW_CONFIG="$2"; shift 2 ;;
    --openclaw-service-name) OPENCLAW_SERVICE_NAME="$2"; shift 2 ;;
    --openclaw-hooks-path) OPENCLAW_HOOKS_PATH="$2"; shift 2 ;;
    --openclaw-allow-request-session-key) OPENCLAW_ALLOW_REQUEST_SESSION_KEY="$2"; shift 2 ;;
    --session-key) SESSION_KEY="$2"; shift 2 ;;
    --client-state) CLIENT_STATE="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --minutes) MINUTES="$2"; shift 2 ;;
    --test-email) TEST_EMAIL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$DOMAIN" || -z "$HOOK_TOKEN" ]]; then
  echo "Missing required arguments: --domain and --hook-token." >&2
  usage
  exit 1
fi

require_cmd curl
require_cmd systemctl
require_cmd python3
require_cmd sed
require_cmd grep
require_cmd cp

SETUP_SCRIPT="$REPO_ROOT/graph-office-suite/scripts/setup_mail_webhook_ec2.sh"
SUB_SCRIPT="$REPO_ROOT/graph-office-suite/scripts/mail_subscriptions.py"
SEND_SCRIPT="$REPO_ROOT/graph-office-suite/scripts/mail_send.py"
ENV_FILE="/etc/default/graph-mail-webhook"
ADAPTER_PATH="/graph/mail"

[[ -f "$SETUP_SCRIPT" ]] || { echo "File not found: $SETUP_SCRIPT" >&2; exit 1; }
[[ -f "$SUB_SCRIPT" ]] || { echo "File not found: $SUB_SCRIPT" >&2; exit 1; }

if [[ -z "$CLIENT_STATE" ]]; then
  CLIENT_STATE="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
)"
fi

if [[ "$OPENCLAW_HOOKS_PATH" != /* ]]; then
  OPENCLAW_HOOKS_PATH="/$OPENCLAW_HOOKS_PATH"
fi

if [[ "$CONFIGURE_OPENCLAW_HOOKS" == "true" ]]; then
  ACTING_USER="${SUDO_USER:-$USER}"
  ACTING_HOME="$(eval echo "~$ACTING_USER")"

  if [[ -z "$OPENCLAW_CONFIG" ]]; then
    CANDIDATES=(
      "/etc/openclaw/config.json5"
      "/etc/openclaw/config.json"
      "/opt/openclaw/config.json5"
      "/opt/openclaw/openclaw.json"
      "$HOME/.openclaw/config.json5"
      "$HOME/.openclaw/config.json"
      "$HOME/.openclaw/openclaw.json"
      "$HOME/.config/openclaw/config.json5"
      "$HOME/.config/openclaw/config.json"
      "$ACTING_HOME/.openclaw/config.json5"
      "$ACTING_HOME/.openclaw/config.json"
      "$ACTING_HOME/.openclaw/openclaw.json"
      "$ACTING_HOME/.config/openclaw/config.json5"
      "$ACTING_HOME/.config/openclaw/config.json"
    )
    for cand in "${CANDIDATES[@]}"; do
      if [[ -f "$cand" ]]; then
        OPENCLAW_CONFIG="$cand"
        break
      fi
    done
  fi

  if [[ -z "$OPENCLAW_CONFIG" ]]; then
    echo "OpenClaw config not found automatically." >&2
    echo "Provide --openclaw-config with the correct path." >&2
    echo "Try discovery on host:" >&2
    echo "  sudo sh -lc 'ls -la /etc/openclaw /opt/openclaw ~/.openclaw ~/.config/openclaw 2>/dev/null'" >&2
    exit 1
  fi
  [[ -f "$OPENCLAW_CONFIG" ]] || { echo "OpenClaw config not found: $OPENCLAW_CONFIG" >&2; exit 1; }

  if [[ "$HOOK_URL_PROVIDED" == "false" ]]; then
    HOOK_URL="http://127.0.0.1:18789${OPENCLAW_HOOKS_PATH}/agent"
  fi

  BACKUP_PATH="${OPENCLAW_CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$OPENCLAW_CONFIG" "$BACKUP_PATH"
  ok "OpenClaw config backup created: $BACKUP_PATH"

  python3 - "$OPENCLAW_CONFIG" "$HOOK_TOKEN" "$OPENCLAW_HOOKS_PATH" "$OPENCLAW_ALLOW_REQUEST_SESSION_KEY" <<'PY'
import sys
from pathlib import Path

cfg_path = Path(sys.argv[1])
token = sys.argv[2]
hooks_path = sys.argv[3]
allow_req = sys.argv[4].lower() == "true"

new_hooks = (
    "hooks: {\n"
    "    enabled: true,\n"
    f"    token: \"{token}\",\n"
    f"    path: \"{hooks_path}\",\n"
    "    defaultSessionKey: \"hook:ingress\",\n"
    f"    allowRequestSessionKey: {'true' if allow_req else 'false'},\n"
    "    allowedSessionKeyPrefixes: [\"hook:\"],\n"
    "  }"
)

text = cfg_path.read_text(encoding="utf-8")

def skip_ws(i):
    while i < len(text) and text[i].isspace():
        i += 1
    return i

def skip_str(i):
    quote = text[i]
    i += 1
    while i < len(text):
        c = text[i]
        if c == "\\":
            i += 2
            continue
        if c == quote:
            return i + 1
        i += 1
    return i

def skip_line_comment(i):
    while i < len(text) and text[i] != "\n":
        i += 1
    return i

def skip_block_comment(i):
    i += 2
    while i + 1 < len(text):
        if text[i] == "*" and text[i + 1] == "/":
            return i + 2
        i += 1
    return i

def skip_value(i):
    i = skip_ws(i)
    if i >= len(text):
        return i
    if text[i] in ("'", '"'):
        return skip_str(i)
    if text[i] in "{[":
        open_c, close_c = text[i], ("}" if text[i] == "{" else "]")
        depth = 0
        while i < len(text):
            c = text[i]
            if c in ("'", '"'):
                i = skip_str(i)
                continue
            if c == "/" and i + 1 < len(text) and text[i + 1] == "/":
                i = skip_line_comment(i + 2)
                continue
            if c == "/" and i + 1 < len(text) and text[i + 1] == "*":
                i = skip_block_comment(i)
                continue
            if c == open_c:
                depth += 1
            elif c == close_c:
                depth -= 1
                if depth == 0:
                    return i + 1
            i += 1
        return i
    while i < len(text) and text[i] not in ",}\n":
        i += 1
    return i

def find_hooks_property():
    i = 0
    depth = 0
    while i < len(text):
        c = text[i]
        if c in ("'", '"'):
            i = skip_str(i)
            continue
        if c == "/" and i + 1 < len(text) and text[i + 1] == "/":
            i = skip_line_comment(i + 2)
            continue
        if c == "/" and i + 1 < len(text) and text[i + 1] == "*":
            i = skip_block_comment(i)
            continue
        if c == "{":
            depth += 1
            i += 1
            continue
        if c == "}":
            depth -= 1
            i += 1
            continue
        if depth == 1:
            j = skip_ws(i)
            if j < len(text) and text.startswith("hooks", j):
                k = j + 5
                k = skip_ws(k)
                if k < len(text) and text[k] == ":":
                    value_start = k + 1
                    value_end = skip_value(value_start)
                    end = value_end
                    end_ws = skip_ws(end)
                    if end_ws < len(text) and text[end_ws] == ",":
                        end = end_ws + 1
                    return j, end
        i += 1
    return None

span = find_hooks_property()
if span:
    start, end = span
    updated = text[:start] + new_hooks + "\n" + text[end:]
else:
    close_idx = text.rfind("}")
    if close_idx == -1:
        raise SystemExit("Could not find root object in OpenClaw config.")
    prefix = text[:close_idx].rstrip()
    if not prefix.endswith("{"):
        prefix += ",\n"
    updated = prefix + "  " + new_hooks + "\n}\n"

cfg_path.write_text(updated, encoding="utf-8")
print("OpenClaw hooks block updated.")
PY

  info "Restarting OpenClaw service: $OPENCLAW_SERVICE_NAME"
  if [[ "$OPENCLAW_SERVICE_NAME" == "auto" ]]; then
    if command -v openclaw >/dev/null 2>&1; then
      if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$ACTING_USER" openclaw gateway restart || true
      else
        openclaw gateway restart || true
      fi
    fi
    if [[ -n "${SUDO_USER:-}" ]]; then
      sudo -u "$ACTING_USER" systemctl --user restart openclaw-gateway.service || true
    else
      systemctl --user restart openclaw-gateway.service || true
    fi
  else
    systemctl restart "$OPENCLAW_SERVICE_NAME" || true
    if [[ -n "${SUDO_USER:-}" ]]; then
      sudo -u "$ACTING_USER" systemctl --user restart "$OPENCLAW_SERVICE_NAME" || true
    else
      systemctl --user restart "$OPENCLAW_SERVICE_NAME" || true
    fi
  fi
  sleep 2
  if [[ "$OPENCLAW_SERVICE_NAME" == "auto" ]]; then
    if command -v openclaw >/dev/null 2>&1; then
      if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$ACTING_USER" openclaw gateway status --no-probe >/dev/null || true
      else
        openclaw gateway status --no-probe >/dev/null || true
      fi
    fi
  else
    systemctl status "$OPENCLAW_SERVICE_NAME" --no-pager >/dev/null || true
  fi

  info "Running OpenClaw hook smoke tests..."
  curl -fsS -X POST "http://127.0.0.1:18789${OPENCLAW_HOOKS_PATH}/wake" \
    -H "Authorization: Bearer $HOOK_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"text":"Graph webhook setup smoke test","mode":"now"}' >/dev/null

  curl -fsS -X POST "http://127.0.0.1:18789${OPENCLAW_HOOKS_PATH}/agent" \
    -H "Authorization: Bearer $HOOK_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"message":"Graph webhook setup smoke test","name":"GraphWebhook","wakeMode":"next-heartbeat"}' >/dev/null
  ok "OpenClaw /hooks/wake and /hooks/agent checks passed"
fi

echo "[Step 2] Running bootstrap script..."
bash "$SETUP_SCRIPT" \
  --domain "$DOMAIN" \
  --hook-url "$HOOK_URL" \
  --hook-token "$HOOK_TOKEN" \
  --session-key "$SESSION_KEY" \
  --client-state "$CLIENT_STATE" \
  --repo-root "$REPO_ROOT"

echo "[Step 3] Validating public HTTPS endpoint..."
VALIDATION_TOKEN="probe-$(date +%s)"
VALIDATION_RESULT="$(curl -fsS "https://$DOMAIN$ADAPTER_PATH?validationToken=$VALIDATION_TOKEN")"
if [[ "$VALIDATION_RESULT" != "$VALIDATION_TOKEN" ]]; then
  echo "Validation failed. Expected '$VALIDATION_TOKEN', got '$VALIDATION_RESULT'." >&2
  exit 1
fi
echo "Endpoint validation OK."

echo "[Step 4] Creating Graph subscription..."
CREATE_JSON="$(
  python3 "$SUB_SCRIPT" create \
    --notification-url "https://$DOMAIN$ADAPTER_PATH" \
    --client-state "$CLIENT_STATE" \
    --minutes "$MINUTES"
)"
echo "$CREATE_JSON"

SUBSCRIPTION_ID="$(
  python3 - <<'PY' "$CREATE_JSON"
import json
import sys
body = json.loads(sys.argv[1])
print(body.get("id", ""))
PY
)"

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Could not parse subscription id from create response." >&2
  exit 1
fi
echo "Subscription created: $SUBSCRIPTION_ID"

echo "[Step 5] Persisting subscription id in $ENV_FILE..."
if grep -q '^GRAPH_MAIL_SUBSCRIPTION_ID=' "$ENV_FILE"; then
  sed -i "s|^GRAPH_MAIL_SUBSCRIPTION_ID=.*$|GRAPH_MAIL_SUBSCRIPTION_ID=$SUBSCRIPTION_ID|" "$ENV_FILE"
else
  printf "\nGRAPH_MAIL_SUBSCRIPTION_ID=%s\n" "$SUBSCRIPTION_ID" >> "$ENV_FILE"
fi

systemctl daemon-reload
systemctl restart graph-mail-webhook-adapter
systemctl restart graph-mail-webhook-worker
systemctl restart graph-mail-subscription-renew.service
systemctl restart graph-mail-subscription-renew.timer

echo "Services restarted."

echo "[Step 6] Optional real email test..."
if [[ -n "$TEST_EMAIL" ]]; then
  TEST_SUBJECT="Graph Push E2E $(date +%Y%m%d-%H%M%S)"
  python3 "$SEND_SCRIPT" --to "$TEST_EMAIL" --subject "$TEST_SUBJECT" --body "Graph webhook push end-to-end test."
  echo "Sent test email to: $TEST_EMAIL"
  echo "Subject: $TEST_SUBJECT"
else
  echo "Skipped (no --test-email provided)."
fi

echo
echo "Setup and validation completed. Summary:"
echo "- Domain: https://$DOMAIN$ADAPTER_PATH"
echo "- Client state: $CLIENT_STATE"
echo "- Subscription ID: $SUBSCRIPTION_ID"
echo "- Env file: $ENV_FILE"
if [[ "$CONFIGURE_OPENCLAW_HOOKS" == "true" ]]; then
  echo "- OpenClaw config: $OPENCLAW_CONFIG"
  echo "- OpenClaw service: $OPENCLAW_SERVICE_NAME"
fi
echo
echo "Useful checks:"
echo "  systemctl status graph-mail-webhook-adapter --no-pager"
echo "  systemctl status graph-mail-webhook-worker --no-pager"
echo "  systemctl status graph-mail-subscription-renew.timer --no-pager"
echo "  python3 \"$SUB_SCRIPT\" status --id \"$SUBSCRIPTION_ID\""
echo
echo "READINESS VERDICT:"
if [[ -n "$TEST_EMAIL" ]]; then
  echo "READY_FOR_PUSH: YES (public endpoint, subscription, services, and real email send tested)"
else
  echo "READY_FOR_PUSH: YES (public endpoint, subscription, and services validated)"
  echo "NOTE: add --test-email for full live delivery check."
fi
