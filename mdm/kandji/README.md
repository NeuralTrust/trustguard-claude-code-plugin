# Kandji — TrustGuard for Claude Code

MDM rollout for **macOS**. Installs the hook binary and the **managed collector
config**. Optionally writes Claude Code **managed-settings.json** (plugin enable
only). **TrustGate MCP is not installed here** — use claude.ai Organization →
Connectors for all products.

| Delivers | Does **not** deliver |
| --- | --- |
| Binary `trustguard-claude-code` | TrustGate MCP (Org Connectors) |
| Managed collector `tgk_…` | Inference Hook secrets (`whsec_…`) |
| Optional Claude `managed-settings.json` (hooks plugin) | Per-user TrustGate OAuth |

Full org picture: [`docs/enterprise.md`](../../docs/enterprise.md) and
[`mdm/claude/README.md`](../claude/README.md).

## Prerequisites

1. TrustGuard → **Claude Code / IDE** collector → mint `tgk_…` + data-plane URL.
2. TrustGate Connect → org MCP URL (`https://host/slug/mcp`).
3. Feature work merged to `main` — the **Release** workflow tags and uploads
   binaries (or stage offline with `TRUSTGUARD_LOCAL_BINARY`).
4. Pin `TRUSTGUARD_CLAUDE_CODE_VERSION` (e.g. `0.1.13`).
5. **Private GitHub repo (this one):** Macs cannot download release assets
   anonymously (browser URL → **404**). Provide a read-only token:

   | Var | Value |
   | --- | --- |
   | `TRUSTGUARD_GITHUB_TOKEN` | Fine-grained PAT: **Contents: Read** on `NeuralTrust/trustguard-claude-code-plugin` (classic: `repo`) |

   Put the token in the secrets file (Option C), not in git.

   Alternatives: make the repo **public**, host binaries on an internal
   `TRUSTGUARD_DOWNLOAD_BASE`, or stage with `TRUSTGUARD_LOCAL_BINARY`.

## What gets installed

| Path | Content |
| --- | --- |
| `/Library/Application Support/TrustGuard/claude-code.json` | Managed collector config (`api_key` locked) |
| `/Library/Application Support/TrustGuard/bin/trustguard-claude-code` | Hook binary |
| `/usr/local/bin/trustguard-claude-code` | Symlink when `/usr/local/bin` exists |
| `/Library/Application Support/ClaudeCode/managed-settings.json` | **If** `TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS=1` |

## Kandji Library Item

### Option A — single install script (recommended)

1. [Kandji](https://web.kandji.io) → **Library** → **Add Library Item** → **Custom Script**
2. **General**
   - Name: `TrustGuard Claude Code`
   - Execution frequency: **Once** (or **Every Day** to repair drift)
   - Restart: **No**
3. **Script**: paste [`install-trustguard-claude-code.sh`](./install-trustguard-claude-code.sh)
4. **Before save**, set CONFIG at the top of the script (or secrets file):

```bash
: "${TRUSTGUARD_DATA_URL:=https://your-data-plane.example}"
: "${TRUSTGUARD_API_KEY:=tgk_…}"
: "${TRUSTGUARD_FAIL_MODE:=closed}"
: "${TRUSTGUARD_CLAUDE_CODE_VERSION:=0.1.13}"

# Private repo — required or downloads 404:
: "${TRUSTGUARD_GITHUB_TOKEN:=github_pat_…}"

# Optional: force Claude Code hooks plugin (MCP stays on Org Connectors):
# : "${TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS:=1}"
```

5. **Assignment** → Blueprint(s) with developer Macs  
6. **Save**

Kandji runs Custom Scripts as **root** — required for `/Library/Application Support`.

### Option B — Audit + Remediation

| Field | File |
| --- | --- |
| **Audit Script** | [`audit-trustguard-claude-code.sh`](./audit-trustguard-claude-code.sh) |
| **Remediation Script** | [`install-trustguard-claude-code.sh`](./install-trustguard-claude-code.sh) (CONFIG filled) |

To also require Claude managed-settings in the audit:

```bash
: "${TRUSTGUARD_REQUIRE_CLAUDE_MANAGED_SETTINGS:=1}"
```

(in the Audit script env / Kandji variable)

### Option C — key outside the script body

1. Deploy a root-owned env file (File drop), mode `0600`:

```
/Library/Managed Preferences/ai.neuraltrust.trustguard-claude-code.env
```

Contents: see [`secrets.env.example`](./secrets.env.example) (optional
`TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS=1`).

2. Leave `REPLACE_ME` in the install script; it loads that file automatically.

## Network / SSL timeouts to GitHub

`curl: (28) SSL connection timeout` means the **Mac cannot complete TLS to
GitHub** (firewall, proxy, or SSL inspection) — not a bad release.

From a failing Mac:

```bash
curl -vI --connect-timeout 30 \
  "https://github.com/NeuralTrust/trustguard-claude-code-plugin/releases/download/v0.1.13/trustguard-claude-code_0.1.13_darwin_arm64"
```

| Fix | How |
| --- | --- |
| Allowlist | Egress to `github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com` |
| Proxy | Set `HTTPS_PROXY` / `HTTP_PROXY` in the Kandji script env (curl honors them) |
| Mirror | Host the asset on an internal CDN and set `TRUSTGUARD_DOWNLOAD_BASE` |
| Offline | File drop + `TRUSTGUARD_LOCAL_BINARY=/path/to/binary` |
| Retries | Defaults: 5 retries, 60s connect, 600s max (`TRUSTGUARD_CURL_*`) |

## Optional: stage binary without GitHub

1. Build: `make dist VERSION=0.1.13`
2. Host binaries on an internal URL (`TRUSTGUARD_DOWNLOAD_BASE`) **or**
3. Drop the binary and set `TRUSTGUARD_LOCAL_BINARY=/path/to/binary`

## Verify on a Mac

```bash
/Library/Application\ Support/TrustGuard/bin/trustguard-claude-code version
cat /Library/Application\ Support/TrustGuard/claude-code.json

# If Claude managed-settings were deployed (plugin enable only):
cat /Library/Application\ Support/ClaudeCode/managed-settings.json

echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"mdm"}' \
  | trustguard-claude-code hook
```

In Claude Code:

- `/status` → Enterprise managed settings  
- `claude plugin list` → `trustguard@neuraltrust` enabled  
- `/mcp` → TrustGate as **org** connector (not plugin-provided)  
- TrustGuard activity: `source.application=claude-code-plugin`

## Uninstall (manual)

```bash
sudo rm -f \
  "/Library/Application Support/TrustGuard/claude-code.json" \
  "/Library/Application Support/TrustGuard/bin/trustguard-claude-code" \
  /usr/local/bin/trustguard-claude-code \
  "/Library/Application Support/ClaudeCode/managed-settings.json"
```

Only remove Claude managed-settings if this script owns the whole file (no
other org policies in the same JSON). Prefer a drop-in under
`managed-settings.d/` if you merge policies later.

## Security notes

- Managed collector config is `0644 root:wheel` so the user-session hook can
  read it. Protect Macs with FileVault + lock screen; rotate `tgk_…` on loss.
- Prefer Option C (secrets file) if policy forbids keys in the Kandji script body.
- Never put Inference Hook `whsec_…` in the collector config.
- Never put `tgk_…` on Org Connectors or in Claude managed settings.
- TrustGate MCP is only via Org Connectors — not this plugin / Kandji.
