#!/bin/bash
# TrustGuard for Claude Code — Kandji Custom Script (macOS, runs as root).
#
# Installs:
#   1. Managed collector config  → /Library/Application Support/TrustGuard/claude-code.json
#   2. Hook binary               → /Library/Application Support/TrustGuard/bin/trustguard-claude-code
#                                  (+ symlink /usr/local/bin/trustguard-claude-code when writable)
#
# Kandji: Library → Add Library Item → Custom Script
#   - Execution frequency: Once (or Every Day for drift repair)
#   - Script: paste this file (after filling the CONFIG block below)
#   - Assignment: Blueprint(s) with Claude Code users
#
# Ships collector credentials + binary. Optionally also writes Claude Code
# managed-settings.json (plugin enable only). TrustGate MCP = Org Connectors.
# See mdm/kandji/README.md and mdm/claude/README.md.
#
# Exit codes: 0 success | 1 misconfiguration | 2 install failure
set -euo pipefail

# =============================================================================
# CONFIG — set in Kandji before assign (or inject via env / secrets file)
# =============================================================================

# TrustGuard data-plane base URL (no trailing slash, no /v1/evaluate).
: "${TRUSTGUARD_DATA_URL:=https://REPLACE_ME_DATA_PLANE}"

# Org Claude Code / IDE collector API key (tgk_…). NOT whsec_… / NOT TrustGate MCP key.
: "${TRUSTGUARD_API_KEY:=tgk_REPLACE_ME}"

# open | closed — closed denies when TrustGuard is unreachable.
: "${TRUSTGUARD_FAIL_MODE:=closed}"

# Optional: pin a release. Empty = latest from GitHub API (or LOCAL_BINARY).
: "${TRUSTGUARD_CLAUDE_CODE_VERSION:=}"

# Optional: full path to a pre-staged binary (skip download). Useful with Kandji
# Auto Apps / file drop before this script runs.
: "${TRUSTGUARD_LOCAL_BINARY:=}"

# Optional: expected SHA-256 of the downloaded binary (empty = skip verify).
: "${TRUSTGUARD_BINARY_SHA256:=}"

# GitHub release base (override for mirrors / private caches).
: "${TRUSTGUARD_DOWNLOAD_BASE:=https://github.com/NeuralTrust/trustguard-claude-code-plugin/releases/download}"

# Optional secrets file (0600, root-owned). Lines: KEY=value
# Deploy separately if you do not want the API key in the Kandji script body.
: "${TRUSTGUARD_SECRETS_FILE:=/Library/Managed Preferences/ai.neuraltrust.trustguard-claude-code.env}"

# --- Claude Code managed settings (plugin enable only; MCP is Org Connectors) ---
# Set TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS=1 to write
# /Library/Application Support/ClaudeCode/managed-settings.json (hooks plugin).
# TrustGate MCP stays on claude.ai Organization → Connectors (all products).
: "${TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS:=0}"
: "${TRUSTGUARD_MARKETPLACE_REPO:=NeuralTrust/trustguard-claude-code-plugin}"
: "${TRUSTGUARD_PLUGIN_ID:=trustguard@neuraltrust}"
: "${TRUSTGUARD_MARKETPLACE_NAME:=neuraltrust}"

# =============================================================================
# Paths (must match cli/config.go systemConfigPath on darwin)
# =============================================================================

SUPPORT_DIR="/Library/Application Support/TrustGuard"
BIN_DIR="${SUPPORT_DIR}/bin"
CONFIG_PATH="${SUPPORT_DIR}/claude-code.json"
BIN_NAME="trustguard-claude-code"
BIN_PATH="${BIN_DIR}/${BIN_NAME}"
USR_LOCAL_BIN="/usr/local/bin/${BIN_NAME}"
CLAUDE_SUPPORT_DIR="/Library/Application Support/ClaudeCode"
CLAUDE_MANAGED_SETTINGS="${CLAUDE_SUPPORT_DIR}/managed-settings.json"
LOG_PREFIX="trustguard-claude-code-kandji"

log()  { echo "${LOG_PREFIX}: $*"; }
err()  { echo "${LOG_PREFIX}: ERROR: $*" >&2; }
die()  { err "$1"; exit "${2:-1}"; }

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    die "must run as root (Kandji Custom Scripts run as root)" 1
  fi
}

load_secrets_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  log "loading secrets from $f"
  # shellcheck disable=SC1090
  set -a
  # Only KEY=value lines; ignore comments/blank.
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    if [[ "$line" =~ ^((TRUSTGUARD|TRUSTGATE)_[A-Z0-9_]+)=(.*)$ ]]; then
      export "${BASH_REMATCH[1]}=${BASH_REMATCH[3]}"
    fi
  done <"$f"
  set +a
  : "${TRUSTGUARD_DATA_URL:=${TRUSTGUARD_DATA_URL}}"
  : "${TRUSTGUARD_API_KEY:=${TRUSTGUARD_API_KEY}}"
  : "${TRUSTGUARD_FAIL_MODE:=${TRUSTGUARD_FAIL_MODE}}"
}

