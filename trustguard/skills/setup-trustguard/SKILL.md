---
name: setup-trustguard
description: Set up the TrustGuard AI firewall for Claude Code — install the trustguard-claude-code binary, configure the TrustGuard endpoint and API key, and verify the hooks work. Use when the user installs the TrustGuard plugin, asks to configure TrustGuard, or when trustguard-claude-code is missing from the PATH.
---

# Set up TrustGuard for Claude Code

The TrustGuard plugin gates this agent with hooks that run `trustguard-claude-code hook`
on `UserPromptSubmit`, `PreToolUse` and `PostToolUse`.

**When to use this plugin vs Anthropic Inference Hooks**

| Path | Who |
| --- | --- |
| Anthropic **Inference Hooks** (`/v1/evaluate/claude`) | Claude **Enterprise** orgs (org-level hook in Anthropic) |
| **This plugin** (local lifecycle hooks) | Teams on Claude Code without Enterprise org hooks — same model as Cursor/Codex plugins |

Enterprise orgs can ship one Claude Code collector for the whole company: employees do
**not** need a NeuralTrust account. Walk the user through the steps below.

## 1. Check for MDM (enterprise) first

Look for the managed config file:

- macOS: `/Library/Application Support/TrustGuard/claude-code.json`
- Linux: `/etc/trustguard/claude-code.json`
- Windows: `%ProgramData%\TrustGuard\claude-code.json`

If it exists and contains an `api_key`, setup is already done by IT. Tell the
user their org firewall is managed — they cannot (and should not) override
`api_key`, `data_url` or `fail_mode`. Skip to step 3 (verify). Soft prefs such
as `transform_action` or `timeout_ms` can still live in `~/.trustguard/claude-code.json`.

## 2. Install the binary (if needed)

On macOS/Linux this is usually automatic: the bootstrap hook downloads the
pinned release into `~/.trustguard/bin` (SHA-256 verified) on the first event.
Check whether a binary is already available:

```bash
trustguard-claude-code version || ls ~/.trustguard/bin/
```

Install manually only if both are missing:

- **From a release**: download the binary for the user's OS/arch from
  https://github.com/NeuralTrust/trustguard-claude-code-plugin/releases and place
  it on the PATH (e.g. `/usr/local/bin/trustguard-claude-code`, `chmod +x`).
- **From source** (requires Go): in a clone of this repo run `make build`,
  then copy `bin/trustguard-claude-code` onto the PATH.

For local plugin testing from a clone:

```bash
make install-local
claude --plugin-dir ./trustguard
```

## 3. Configure the connection (BYO / non-MDM only)

Only when step 1 found no managed key.

### Preferred: plugin enable prompt (`userConfig`)

When the user enables **trustguard** (org Plugins marketplace or
`/plugin install`), Claude Code should prompt for:

1. **TrustGuard data URL** — data-plane base URL  
2. **TrustGuard collector API key** — `tgk_…` (sensitive; keychain)  
3. **Fail mode** — `open` / `closed`  
4. **TrustGate MCP URL** — optional  
5. **TrustGate MCP API key** — optional (not `tgk_…`)  
6. **TrustGate gateway slug** — optional hybrid only  

If they already installed without filling these, re-open plugin settings /
re-enable the plugin, or set options via CLI:

```bash
claude plugin enable trustguard@neuraltrust \
  --config trustguard_data_url=https://… \
  --config trustguard_api_key=tgk_… \
  --config trustgate_mcp_url=https://…/mcp
```

Do **not** ask them to paste secrets into the chat.

### Fallback: config file

```json
{
  "data_url": "https://<trustguard-data-plane>",
  "api_key": "tgk_REPLACE_ME",
  "fail_mode": "closed"
}
```

Path: `~/.trustguard/claude-code.json`, `chmod 600`.

## 4. Verify

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hello"},"session_id":"sess_test"}' \
  | trustguard-claude-code hook
```

Empty `{}` or no `permissionDecision` means allow. A deny prints
`hookSpecificOutput.permissionDecision: "deny"`.

In Claude Code, run `/hooks` and confirm TrustGuard entries under
`UserPromptSubmit`, `PreToolUse`, and `PostToolUse`.

## Config reference

| Field | Env | Default |
| --- | --- | --- |
| `data_url` | `TRUSTGUARD_DATA_URL` | `http://localhost:8081` |
| `api_key` | `TRUSTGUARD_API_KEY` | (required) |
| `fail_mode` | `TRUSTGUARD_FAIL_MODE` | `open` |
| `transform_action` | `TRUSTGUARD_TRANSFORM_ACTION` | `ask` |
| `timeout_ms` | `TRUSTGUARD_TIMEOUT_MS` | `5000` |
| `consumer_id` | `TRUSTGUARD_CONSUMER_ID` | OS user, prefixed `claude-code:` |
