# Claude Code managed settings — TrustGuard plugin

Enables the **Claude Code plugin** (lifecycle hooks only). TrustGate MCP is
**not** configured here.

| Layer | Delivers | Mechanism |
| --- | --- | --- |
| **Org Connectors** | TrustGate MCP for **all** Claude products | claude.ai Owner → Connectors (always on for the org) |
| **This file** | Plugin enable (hooks) | Claude Code managed settings |
| **Kandji** | `tgk_…` + binary | TrustGuard support dir |

See [docs/enterprise.md](../../docs/enterprise.md).

## 1. Template

[`managed-settings.json`](./managed-settings.json) — marketplace + `enabledPlugins`
only. **No** `pluginConfigs`, **no** MCP URL.

Optional hardening:

```json
{
  "strictKnownMarketplaces": [
    { "source": "github", "repo": "anthropics/claude-plugins-official" },
    { "source": "github", "repo": "NeuralTrust/trustguard-claude-code-plugin" }
  ],
  "pluginTrustMessage": "Trustguard is approved by IT for this organization."
}
```

## 2. Deliver

| OS | Path |
| --- | --- |
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Linux / WSL | `/etc/claude-code/managed-settings.json` |
| Windows | `C:\Program Files\ClaudeCode\managed-settings.json` |

**Preferred:** same JSON keys in claude.ai **server-managed settings** (no file
on disk). If both remote and file exist, **remote wins**.

**Kandji:** `TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS=1` writes this file
(plugin enable only; MCP stays on Org Connectors).

## 3. Keys

| Key | Effect |
| --- | --- |
| `extraKnownMarketplaces.neuraltrust` | Registers this GitHub marketplace |
| `enabledPlugins["trustguard@neuraltrust"]` | Force plugin on (hooks) |

## 4. Verify

```bash
# /status → Enterprise managed settings (remote|file)
claude plugin list   # trustguard@neuraltrust enabled
# /mcp → TrustGate from **org Connectors**, not "Provided by the Trustguard plugin"
```

Hooks still need Kandji collector + binary.