validate_config() {
  if [[ -z "${TRUSTGUARD_DATA_URL}" || "${TRUSTGUARD_DATA_URL}" == *REPLACE_ME* ]]; then
    die "TRUSTGUARD_DATA_URL is unset or still REPLACE_ME" 1
  fi
  if [[ -z "${TRUSTGUARD_API_KEY}" || "${TRUSTGUARD_API_KEY}" == *REPLACE_ME* ]]; then
    die "TRUSTGUARD_API_KEY is unset or still REPLACE_ME" 1
  fi
  if [[ "${TRUSTGUARD_API_KEY}" == whsec_* ]]; then
    die "TRUSTGUARD_API_KEY looks like an Inference Hook secret (whsec_). Use a collector tgk_… key." 1
  fi
  if [[ "${TRUSTGUARD_API_KEY}" != tgk_* ]]; then
    log "WARNING: api_key does not start with tgk_ — continuing anyway"
  fi
  case "${TRUSTGUARD_FAIL_MODE}" in
    open|closed) ;;
    *) die "TRUSTGUARD_FAIL_MODE must be open or closed (got ${TRUSTGUARD_FAIL_MODE})" 1 ;;
  esac
  # Strip trailing slash and accidental /v1/evaluate
  TRUSTGUARD_DATA_URL="${TRUSTGUARD_DATA_URL%/}"
  TRUSTGUARD_DATA_URL="${TRUSTGUARD_DATA_URL%/v1/evaluate}"
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64)  echo "amd64" ;;
    *) die "unsupported arch $(uname -m)" 2 ;;
  esac
}

resolve_version() {
  if [[ -n "${TRUSTGUARD_CLAUDE_CODE_VERSION}" ]]; then
    echo "${TRUSTGUARD_CLAUDE_CODE_VERSION}"
    return
  fi
  if [[ -n "${TRUSTGUARD_LOCAL_BINARY}" ]]; then
    echo "local"
    return
  fi
  # Latest tag from GitHub (v0.1.2 → 0.1.2). Prefer pinning TRUSTGUARD_CLAUDE_CODE_VERSION.
  local tag body code
  body="$(mktemp "${TMPDIR:-/tmp}/tg-release.XXXXXX")"
  code="$(curl -sS -o "$body" -w '%{http_code}' --connect-timeout 10 --max-time 60 \
    -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/NeuralTrust/trustguard-claude-code-plugin/releases/latest" || true)"
  if [[ "$code" == "200" ]]; then
    tag="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("tag_name",""))' "$body" 2>/dev/null || true)"
  fi
  rm -f "$body"
  tag="${tag#v}"
  if [[ -z "$tag" ]]; then
    die "could not resolve latest release (HTTP ${code:-?}). Publish a GitHub Release, or set TRUSTGUARD_CLAUDE_CODE_VERSION=0.1.13 / TRUSTGUARD_LOCAL_BINARY" 2
  fi
  echo "$tag"
}

install_binary() {
  mkdir -p "${BIN_DIR}"
  chmod 755 "${SUPPORT_DIR}" "${BIN_DIR}"

  if [[ -n "${TRUSTGUARD_LOCAL_BINARY}" ]]; then
    [[ -f "${TRUSTGUARD_LOCAL_BINARY}" ]] || die "TRUSTGUARD_LOCAL_BINARY not found: ${TRUSTGUARD_LOCAL_BINARY}" 2
    log "installing binary from ${TRUSTGUARD_LOCAL_BINARY}"
    cp "${TRUSTGUARD_LOCAL_BINARY}" "${BIN_PATH}.new"
  else
    local version arch url tmp
    version="$(resolve_version)"
    arch="$(detect_arch)"
    url="${TRUSTGUARD_DOWNLOAD_BASE}/v${version}/trustguard-claude-code_${version}_darwin_${arch}"
    tmp="$(mktemp "${TMPDIR:-/tmp}/tg-claude-code.XXXXXX")"
    log "downloading ${url}"
    if ! curl -fsSL --connect-timeout 15 --max-time 300 -o "$tmp" "$url"; then
      rm -f "$tmp"
      die "download failed: ${url}" 2
    fi
    if [[ -n "${TRUSTGUARD_BINARY_SHA256}" ]]; then
      local got
      got="$(shasum -a 256 "$tmp" | awk '{print $1}')"
      if [[ "${got}" != "${TRUSTGUARD_BINARY_SHA256}" ]]; then
        rm -f "$tmp"
        die "SHA-256 mismatch (got ${got}, want ${TRUSTGUARD_BINARY_SHA256})" 2
      fi
      log "checksum ok"
    fi
    mv "$tmp" "${BIN_PATH}.new"
  fi

  chmod 755 "${BIN_PATH}.new"
  # Quick smoke: must run version
  if ! "${BIN_PATH}.new" version >/dev/null 2>&1; then
    rm -f "${BIN_PATH}.new"
    die "binary failed 'version' smoke test" 2
  fi
  mv -f "${BIN_PATH}.new" "${BIN_PATH}"
  log "installed ${BIN_PATH} ($("${BIN_PATH}" version 2>/dev/null || echo '?'))"

  # Symlink for PATH if /usr/local/bin exists (common on macOS)
  if [[ -d /usr/local/bin ]]; then
    ln -sfn "${BIN_PATH}" "${USR_LOCAL_BIN}"
    log "linked ${USR_LOCAL_BIN}"
  fi
}

