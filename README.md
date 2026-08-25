# TrustGuard for Claude Code

AI firewall for [Claude Code](https://code.claude.com) via **lifecycle hooks**,
plus a bundled **TrustGate MCP** connector (URL + OAuth).

Same model as the [Cursor](https://github.com/NeuralTrust/trustguard-cursor-plugin)
and [Codex](https://github.com/NeuralTrust/trustguard-codex-plugin) plugins:
local hooks call `trustguard-claude-code` → TrustGuard `POST /v1/evaluate`.

> **Claude Enterprise Inference Hooks** (`/v1/evaluate/claude`) are a separate
> path. This plugin is for teams **without** org-level Inference Hooks (or in
> addition to them, with `source.application=claude-code-plugin` gates).

## Org-wide install (managed) — primary path

**TrustGate MCP is for Claude broadly** (claude.ai, Desktop, Cowork), not only
Claude Code. The plugin adds **hooks** (and an optional MCP bind) for Code.
Full detail: **[docs/enterprise.md](./docs/enterprise.md)**.

| Piece | Surfaces | How |
| --- | --- | --- |
| **TrustGate MCP** | claude.ai, Desktop, Cowork, Code | Owner → **Organization settings → Connectors** (remote MCP URL + OAuth) |
| **Plugin** | Claude Code only | Managed settings: enable `trustguard@neuraltrust` |
| **Collector + binary** | Claude Code hooks only | Kandji [`mdm/kandji/`](./mdm/kandji/) |

### 1. TrustGate for the Claude org (all products)

Owner:

1. **Organization settings → Connectors → Add → Custom → Web**
2. URL = TrustGate Connect MCP endpoint `https://HOST/CONSUMER-SLUG/mcp`
3. Members: **Customize → Connectors → Connect** (OAuth once)

Same URL everywhere. No `tgk_…` on the connector.

### 2. Claude Code plugin (hooks)

Server-managed or file
`/Library/Application Support/ClaudeCode/managed-settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "neuraltrust": {
      "source": {
        "source": "github",
        "repo": "NeuralTrust/trustguard-claude-code-plugin"
      },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "trustguard@neuraltrust": true
  }
}
```

Optional: add `pluginConfigs…options.trustgate_mcp_url` with the **same** URL
if Code should bind TrustGate via the plugin instead of (or in addition to)
the org Connector — avoid double-registering the same endpoint. Template:
[`mdm/claude/managed-settings.json`](./mdm/claude/managed-settings.json).

### 3. Collector key + binary (Kandji)

```bash
# mdm/kandji/README.md — installs:
#   /Library/Application Support/TrustGuard/claude-code.json   (tgk_… locked)
#   /Library/Application Support/TrustGuard/bin/trustguard-claude-code
```

Create a **Claude Code / IDE** collector (`tgk_…`). Not Inference Hook `whsec_…`.

### 4. Verify (pilot)

- claude.ai / Desktop: Connectors → TrustGate connected + tools  
- Claude Code: `/status` managed; `claude plugin list` → trustguard; hooks fire  

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"pilot"}' \
  | trustguard-claude-code hook
# TrustGuard: source.application=claude-code-plugin
```

## Credentials map

| Secret | Where |
| --- | --- |
| TrustGate MCP URL | Org **Connectors** (Claude products); optional plugin `pluginConfigs` for Code |
| TrustGuard collector `tgk_…` | Kandji / `~/.trustguard/claude-code.json` — **not** Connectors / Plugins UI |

## Dogfood / single machine (not org)

```bash
make install-local
claude plugin marketplace add NeuralTrust/trustguard-claude-code-plugin
claude plugin install trustguard@neuraltrust \
  --config trustgate_mcp_url=https://HOST/CONSUMER-SLUG/mcp
```

Or `claude --plugin-dir ./trustguard` from a clone.

## Plugin shape (reference)

```json
"userConfig": {
  "trustgate_mcp_url": { "type": "string", "title": "TrustGate MCP URL", "required": true }
},
"mcpServers": {
  "TrustGate": {
    "type": "http",
    "url": "${user_config.trustgate_mcp_url}"
  }
}
```

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
| `.claude-plugin/marketplace.json` | Marketplace catalog (`neuraltrust`) |
| `cli/` | `trustguard-claude-code` binary |
| `mdm/claude/` | Org Claude managed-settings template |
| `mdm/kandji/` | macOS MDM: binary + collector (+ optional Claude settings) |

```bash
make build && make test && make install-local
```

## License

Apache-2.0 — see [`LICENSE`](./LICENSE).
