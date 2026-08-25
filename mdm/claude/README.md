# Claude Code managed settings — TrustGuard plugin

Deploys the **Claude Code plugin** (hooks) to every Code session. Pair with:

1. **Org Connectors** for TrustGate MCP on **claude.ai / Desktop / Cowork**  
   (see [docs/enterprise.md](../../docs/enterprise.md) §1) — that is the
   primary MCP path for “Claude”, not only Code.
2. **Kandji** (`../kandji/`) for collector `tgk_…` + hook binary.

| Layer | Delivers | Mechanism |
| --- | --- | --- |
| Org Connectors | TrustGate MCP for Claude products | claude.ai Owner → Connectors |
| This file | Plugin enable (+ optional MCP bind for Code) | Claude Code managed settings |
| Kandji | `tgk_…` + binary | TrustGuard support dir |

## 1. Fill the template

Edit [`managed-settings.json`](./managed-settings.json):

1. Keep `enabledPlugins` / `extraKnownMarketplaces` unless names differ.
2. **`pluginConfigs.trustgate_mcp_url`**:
   - **Set it** if Claude Code should get TrustGate from the plugin (same URL
     as the org Connector).
   - **Omit `pluginConfigs` entirely** if Code already loads the org TrustGate
     connector from claude.ai and you only need hooks from this plugin.

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

## 2. Deliver the file (or server-managed)

| OS | Path |
| --- | --- |
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Linux / WSL | `/etc/claude-code/managed-settings.json` |
| Windows | `C:\Program Files\ClaudeCode\managed-settings.json` |

**Preferred for org policy:** same JSON keys in claude.ai **server-managed
settings** (no file on disk). If both remote and file exist, **remote wins**.

**Kandji:** `TRUSTGUARD_DEPLOY_CLAUDE_MANAGED_SETTINGS=1` + optional
`TRUSTGATE_MCP_URL` on the install script.

## 3. Keys

| Key | Effect |
| --- | --- |
| `extraKnownMarketplaces.neuraltrust` | Registers this GitHub marketplace |
| `enabledPlugins["trustguard@neuraltrust"]` | Force plugin on (hooks) |
| `pluginConfigs…options.trustgate_mcp_url` | Optional: bind TrustGate inside the plugin for Code |

`pluginConfigs` values must nest under **`options`**.

## 4. Verify Claude Code

```bash
# /status → Enterprise managed settings (remote|file)
claude plugin list   # trustguard@neuraltrust enabled
# /mcp → TrustGate (from plugin and/or claude.ai connector) + OAuth
```

Hooks still need Kandji collector + binary.
