# TrustGuard for Claude Code

AI firewall for [Claude Code](https://code.claude.com) via **lifecycle hooks**.
One org collector — developers are protected without a NeuralTrust account.

Same model as the [Cursor](https://github.com/NeuralTrust/trustguard-cursor-plugin)
and [Codex](https://github.com/NeuralTrust/trustguard-codex-plugin) plugins:
local hooks call `trustguard-claude-code` → TrustGuard `POST /v1/evaluate`.

> **Claude Enterprise Inference Hooks** (`/v1/evaluate/claude`) are a separate
> path. This plugin is for teams **without** org-level Inference Hooks.

## Credentials (two secrets, two places)

| Secret | Where |
| --- | --- |
| TrustGuard collector `tgk_…` (hooks) | `~/.trustguard/claude-code.json`, env, or MDM — **not** the Plugins UI |
| TrustGate MCP URL | Plugin `userConfig` at install/enable — **not** “Add custom connector” |

Create a **Claude Code / IDE** collector in TrustGuard. Do not reuse Inference
Hook secrets (`whsec_…`).

### Collector key (hooks)

```bash
mkdir -p ~/.trustguard && chmod 700 ~/.trustguard
cat > ~/.trustguard/claude-code.json <<'EOF'
{
  "data_url": "https://<trustguard-data-plane>",
  "api_key": "tgk_…",
  "fail_mode": "closed"
}
EOF
chmod 600 ~/.trustguard/claude-code.json
```

Or env / MDM:

```bash
export TRUSTGUARD_DATA_URL="https://…"
export TRUSTGUARD_API_KEY="tgk_…"
export TRUSTGUARD_FAIL_MODE="closed"
```

| OS | Managed config (locks key / URL / fail_mode) |
| --- | --- |
| macOS | `/Library/Application Support/TrustGuard/claude-code.json` |
| Linux | `/etc/trustguard/claude-code.json` |
| Windows | `%ProgramData%\TrustGuard\claude-code.json` |

**Kandji (macOS):** [`mdm/kandji/README.md`](./mdm/kandji/README.md).

## Install the plugin (correct path)

The bundled TrustGate MCP server uses `${user_config.trustgate_mcp_url}`.
Claude Code only substitutes that when the plugin is installed/enabled through
the **plugin** flow. Do **not** open “Add custom connector” and paste the
placeholder — that dialog is a different surface; the URL field stays locked
with the literal `${user_config…}` string.

### Per user (interactive)

1. Marketplace: add `NeuralTrust/trustguard-claude-code-plugin` (marketplace
   name `neuraltrust`) if needed.
2. Install and enable:

```text
/plugin install trustguard@neuraltrust
```

Or CLI:

```bash
claude plugin install trustguard@neuraltrust \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp
```

Claude Code detects `userConfig` and prompts for **TrustGate MCP URL** on
enable (unless you passed `--config`). Auth is **OAuth** against that URL —
no API key field.

3. Write the collector key file (above) on the machine.
4. Confirm **Plugins → Trustguard → Hooks** lists Prompt submit / Pre / Post.
5. `/mcp` → complete OAuth for TrustGate if prompted → tools appear.

Local dogfood without marketplace:

```bash
make install-local
claude --plugin-dir ./trustguard
# or: /plugin install /path/to/trustguard-claude-code-plugin/trustguard
```

### Org-wide (managed settings — recommended)

Force the plugin on and pre-fill the MCP URL so users are not prompted. Deploy
via MDM or claude.ai admin as
[managed settings](https://code.claude.com/docs/en/managed-settings):

```json
{
  "enabledPlugins": {
    "trustguard@neuraltrust": true
  },
  "extraKnownMarketplaces": {
    "neuraltrust": {
      "source": {
        "source": "github",
        "repo": "NeuralTrust/trustguard-claude-code-plugin"
      }
    }
  },
  "pluginConfigs": {
    "trustguard@neuraltrust": {
      "options": {
        "trustgate_mcp_url": "https://HOST/CONSUMER-SLUG/mcp"
      }
    }
  }
}
```

Notes:

- Plugin ID is `trustguard@neuraltrust` (plugin@marketplace).
- `pluginConfigs` values live under **`options`** (settings-reference shape).
- Scope is **user or managed** only — project `.claude/settings.json` is
  ignored for `pluginConfigs` (security).
- Collector `tgk_…` stays in Kandji/managed TrustGuard JSON, not here.

### Project scope (repo)

```bash
claude plugin install trustguard@neuraltrust --scope project \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp
```

Writes `enabledPlugins` into the repo’s `.claude/settings.json`. Still set
`pluginConfigs` in user/managed settings for the URL (project cannot supply it).

## TrustGate MCP (URL only, OAuth)

```json
"userConfig": {
  "trustgate_mcp_url": {
    "type": "string",
    "title": "TrustGate MCP URL",
    "required": true
  }
},
"mcpServers": {
  "TrustGate": {
    "type": "http",
    "url": "${user_config.trustgate_mcp_url}"
  }
}
```

If you already “added” TrustGate as a custom connector with the placeholder
string, remove that connector and reinstall the plugin so `userConfig` runs.

## Event → evaluation mapping

| Claude Code event | Protocol | Direction | On block |
| --- | --- | --- | --- |
| `UserPromptSubmit` | `llm` | input | `decision: "block"` |
| `PreToolUse` (`Bash`) | `all` | input | `permissionDecision: "deny"` |
| `PreToolUse` (other / MCP tools) | `mcp` tools/call | input | same deny |
| `PostToolUse` | `mcp` result | output | `decision: "block"` + untrusted guidance |

Stamps: `collector.type=ide`, `source.application=claude-code-plugin`,
`consumer_id` prefixed `claude-code:`.

## Layout

| Path | Role |
| --- | --- |
| `trustguard/` | Plugin (manifest, hooks, skill) |
| `.claude-plugin/marketplace.json` | Org marketplace catalog |
| `cli/` | `trustguard-claude-code` binary |

```bash
make build && make test && make install-local
```

## Verify

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"s1"}' \
  | ./bin/trustguard-claude-code hook
```

## License

Apache-2.0 — see [`LICENSE`](./LICENSE).
