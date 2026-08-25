# Enterprise deployment — org-wide (managed)

Three pieces. TrustGate MCP is **org-wide for Claude** (claude.ai, Desktop,
Cowork). The plugin only wires that same gateway into **Claude Code**, plus
local firewall hooks.

| Piece | Surfaces | How |
| --- | --- | --- |
| **1. TrustGate MCP Gateway** | claude.ai, Desktop, Cowork, Claude Code* | Org **Connectors** (Owner) + per-user OAuth |
| **2. Claude Code plugin** | Claude Code only (hooks + optional MCP bind) | Server-managed / file managed settings |
| **3. TrustGuard collector + binary** | Claude Code hooks only | Kandji MDM |

\*Claude Code can use TrustGate either as a **claude.ai connector** that Code
also loads, or via the plugin’s `userConfig` MCP entry. Prefer **one** path so
you do not register the same URL twice.

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. claude.ai Organization settings → Connectors                  │
│    TrustGate remote MCP URL (same URL for everyone)              │
│    → claude.ai · Desktop · Cowork · (optional) Claude Code       │
└───────────────────────────────┬──────────────────────────────────┘
                                │ same TrustGate endpoint
┌───────────────────────────────▼──────────────────────────────────┐
│ 2. Claude Code managed settings (plugin)                         │
│    · marketplace + enabledPlugins trustguard@neuraltrust         │
│    · pluginConfigs…trustgate_mcp_url  OR  rely on claude.ai MCP  │
│    · lifecycle hooks → TrustGuard evaluate                       │
└───────────────────────────────┬──────────────────────────────────┘
                                │ needs tgk_ + binary on the Mac
┌───────────────────────────────▼──────────────────────────────────┐
│ 3. Kandji                                                        │
│    · /Library/…/TrustGuard/claude-code.json (tgk_…)              │
│    · …/bin/trustguard-claude-code                                │
└──────────────────────────────────────────────────────────────────┘
```

## 1 — TrustGate MCP for the whole Claude org

This is **not** limited to Claude Code. Owners add a **custom remote MCP**
connector once; members connect with OAuth.

Doc: [Custom connectors (remote MCP)](https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp).

1. Owner → **Organization settings → Connectors → Add → Custom → Web**
2. Name: `TrustGate` (or your brand)
3. URL: `https://HOST/CONSUMER-SLUG/mcp` from TrustGate Connect
4. Advanced OAuth Client ID/Secret only if TrustGate requires a fixed client
5. Save

Each user (claude.ai / Desktop / Cowork):

1. **Customize → Connectors** → TrustGate → **Connect** (OAuth once)

Notes:

- The connector is reached from **Anthropic’s cloud**, not the laptop. The MCP
  URL must be reachable from the public internet (or allowlisted Anthropic
  egress). Private-only MCP needs TrustGate’s private/network options.
- Team/Enterprise: Owner must add the connector before members can use it.
- Optional: Enterprise-managed auth via IdP so users inherit access on login
  (when your Claude plan supports it).

**Do not** put the TrustGuard collector `tgk_…` on this connector.

## 2 — Claude Code plugin (hooks + optional MCP bind)

Canonical template: **[mdm/claude/managed-settings.json](../mdm/claude/managed-settings.json)**  
Ops: **[mdm/claude/README.md](../mdm/claude/README.md)**.

Minimum for **hooks only** (if TrustGate already comes from org Connectors and
Claude Code loads claude.ai MCPs):

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

If Claude Code should bind TrustGate **via the plugin** (isolated from
claude.ai connectors, or connectors not loaded in that session), also set:

```json
{
  "pluginConfigs": {
    "trustguard@neuraltrust": {
      "options": {
        "trustgate_mcp_url": "https://HOST/CONSUMER-SLUG/mcp"
      }
    }
  }
}
```

Use the **same** URL as the org Connector. Avoid enabling both the plugin MCP
and a duplicate custom connector with the same endpoint in the same session
(duplicate MCP tools).

Deliver managed settings via:

- claude.ai **server-managed settings** (recommended for org policy), or
- file: `/Library/Application Support/ClaudeCode/managed-settings.json` (macOS)

**Do not** use “Add custom connector” *inside* the plugin UI for the
`${user_config…}` placeholder — that is the wrong surface for plugin options.

## 3 — TrustGuard collector + binary (Kandji)

Only needed for **Claude Code lifecycle hooks** (firewall). Not used by
claude.ai chat connectors.

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
- [ ] claude.ai Owner: org **Connectors** → TrustGate custom remote MCP
- [ ] Pilot users: Connect OAuth on claude.ai / Desktop
- [ ] Merge plugin to marketplace default branch + GitHub release (binaries)
- [ ] Claude Code managed settings: enable `trustguard@neuraltrust` (+ MCP URL if needed)
- [ ] Kandji: collector + binary on Macs that run Claude Code
- [ ] Pilot Claude Code: `/status`, hooks → TrustGuard `source.application=claude-code-plugin`
- [ ] Expand Blueprints / org

## Inference Hooks vs this stack

| Path | What |
| --- | --- |
| Anthropic **Inference Hooks** | Enterprise org traffic to `/v1/evaluate/claude` (`whsec_…`) |
| **This plugin** | Local Claude Code hooks → `/v1/evaluate` with `tgk_…`, stamp `claude-code-plugin` |
| **TrustGate MCP** | Tools gateway for Claude products via Connectors / plugin MCP |

Do not put `whsec_…` in Kandji collector config. Do not put `tgk_…` on the MCP connector.
