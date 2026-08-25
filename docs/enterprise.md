# Enterprise deployment — org-wide (managed)

**TrustGate MCP Gateway is always on for the whole Claude org and every
product** (claude.ai, Desktop, Cowork, Claude Code). It is **not** shipped by
this plugin.

This plugin only adds **local firewall hooks** on Claude Code.

| Piece | Surfaces | How |
| --- | --- | --- |
| **1. TrustGate MCP Gateway** | **All** Claude products | Org **Connectors** (Owner) + per-user OAuth |
| **2. Claude Code plugin** | Claude Code only (hooks) | Server-managed / file managed settings |
| **3. TrustGuard collector + binary** | Claude Code hooks only | Kandji MDM |

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. claude.ai Organization settings → Connectors                  │
│    TrustGate remote MCP URL — org-wide, all products             │
│    → claude.ai · Desktop · Cowork · Claude Code                  │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ 2. Claude Code managed settings (plugin)                         │
│    · marketplace + enabledPlugins trustguard@neuraltrust         │
│    · NO pluginConfigs / NO MCP URL (MCP is piece 1)              │
│    · lifecycle hooks → TrustGuard evaluate                       │
└───────────────────────────────┬──────────────────────────────────┘
                                │ needs tgk_ + binary on the Mac
┌───────────────────────────────▼──────────────────────────────────┐
│ 3. Kandji                                                        │
│    · /Library/…/TrustGuard/claude-code.json (tgk_…)              │
│    · …/bin/trustguard-claude-code                                │
└──────────────────────────────────────────────────────────────────┘
```

## 1 — TrustGate MCP (org-wide, required)

Owners add a **custom remote MCP** connector **once**. That is the only
supported path for TrustGate across the org.

Doc: [Custom connectors (remote MCP)](https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp).

1. Owner → **Organization settings → Connectors → Add → Custom → Web**
2. Name: `TrustGate` (or your brand)
3. URL: `https://HOST/CONSUMER-SLUG/mcp` from TrustGate Connect
4. Advanced OAuth Client ID/Secret only if TrustGate requires a fixed client
5. Save — connector is available to the **entire org**

Each user (any product):

1. **Customize → Connectors** → TrustGate → **Connect** (OAuth once)

Notes:

- The connector is reached from **Anthropic’s cloud**, not the laptop. The MCP
  URL must be reachable from the public internet (or allowlisted Anthropic
  egress).
- Team/Enterprise: Owner must add the connector before members can use it.
- **Do not** put the TrustGuard collector `tgk_…` on this connector.
- **Do not** also bind the same URL via the Claude Code plugin (`mcpServers` /
  `pluginConfigs`) — that creates a second “Connects in sessions” entry and
  is the wrong model for org-wide always-on MCP.

## 2 — Claude Code plugin (hooks only)

Canonical template: **[mdm/claude/managed-settings.json](../mdm/claude/managed-settings.json)**  
Ops: **[mdm/claude/README.md](../mdm/claude/README.md)**.

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

Deliver via:

- claude.ai **server-managed settings** (recommended), or
- file: `/Library/Application Support/ClaudeCode/managed-settings.json` (macOS)

No `pluginConfigs`. No MCP URL in managed settings.

## 3 — TrustGuard collector + binary (Kandji)

Only for **Claude Code lifecycle hooks** (firewall). Not used by org MCP.

- **[mdm/kandji/README.md](../mdm/kandji/README.md)**
- Installs `tgk_…` + `trustguard-claude-code`

```json
{
  "data_url": "https://data.example.neuraltrust.ai",
  "api_key": "tgk_…",
  "fail_mode": "closed"
}
```

## Org checklist

- [ ] TrustGate Connect: public (or allowlisted) MCP URL
- [ ] claude.ai Owner: org **Connectors** → TrustGate custom remote MCP (all products)
- [ ] Pilot users: Connect OAuth on claude.ai / Desktop / Code
- [ ] Merge plugin to `main` → **Release** workflow publishes GitHub Release (binaries)
- [ ] Claude Code managed settings: enable `trustguard@neuraltrust` only
- [ ] Kandji: collector + binary on Macs that run Claude Code
- [ ] Pilot Claude Code: `/status`, hooks → TrustGuard `source.application=claude-code-plugin`
- [ ] Expand Blueprints / org

## Inference Hooks vs this stack

| Path | What |
| --- | --- |
| Anthropic **Inference Hooks** | Enterprise org traffic to `/v1/evaluate/claude` (`whsec_…`) |
| **This plugin** | Local Claude Code hooks → `/v1/evaluate` with `tgk_…`, stamp `claude-code-plugin` |
| **TrustGate MCP** | Tools gateway for **all** Claude products via **Org Connectors only** |

Do not put `whsec_…` in Kandji collector config. Do not put `tgk_…` on the MCP connector.