write_managed_config() {
  mkdir -p "${SUPPORT_DIR}"
  chmod 755 "${SUPPORT_DIR}"

  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/tg-claude-code-cfg.XXXXXX")"
  /usr/bin/python3 - "$tmp" <<'PY'
import json, os, sys
path = sys.argv[1]
cfg = {
    "data_url": os.environ["TRUSTGUARD_DATA_URL"].rstrip("/"),
    "api_key": os.environ["TRUSTGUARD_API_KEY"],
    "fail_mode": os.environ.get("TRUSTGUARD_FAIL_MODE", "closed"),
}
# Optional soft fields if set in environment
for src, key in (
    ("TRUSTGUARD_TIMEOUT_MS", "timeout_ms"),
    ("TRUSTGUARD_TRANSFORM_ACTION", "transform_action"),
    ("TRUSTGUARD_CONSUMER_ID", "consumer_id"),
):
    v = os.environ.get(src, "").strip()
    if not v:
        continue
    if key == "timeout_ms":
        try:
            cfg[key] = int(v)
        except ValueError:
            pass
    else:
        cfg[key] = v
with open(path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
  # root-only read; binary runs as the user but system path is world-readable
  # by design (same as other MDM-managed app configs). Restrict to root:wheel
  # 644 so every developer session can read the org key without sudo.
  install -m 0644 -o root -g wheel "$tmp" "${CONFIG_PATH}"
  rm -f "$tmp"
  log "wrote managed config ${CONFIG_PATH} (api_key locked for developers)"
}

write_claude_managed_settings() {
  case "${TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS}" in
    1|true|TRUE|yes|YES) ;;
    *)
      log "skip Claude managed-settings (set TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS=1 to deploy)"
      return 0
      ;;
  esac

  mkdir -p "${CLAUDE_SUPPORT_DIR}"
  chmod 755 "${CLAUDE_SUPPORT_DIR}"

  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/tg-claude-managed.XXXXXX")"
  export TRUSTGUARD_MARKETPLACE_REPO TRUSTGUARD_PLUGIN_ID TRUSTGUARD_MARKETPLACE_NAME
  /usr/bin/python3 - "$tmp" <<'PY'
import json, os, sys
path = sys.argv[1]
marketplace = os.environ["TRUSTGUARD_MARKETPLACE_NAME"]
plugin_id = os.environ["TRUSTGUARD_PLUGIN_ID"]
repo = os.environ["TRUSTGUARD_MARKETPLACE_REPO"]
# Hooks plugin only. TrustGate MCP is org Connectors (all Claude products).
doc = {
    "extraKnownMarketplaces": {
        marketplace: {
            "source": {"source": "github", "repo": repo},
            "autoUpdate": True,
        }
    },
    "enabledPlugins": {plugin_id: True},
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
  install -m 0644 -o root -g wheel "$tmp" "${CLAUDE_MANAGED_SETTINGS}"
  rm -f "$tmp"
  log "wrote Claude managed settings ${CLAUDE_MANAGED_SETTINGS} (plugin enable; MCP via Org Connectors)"
}

verify() {
  [[ -x "${BIN_PATH}" ]] || die "binary missing after install" 2
  [[ -f "${CONFIG_PATH}" ]] || die "config missing after install" 2
  # Evaluate path without calling the network: ensure config is valid JSON
  /usr/bin/python3 -c "import json; json.load(open('${CONFIG_PATH}'))" \
    || die "config is not valid JSON" 2
  case "${TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS}" in
    1|true|TRUE|yes|YES)
      [[ -f "${CLAUDE_MANAGED_SETTINGS}" ]] || die "Claude managed-settings missing" 2
      /usr/bin/python3 -c "import json; json.load(open('${CLAUDE_MANAGED_SETTINGS}'))" \
        || die "Claude managed-settings is not valid JSON" 2
      ;;
  esac
  log "verify ok — binary=$("${BIN_PATH}" version) config=${CONFIG_PATH}"
}

main() {
  require_root
  load_secrets_file "${TRUSTGUARD_SECRETS_FILE}"
  # Re-export after secrets file may have set them
  export TRUSTGUARD_DATA_URL TRUSTGUARD_API_KEY TRUSTGUARD_FAIL_MODE
  export TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS
  export TRUSTGUARD_MARKETPLACE_REPO TRUSTGUARD_PLUGIN_ID TRUSTGUARD_MARKETPLACE_NAME
  validate_config
  install_binary
  write_managed_config
  write_claude_managed_settings
  verify
  log "done. Hooks use managed collector key; Claude managed-settings force plugin when enabled. TrustGate MCP = Org Connectors."
}

main "$@"
