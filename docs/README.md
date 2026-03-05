# Contributor Guide — Claude Extensions

Everything you need to build and publish an extension.

## What is an Extension?

An extension is a Claude Code plugin that runs **passively** — it reacts to events or injects context automatically, without the user invoking a command. The two mechanisms are:

- **Hooks** — shell commands triggered by Claude Code lifecycle events (`SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`, `Notification`)
- **Context rules** — markdown files scoped to path patterns, automatically loaded when Claude works in matching directories

## Plugin Structure

```
plugins/<your-extension>/
├── .claude-plugin/
│   └── plugin.json          # required — plugin manifest
├── hooks/
│   └── hooks.json           # hook definitions (if using hooks)
├── scripts/                 # helper scripts called by hooks (optional)
│   └── your-script.sh
└── README.md                # required — usage docs
```

## `plugin.json` — Plugin Manifest

```json
{
  "name": "your-extension",
  "version": "1.0.0",
  "description": "What this extension does",
  "author": {
    "name": "your-name",
    "email": "you@example.com",
    "url": "https://github.com/your-name"
  },
  "homepage": "https://github.com/claude-contrib/claude-extensions",
  "repository": "https://github.com/claude-contrib/claude-extensions",
  "license": "MIT",
  "keywords": ["relevant", "tags"]
}
```

## `hooks.json` — Hook Definitions

```json
{
  "description": "What these hooks do",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/your-script.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Supported events:**

| Event | When it fires | Common matchers |
|-------|--------------|-----------------|
| `SessionStart` | Claude Code session begins | `startup` |
| `PreToolUse` | Before a tool call executes | `Write`, `Edit`, `Bash` (regex) |
| `PostToolUse` | After a tool call completes | `Write`, `Edit`, `Bash` (regex) |
| `Stop` | Claude finishes responding | `*` |
| `Notification` | Claude needs user attention | `permission_prompt`, `elicitation_dialog` |

**`${CLAUDE_PLUGIN_ROOT}`** expands to the absolute path of your plugin directory at install time.

## Registering in `marketplace.json`

Add your plugin to `.claude-plugin/marketplace.json`:

```json
{
  "name": "your-extension",
  "description": "One-line description",
  "version": "1.0.0",
  "author": { "name": "your-name" },
  "source": "./plugins/your-extension",
  "category": "automation",
  "tags": ["relevant", "tags"],
  "keywords": ["relevant", "keywords"]
}
```

## Testing Locally

```bash
# 1. Clone the repo and navigate to it
cd claude-extensions

# 2. Open Claude Code
claude

# 3. Add the local marketplace
/plugin marketplace add .

# 4. Install your extension
/plugin install your-extension@claude-extensions

# 5. Reload or start a new session to trigger SessionStart hooks
```

To iterate: edit your files, then reinstall:

```
/plugin uninstall your-extension@claude-extensions
/plugin install your-extension@claude-extensions
```

## CI Validation

Every pull request runs `.github/workflows/validate.yml` which checks:

- `marketplace.json` is valid JSON with required fields (`name`, `owner`, `plugins`)
- Each plugin entry has `name` and `source`
- Each plugin directory exists
- `plugin.json` is valid JSON with a `name` field
- No duplicate plugin names

Run the same checks locally with `jq`:

```bash
jq empty .claude-plugin/marketplace.json
jq empty plugins/your-extension/.claude-plugin/plugin.json
```

## Official References

- [Plugins overview](https://code.claude.com/docs/en/plugins) — Plugin system, component types, installation
- [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) — Marketplace creation and team distribution
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference) — Full schema specifications
- [Hooks](https://code.claude.com/docs/en/hooks) — Hook events, matchers, environment variables
