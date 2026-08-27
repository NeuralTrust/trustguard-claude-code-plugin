# TrustGuard for Claude Code

AI firewall for [Claude Code](https://code.claude.com) via **lifecycle hooks**.

**TrustGate MCP Gateway** is **not** part of this plugin. It must stay **always
on for the whole Claude org and every product** (claude.ai, Desktop, Cowork,
Claude Code) via **Organization → Connectors**. See
**[docs/enterprise.md](./docs/enterprise.md)**.

Same model as the [Cursor](https://github.com/NeuralTrust/trustguard-cursor-plugin)
and [Codex](https://github.com/NeuralTrust/trustguard-codex-plugin) plugins for
hooks: local binary → TrustGuard `POST /v1/evaluate`.

> **Claude Enterprise Inference Hooks** (`/v1/evaluate/claude`) are a separate
> path. This plugin is for teams **without** org-level Inference Hooks (or in
> addition to them, with `source.application=claude-code-plugin` gates).

## Org-wide install (managed) — primary path

| Piece | Surfaces | How |
| --- | --- | --- |
| **TrustGate MCP** | **All** Claude products | Owner → **Organization settings → Connectors** |
| **Plugin** | Claude Code only (hooks) | Managed settings: enable `trustguard@neuraltrust` |
| **Collector + binary** | Claude Code hooks only | Kandji [`mdm/kandji/`](./mdm/kandji/) |

### 1. TrustGate for the Claude org (all products) — required

Owner:

1. **Organization settings → Connectors → Add → Custom → Web**
2. URL = TrustGate Connect MCP endpoint `https://HOST/CONSUMER-SLUG/mcp`
3. Members: **Customize → Connectors → Connect** (OAuth once per user)

Same URL everywhere. No `tgk_…` on the connector. Do **not** configure MCP
inside this plugin.

### 2. Claude Code plugin (hooks only)

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

Template: [`mdm/claude/managed-settings.json`](./mdm/claude/managed-settings.json).
No `pluginConfigs`.

### 3. Collector key + binary (Kandji)

```bash
# mdm/kandji/README.md — installs:
#   /Library/Application Support/TrustGuard/claude-code.json   (tgk_… locked)
#   /Library/Application Support/TrustGuard/bin/trustguard-claude-code
```

Create a **Claude Code / IDE** collector (`tgk_…`). Not Inference Hook `whsec_…`.

### 4. Verify (pilot)

- Any Claude product: Connectors → TrustGate connected + tools (org connector)
- Claude Code: `/status` managed; `claude plugin list` → trustguard; hooks fire
- Claude Code `/mcp`: TrustGate listed as **org** connector — **not**
  “Provided by the Trustguard plugin”

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"pilot"}' \
  | trustguard-claude-code hook
# TrustGuard: source.application=claude-code-plugin
```

## Credentials map

| Secret | Where |
| --- | --- |
| TrustGate MCP URL | Org **Connectors** only (all Claude products) |
| TrustGuard collector `tgk_…` | Kandji / `~/.trustguard/claude-code.json` — **not** Connectors |

## Dogfood / single machine (not org)

```bash
make install-local
claude plugin marketplace add NeuralTrust/trustguard-claude-code-plugin
claude plugin install trustguard@neuraltrust
# TrustGate: add the same remote MCP under your user/org Connectors
```

Or `claude --plugin-dir ./trustguard` from a clone.

## Event → evaluation mapping

| Claude Code event | Protocol | Direction | On block | On ask |
| --- | --- | --- | --- | --- |
| `UserPromptSubmit` | `llm` | input | `decision: "block"` | continues with a warning (no confirmation UI) |
| `PreToolUse` (`Bash`) | `all` | input | `permissionDecision: "deny"` | `permissionDecision: "ask"` |
| `PreToolUse` (other / MCP tools) | `mcp` tools/call | input | same deny | same ask |
| `PostToolUse` | `mcp` result | output | `decision: "block"` + untrusted guidance | allowed — must not re-challenge an approved tool |

Stamps: `collector.type=ide`, `source.application=claude-code-plugin`,
`consumer_id` is the account email from `~/.claude.json`
(`oauthAccount.emailAddress`). The collector already identifies the source.
Override with `TRUSTGUARD_CONSUMER_ID` or `consumer_id` in config.

## Layout

| Path | Role |
| --- | --- |
| `trustguard/` | Plugin (manifest, hooks, skill) — **hooks only** |
| `.claude-plugin/marketplace.json` | Marketplace catalog (`neuraltrust`) |
| `cli/` | `trustguard-claude-code` binary |
| `mdm/claude/` | Org Claude managed-settings template (plugin enable) |
| `mdm/kandji/` | macOS MDM: binary + collector (+ optional Claude settings) |

```bash
make build && make test && make install-local
```

## Releases (automated)

Same model as the Cursor plugin. On every push to `main`, the **Release**
workflow:

| State on `main` | Action |
| --- | --- |
| Version in `plugin.json` **not** tagged yet | Rebuild, verify pinned SHA-256, tag `vX.Y.Z`, upload `dist/*` |
| Version already released | Bump patch, pin new checksums, push `release/vX.Y.Z` (open the PR from the run summary) |

Merging that release PR publishes. Manual: **Actions → Release → Run workflow**.

```bash
make release-plan   # mode=publish|prepare + version
make dist VERSION=0.1.13
python3 scripts/release.py verify 0.1.13
```

Kandji / bootstrap downloads:
`https://github.com/NeuralTrust/trustguard-claude-code-plugin/releases/download/vX.Y.Z/…`

## License

Apache-2.0 — see [`LICENSE`](./LICENSE).
