# TrustGuard for Claude Code

AI firewall for [Claude Code](https://code.claude.com) via **lifecycle hooks**.
One org collector, MDM-deployable — every developer is protected without a
NeuralTrust account.

Same model as the [Cursor](https://github.com/NeuralTrust/trustguard-cursor-plugin)
and [Codex](https://github.com/NeuralTrust/trustguard-codex-plugin) plugins:
local hooks call `trustguard-claude-code`, which maps Claude Code events to
TrustGuard `POST /v1/evaluate` and returns allow / deny.

> **Claude Enterprise Inference Hooks** (`/v1/evaluate/claude`) are a separate
> path for Anthropic Enterprise orgs. This plugin is for teams that use Claude
> Code **without** org-level Inference Hooks (non-Enterprise, or Enterprise
> orgs that prefer the local-hook model).

Optional: the same plugin can register **TrustGate MCP Gateway** tools when
`TRUSTGATE_MCP_URL` is set.

## Install

### From this marketplace (recommended)

In Claude Code:

```text
/plugin marketplace add NeuralTrust/trustguard-claude-code-plugin
/plugin install trustguard@neuraltrust
```

Or load a local checkout:

```bash
make install-local
claude --plugin-dir ./trustguard
```

### Configure credentials

**Preferred (org Plugins / local install):** when you enable the plugin, Claude
Code prompts for `userConfig`:

| Field | What |
|---|---|
| TrustGuard data URL | Data-plane base URL (`https://…`, no `/v1/evaluate`) |
| TrustGuard collector API key | `tgk_…` from a Claude Code / IDE collector (`sensitive`) |
| Fail mode | `open` or `closed` (default `open`) |
| TrustGate MCP URL | Optional full MCP endpoint from TrustGate Connect |
| TrustGate MCP API key | Optional consumer key (`X-AG-API-Key`), not `tgk_…` |
| TrustGate gateway slug | Optional hybrid / private data plane |

Sensitive values go to the OS keychain (or `~/.claude/.credentials.json`).
Non-sensitive options land in `~/.claude/settings.json` under `pluginConfigs`.

Create a **Claude Code** (or generic IDE) collector in TrustGuard and mint the
key. Do not reuse the Anthropic Inference Hook secret (`whsec_…`).

**Alternatives** (same binary; priority: MDM file → user file → env → plugin prompt):

```json
// ~/.trustguard/claude-code.json
{
  "data_url": "https://<trustguard-data-plane>",
  "api_key": "tgk_…",
  "fail_mode": "closed"
}
```

```bash
export TRUSTGUARD_DATA_URL="https://…"
export TRUSTGUARD_API_KEY="tgk_…"
```

### Enterprise (MDM)

1. Deploy `trustguard-claude-code` onto developer machines (PATH or
   `~/.trustguard/bin`).
2. Drop a managed config with the org Claude Code collector key:
   - macOS: `/Library/Application Support/TrustGuard/claude-code.json`
   - Linux: `/etc/trustguard/claude-code.json`
   - Windows: `%ProgramData%\TrustGuard\claude-code.json`
3. Ship the plugin via your org marketplace or managed settings so hooks cannot
   be removed casually.

Developers cannot override locked `api_key` / `data_url` / `fail_mode` from the
user config or env when the managed file is present.

### TrustGate MCP (optional)

Prefer the enable-time plugin fields above. Equivalent env (if you wire MCP
outside the plugin) is not required when `userConfig` is set.

Not the TrustGuard `tgk_…` key.

## Event → evaluation mapping

| Claude Code event | TrustGuard protocol | Direction | Notes |
|---|---|---|---|
| `UserPromptSubmit` | `llm` | input | Block with `decision: "block"` |
| `PreToolUse` (`Bash`) | `all` | input | Deny with `permissionDecision: "deny"` |
| `PreToolUse` (MCP / other tools) | `mcp` tools/call | input | Same deny shape |
| `PostToolUse` | `mcp` result | output | `decision: "block"` + untrusted-result guidance |

Attributes stamped on every evaluate call:

- `collector.type` = `ide`
- `source.application` = `claude-code-plugin` (gate-friendly; distinct from
  Enterprise Inference Hook values like `claude-code` / `claude-ai`)
- `consumer_id` prefers `user_email` when present, else config / OS user,
  always prefixed `claude-code:`

## Repository layout

| Path | Role |
|---|---|
| [`trustguard/`](./trustguard/) | Claude Code plugin (manifest, hooks, skill, MCP, logo) |
| [`.claude-plugin/marketplace.json`](./.claude-plugin/marketplace.json) | Marketplace catalog |
| [`cli/`](./cli/) | `trustguard-claude-code` binary (Go, stdlib-only) |
| [`scripts/`](./scripts/) | Cross-compile |
| [`docs/`](./docs/) | Enterprise notes |

```bash
make build          # ./bin/trustguard-claude-code
make test           # go test -race ./cli/
make install-local  # binary → ~/.trustguard/bin
make dist VERSION=0.1.0
```

## Verify

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"session_id":"sess_1"}' \
  | ./bin/trustguard-claude-code hook
```

## License

Apache-2.0 — see [`LICENSE`](./LICENSE).
