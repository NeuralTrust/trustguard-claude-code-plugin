# Kandji — TrustGuard for Claude Code

MDM rollout for **macOS** (Kandji). Installs the hook binary and the **managed
collector config** so every Mac uses the org `tgk_…` without developers pasting
keys into Claude.

| Delivers | Does **not** deliver |
| --- | --- |
| Binary `trustguard-claude-code` | Claude org **plugin** enable (do that in claude.ai → Plugins) |
| Managed config with collector key | TrustGate MCP connector (optional, separate) |

## Prerequisites

1. TrustGuard → create a **Claude Code / IDE** collector → mint `tgk_…`.
2. Note the data-plane base URL (no `/v1/evaluate`).
3. Publish a GitHub **release** of this repo (or stage the binary another way).
4. Claude org: marketplace `NeuralTrust/trustguard-claude-code-plugin` + enable
   **trustguard** for the team (hooks only work if the plugin is on).

## What gets installed

| Path | Content |
| --- | --- |
| `/Library/Application Support/TrustGuard/claude-code.json` | Managed config (`api_key` locked) |
| `/Library/Application Support/TrustGuard/bin/trustguard-claude-code` | Hook binary |
| `/usr/local/bin/trustguard-claude-code` | Symlink when `/usr/local/bin` exists |

The binary reads the managed file first; developers cannot override
`api_key` / `data_url` / `fail_mode` via `~/.trustguard/claude-code.json` or env.

## Kandji Library Item

### Option A — single install script (simplest)

1. [Kandji](https://web.kandji.io) → **Library** → **Add Library Item** → **Custom Script**
2. **General**
   - Name: `TrustGuard Claude Code`
   - Execution frequency: **Once** (or **Every Day** to repair drift)
   - Restart: **No**
3. **Script**: paste [`install-trustguard-claude-code.sh`](./install-trustguard-claude-code.sh)
4. **Before save**, set credentials in the CONFIG block at the top of the script:

```bash
: "${TRUSTGUARD_DATA_URL:=https://your-data-plane.example}"
: "${TRUSTGUARD_API_KEY:=tgk_…}"
: "${TRUSTGUARD_FAIL_MODE:=closed}"
# Optional pin:
# : "${TRUSTGUARD_CLAUDE_CODE_VERSION:=0.1.2}"
# : "${TRUSTGUARD_BINARY_SHA256:=…}"
```

5. **Assignment** → Blueprint(s) with developer Macs  
6. **Save**

Kandji runs Custom Scripts as **root** — required for `/Library/Application Support`.

### Option B — Audit + Remediation

| Field | File |
| --- | --- |
| **Audit Script** | [`audit-trustguard-claude-code.sh`](./audit-trustguard-claude-code.sh) |
| **Remediation Script** | [`install-trustguard-claude-code.sh`](./install-trustguard-claude-code.sh) (with CONFIG filled) |

- Audit exit `0` → compliant, skip remediation  
- Audit exit `≠ 0` → run install  

Frequency: **Every Day** is enough.

### Option C — key outside the script body

1. Deploy a root-owned env file (File drop / another script), mode `0600`:

```
/Library/Managed Preferences/ai.neuraltrust.trustguard-claude-code.env
```

Contents: see [`secrets.env.example`](./secrets.env.example).

2. Leave `REPLACE_ME` in the install script; it loads that file automatically.

## Optional: stage binary without GitHub

If Macs cannot reach GitHub:

1. Build: `make dist VERSION=0.1.2`
2. Host `trustguard-claude-code_0.1.2_darwin_arm64` (and amd64) on an internal URL,
   set `TRUSTGUARD_DOWNLOAD_BASE`, **or**
3. Drop the binary on the Mac and set:

```bash
: "${TRUSTGUARD_LOCAL_BINARY:=/path/to/trustguard-claude-code}"
```

## Verify on a Mac

```bash
# As any user
/Library/Application\ Support/TrustGuard/bin/trustguard-claude-code version

cat /Library/Application\ Support/TrustGuard/claude-code.json
# should show data_url + api_key (org key)

echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"mdm"}' \
  | trustguard-claude-code hook
# no "TRUSTGUARD_API_KEY missing"; empty {} or deny JSON
```

In Claude: **Plugins → Trustguard → Hooks** must list Prompt submit / Pre / Post.
Activity in TrustGuard should show `source.application=claude-code-plugin`.

## Claude plugin (not Kandji)

Kandji does **not** install the Claude plugin. Org admin:

1. claude.ai → org **Plugins** → marketplace synced  
2. Enable **trustguard** for the team  

Without the plugin, the binary sits idle (no hooks fire).

## TrustGate MCP (optional)

The plugin's TrustGate connector reads `TRUSTGATE_MCP_URL` /
`TRUSTGATE_MCP_API_KEY` from the environment. To roll it out org-wide, deploy a
managed settings file at
`/Library/Application Support/ClaudeCode/managed-settings.json`:

```json
{
  "env": {
    "TRUSTGATE_MCP_URL": "https://HOST/SLUG/mcp"
  }
}
```

Per-user API keys go in each user's `~/.claude/settings.json` `env` block.
Do not put `tgk_…` there (consumer MCP key only).

## Uninstall (manual)

```bash
sudo rm -f \
  "/Library/Application Support/TrustGuard/claude-code.json" \
  "/Library/Application Support/TrustGuard/bin/trustguard-claude-code" \
  /usr/local/bin/trustguard-claude-code
```

## Security notes

- Managed config is `0644 root:wheel` so the user-session hook process can read
  it (same pattern as other MDM app configs). Protect the Mac with FileVault +
  Kandji lock screen; rotate `tgk_…` if a device is lost.
- Prefer Option C (secrets file) if your policy forbids collector keys in the
  Kandji script library text.
- Never put Inference Hook `whsec_…` in this config.
