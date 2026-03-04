# Claude Extensions

> Hooks, context rules, and session automation for [Claude Code](https://claude.ai/code) — applied automatically, every session, zero extra prompts.

[![Validate](https://github.com/claude-contrib/claude-extensions/actions/workflows/validate.yml/badge.svg)](https://github.com/claude-contrib/claude-extensions/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Stop repeating project conventions to Claude. Extensions encode your team's rules, automate session setup, and react to tool events — passively, in the background, without you lifting a finger.

## How Extensions Work

Extensions are **passive plugins** — they don't require invocation:

| Type | Trigger | Example |
|------|---------|---------|
| **Hooks** | Claude Code events (`SessionStart`, `PreToolUse`, `PostToolUse`) | Sync rules on startup, lint after edits |
| **Context rules** | Path patterns | Inject team conventions scoped to `src/api/**` |

Install once. Works on every future session automatically.

## Quickstart

**1. Register the marketplace** in `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "claude-extensions": {
      "source": {
        "source": "github",
        "repo": "claude-contrib/claude-extensions"
      }
    }
  }
}
```

**2. Install an extension** inside Claude Code:

```
/plugin install agents-context@claude-extensions
```

That's it — the extension activates on your next session start.

## Available Extensions

| Extension | Description |
|-----------|-------------|
| [`agents-context`](plugins/agents-context/README.md) | Automatically syncs [AGENTS.md](https://agents.md/) files into Claude Code path-specific rules on every session start |

## Publish Your Own Extension

Got a hook or rule your team swears by? Three steps to share it with the community:

```
plugins/your-extension/
├── .claude-plugin/plugin.json   # name, version, description
├── hooks/hooks.json             # hook definitions
└── README.md                   # what it does + install instructions
```

1. **Fork** this repo and drop your plugin under `plugins/`
2. **Register** it in `.claude-plugin/marketplace.json`
3. **Open a PR** — CI validates structure automatically, no manual review of config syntax

→ [Read the full authoring guide](docs/README.md)

## The claude-contrib Ecosystem

| Marketplace | Install key | What it provides |
|-------------|------------|-----------------|
| **claude-extensions** ← you are here | `@claude-extensions` | Hooks, context rules, session automation |
| [claude-services](https://github.com/claude-contrib/claude-services) | `@claude-services` | MCP servers — browser, filesystem, sequential thinking |
| [claude-skills](https://github.com/claude-contrib/claude-skills) | `@claude-skills` | Slash commands — `/commit`, and more |

## License

MIT — use it, fork it, extend it.
