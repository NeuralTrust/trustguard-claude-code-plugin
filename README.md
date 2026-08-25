# TrustGuard for Claude Code

AI firewall for [Claude Code](https://code.claude.com) via **lifecycle hooks**.
One org collector — developers are protected without a NeuralTrust account.

Same model as the [Cursor](https://github.com/NeuralTrust/trustguard-cursor-plugin)
and [Codex](https://github.com/NeuralTrust/trustguard-codex-plugin) plugins:
local hooks call `trustguard-claude-code` → TrustGuard `POST /v1/evaluate`.

> **Claude Enterprise Inference Hooks** (`/v1/evaluate/claude`) are a separate
> path. This plugin is for teams **without** org-level Inference Hooks.

## Where does the collector API key go?

**Not in the Claude Plugins UI.** The plugin detail screen only shows Skills /
Connectors / Hooks. There is no field there for `tgk_…`.

Put the key in a local file the hook binary reads:

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

| Secret | Where |
| --- | --- |
| TrustGuard collector `tgk_…` | `~/.trustguard/claude-code.json` (or MDM / env) |
| TrustGate MCP URL + consumer key | Claude **Connectors** (real `https://…` URL) — not this file |

Create a **Claude Code / IDE** collector in TrustGuard. Do not reuse Inference
Hook secrets (`whsec_…`).

### Env / MDM

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

**Kandji (macOS):** Custom Script — [`mdm/kandji/README.md`](./mdm/kandji/README.md).

## Install (org Plugins)

1. Org admin adds marketplace `NeuralTrust/trustguard-claude-code-plugin` and
   enables **trustguard** for the team.
2. Each machine: write `~/.trustguard/claude-code.json` (above) and ensure
   `trustguard-claude-code` is on PATH or in `~/.trustguard/bin`
   (`make install-local` from this repo).
3. Confirm **Plugins → Trustguard → Hooks** lists Prompt submit, Pre-tool use,
   Post-tool use.

Local load without marketplace:

```bash
make install-local
claude --plugin-dir ./trustguard
```

## TrustGate MCP (bundled) — plugin `userConfig`

The plugin declares the MCP URL in `userConfig` and substitutes it into the
bundled HTTP server with `${user_config.trustgate_mcp_url}` (Claude Code
plugins-reference pattern for `url` / `headers` on `http` servers).

```json
"userConfig": {
  "trustgate_mcp_url": { "type": "string", "title": "TrustGate MCP URL", "required": true },
  "trustgate_mcp_api_key": { "type": "string", "sensitive": true, "required": false, "default": "" },
  "trustgate_gateway_slug": { "type": "string", "required": false, "default": "" }
},
"mcpServers": {
  "TrustGate": {
    "type": "http",
    "url": "${user_config.trustgate_mcp_url}",
    "headers": {
      "X-AG-API-Key": "${user_config.trustgate_mcp_api_key}",
      "X-AG-Gateway-Slug": "${user_config.trustgate_gateway_slug}"
    }
  }
}
```

**How to set the values**

1. **On enable** — Claude Code prompts for the fields when you enable the plugin.
2. **CLI** (non-interactive):

```bash
claude plugin install trustguard@neuraltrust \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp \
  --config trustgate_mcp_api_key=YOUR_CONSUMER_KEY
```

3. **Already installed** — `/plugin` → Installed → **trustguard** → configure
   options, then `/reload-plugins`.

Do **not** paste the URL into the generic “Add custom connector” dialog; that
is not the `userConfig` form and often shows the unresolved placeholder.

Verify with `/mcp`: **TrustGate** should be connected. MCP key = TrustGate
**consumer** key, never the TrustGuard `tgk_…`.

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
