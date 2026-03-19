# Claude Extensions

> Hooks, context rules, and session automation for [Claude Code](https://claude.ai/code) — applied automatically, every session, zero extra prompts.

[![Test](https://github.com/claude-contrib/claude-extensions/actions/workflows/test.yml/badge.svg)](https://github.com/claude-contrib/claude-extensions/actions/workflows/test.yml)
[![Validate](https://github.com/claude-contrib/claude-extensions/actions/workflows/validate.yml/badge.svg)](https://github.com/claude-contrib/claude-extensions/actions/workflows/validate.yml)
[![Release](https://img.shields.io/github/v/release/claude-contrib/claude-extensions)](https://github.com/claude-contrib/claude-extensions/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Stop repeating project conventions to Claude. Extensions encode your team's rules, automate session setup, and react to tool events — passively, in the background, without you lifting a finger.

## How Extensions Work

Extensions are **passive plugins** — they don't require invocation:

| Type | Trigger | Example |
|------|---------|---------|
| **Hooks** | Claude Code events (`SessionStart`, `Stop`, `Notification`, …) | Sync rules on startup, notify on completion |
| **Context rules** | Path patterns | Inject team conventions scoped to `src/api/**` |

Install once. Works on every future session automatically.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/setup) (`claude`)

Install `claude` separately: [Claude Code installation guide](https://docs.anthropic.com/en/docs/claude-code/setup)

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
/plugin install agent-rules@claude-extensions
```

That's it — the extension activates on your next session start.

## Available Extensions

| Extension | Description |
|-----------|-------------|
| [`agent-rules`](plugins/agent-rules/README.md) | Automatically syncs [AGENTS.md](https://agents.md/) files into Claude Code path-specific rules on every session start |
| [`tmux-notify`](plugins/tmux-notify/README.md) | tmux notifications for Claude Code — bell, display-message, and auto-focus |
| [`macos-notify`](plugins/macos-notify/README.md) | Native macOS Notification Center alerts with click-to-focus when Claude needs your input |

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

| Repo | What it provides |
|------|-----------------|
| **claude-extensions** ← you are here | Hooks, context rules, session automation |
| [claude-features](https://github.com/claude-contrib/claude-features) | Devcontainer features for Claude Code and Anthropic tools |
| [claude-languages](https://github.com/claude-contrib/claude-languages) | LSP language servers — completions, diagnostics, hover |
| [claude-sandbox](https://github.com/claude-contrib/claude-sandbox) | Sandboxed Docker environment for Claude Code |
| [claude-services](https://github.com/claude-contrib/claude-services) | MCP servers — browser, filesystem, sequential thinking |
| [claude-skills](https://github.com/claude-contrib/claude-skills) | Slash commands for Claude Code |
| [claude-status](https://github.com/claude-contrib/claude-status) | Live status line — context, cost, model, branch, worktree |

## License

MIT — use it, fork it, extend it.
