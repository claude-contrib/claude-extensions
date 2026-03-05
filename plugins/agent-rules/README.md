# agent-rules

> Automatically sync [AGENTS.md](https://agents.md/) files into Claude Code path-specific rules — no manual setup, no copy-paste.

## What it does

Claude Code has a native [path-specific rules](https://code.claude.com/docs/en/memory#path-specific-rules) system that injects context based on which files you're editing. `agent-rules` bridges the popular `AGENTS.md` convention to that system automatically.

On every session start it:
1. Finds all `AGENTS.md` files in your repository (respects `.gitignore`)
2. Copies each one to `.claude/rules/agents/` with YAML frontmatter that sets the path scope
3. Removes any previously generated rules whose source `AGENTS.md` was deleted
4. Skips files that haven't changed — no unnecessary I/O on repeat starts

## Installation

```
/plugin install agent-rules@claude-extensions
```

After installing, add the generated directory to your `.gitignore` — the files are auto-generated and shouldn't be committed:

```
# Claude Code — generated from AGENTS.md files
.claude/rules/agents/
```

## How path mapping works

The output path and frontmatter are derived from where each `AGENTS.md` lives:

| Source file | Generated rule | Applies to |
|-------------|---------------|------------|
| `AGENTS.md` | `.claude/rules/agents/AGENTS.md` | `**/*` (whole repo) |
| `src/api/AGENTS.md` | `.claude/rules/agents/src/api/AGENTS.md` | `src/api/**/*` |
| `docs/AGENTS.md` | `.claude/rules/agents/docs/AGENTS.md` | `docs/**/*` |

**Example — root `AGENTS.md`:**

```markdown
# Project Guidelines

This is a TypeScript project. Always:
- Use strict mode
- Write tests for new features
- Follow the ESLint configuration
```

Becomes `.claude/rules/agents/AGENTS.md`:

```yaml
---
paths:
  - "**/*"
---

# Project Guidelines

This is a TypeScript project. Always:
- Use strict mode
- Write tests for new features
- Follow the ESLint configuration
```

## Multi-level example

```
your-repo/
├── AGENTS.md              # general project guidelines → **/*
├── src/
│   ├── api/AGENTS.md      # API conventions → src/api/**/*
│   └── ui/AGENTS.md       # UI conventions → src/ui/**/*
└── docs/AGENTS.md         # docs guidelines → docs/**/*
```

Claude picks up whichever rules match the files you're working with.

## Git submodules

Each git repository is processed independently. When you open a parent repo, only that repo's `AGENTS.md` files are synced — submodules manage their own rules when opened as a workspace. This prevents rule conflicts and matches git's model of independent repositories.

## Contributing

Issues and pull requests welcome at [claude-contrib/claude-extensions](https://github.com/claude-contrib/claude-extensions).

## License

MIT
