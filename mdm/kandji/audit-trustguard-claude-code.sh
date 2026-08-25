#!/bin/bash
# TrustGuard for Claude Code — Kandji Audit Script (macOS).
#
# Exit 0  = compliant (binary + managed config present and sane)
# Exit 1  = not compliant → Kandji should run the Remediation (install) script
#
# Pair with install-trustguard-claude-code.sh as:
#   Audit Script      = this file
#   Remediation Script = install-trustguard-claude-code.sh
set -euo pipefail

SUPPORT_DIR="/Library/Application Support/TrustGuard"
CONFIG_PATH="${SUPPORT_DIR}/claude-code.json"
BIN_PATH="${SUPPORT_DIR}/bin/trustguard-claude-code"

if [[ ! -x "${BIN_PATH}" ]]; then
  echo "missing binary: ${BIN_PATH}"
  exit 1
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "missing managed config: ${CONFIG_PATH}"
  exit 1
fi

if ! "${BIN_PATH}" version >/dev/null 2>&1; then
  echo "binary failed version check"
  exit 1
fi

if ! /usr/bin/python3 - <<PY
import json, sys
cfg = json.load(open("${CONFIG_PATH}"))
key = (cfg.get("api_key") or "").strip()
url = (cfg.get("data_url") or "").strip()
if not key or "REPLACE_ME" in key:
    sys.exit(2)
if not url or "REPLACE_ME" in url:
    sys.exit(2)
if key.startswith("whsec_"):
    sys.exit(3)
print("ok", cfg.get("fail_mode", ""), flush=True)
PY
then
  echo "managed config invalid or incomplete"
  exit 1
fi

echo "compliant: $("${BIN_PATH}" version) @ ${CONFIG_PATH}"
exit 0
