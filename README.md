# Claude Extensions

A curated collection of Claude Code extensions — hooks, context rules, and session automation.

[![Validate Plugins](https://github.com/claude-contrib/claude-extensions/actions/workflows/validate-plugins.yml/badge.svg)](https://github.com/claude-contrib/claude-extensions/actions/workflows/validate-plugins.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What are Extensions?

Extensions run passively — they trigger on events (file edits, session start) or load context rules automatically. They differ from:

- **Skills** ([claude-skills](https://github.com/claude-contrib/claude-skills)) — slash commands you invoke intentionally
- **Services** ([claude-services](https://github.com/claude-contrib/claude-services)) — MCP servers providing tools to Claude

## Installation

Add the marketplace to your Claude Code settings (`~/.claude/settings.json`):

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

Then install an extension:

```text
/plugin install <plugin-name>@claude-extensions
```

## Available Extensions

| Plugin | Description |
| --- | --- |
| [`agents-context`](plugins/agents-context/README.md) | Enable [AGENTS.md](https://agents.md/) rules for Claude Code |

## Contributing

1. Fork this repository
2. Create a plugin directory under `plugins/<your-plugin>/`
3. Add `.claude-plugin/plugin.json`, a `hooks/hooks.json` (or other config), and a `README.md`
4. Register your plugin in `.claude-plugin/marketplace.json`
5. Open a pull request — CI validates the structure automatically

See [docs/](docs/) for plugin development guides.

## License

MIT
