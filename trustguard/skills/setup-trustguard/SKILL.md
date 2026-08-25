---
name: setup-trustguard
description: Configure the TrustGuard collector API key and data URL for the Claude Code plugin hooks. Use when the user enables Trustguard, asks where to put the tgk_ key, or hooks allow without evaluating.
---

# Configure TrustGuard (collector key)

The **collector API key is not in the Claude Plugins UI** (Skills / Connectors / Hooks tabs). Those tabs only show what the plugin ships. Hooks read credentials from a **local config file** (or env / MDM).

TrustGate MCP is separate: add it under **Connectors** with a real `https://…/mcp` URL — not via this plugin.

## 1. Create the config file

```bash
mkdir -p ~/.trustguard
chmod 700 ~/.trustguard
cat > ~/.trustguard/claude-code.json <<'EOF'
{
  "data_url": "https://YOUR_TRUSTGUARD_DATA_PLANE",
  "api_key": "tgk_YOUR_COLLECTOR_KEY",
  "fail_mode": "closed"
}
EOF
chmod 600 ~/.trustguard/claude-code.json
```

| Field | Value |
| --- | --- |
| `data_url` | TrustGuard data-plane base URL (no `/v1/evaluate`) |
| `api_key` | Collector key `tgk_…` from TrustGuard → Claude Code / IDE collector |
| `fail_mode` | `open` (allow if TG down) or `closed` (deny) |

Do **not** use Inference Hook secrets (`whsec_…`) or TrustGate MCP consumer keys here.

## 2. Install the hook binary (if needed)

```bash
trustguard-claude-code version || ls ~/.trustguard/bin/
```

From a clone of the plugin repo: `make install-local`.  
Or wait for the bootstrap script to download a release binary into `~/.trustguard/bin`.

## 3. Verify

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"t1"}' \
  | trustguard-claude-code hook
```

- Missing key → stderr `TRUSTGUARD_API_KEY missing` and `{}` (allow).
- With key → empty allow or `permissionDecision: "deny"` if blocked.

In Claude: Plugins → Trustguard → **Hooks** should list Prompt submit / Pre-tool use / Post-tool use.

## Enterprise (MDM)

IT drops the same JSON (with org `api_key`) at:

- macOS: `/Library/Application Support/TrustGuard/claude-code.json`
- Linux: `/etc/trustguard/claude-code.json`
- Windows: `%ProgramData%\TrustGuard\claude-code.json`

Then developers cannot override key / data URL / fail mode.

## TrustGate MCP Gateway (optional, separate)

1. Claude → **Connectors** (or plugin Connectors → Add)  
2. Name: `TrustGate`  
3. URL: full MCP endpoint from TrustGate Connect, e.g. `https://{host}/{consumer-slug}/mcp`  
4. API key header if needed: consumer key — **not** `tgk_…`

## Env alternatives

```bash
export TRUSTGUARD_DATA_URL="https://…"
export TRUSTGUARD_API_KEY="tgk_…"
export TRUSTGUARD_FAIL_MODE="closed"
```

Priority: MDM file → `~/.trustguard/claude-code.json` → env.
