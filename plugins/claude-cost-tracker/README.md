# Claude Cost Tracker Plugin

A Claude Code plugin that automatically tracks token usage and cost in real-time. Every tool call is logged to a local SQLite database with developer, project, session, and model metadata -- giving you full visibility into your Claude Code spend.

```
Claude Code runs a tool (Edit, Bash, Read, Write...)
        ↓
PostToolUse hook captures token usage automatically
        ↓
Writes to local SQLite with developer, project, model metadata
        ↓
Query via slash command, agent skill, or optional dashboard
```

## Installation

### From Plugin Directory

```bash
claude /plugin install claude-cost-tracker
```

### From GitHub

```bash
claude /plugin install https://github.com/MayurBhavsar/claude-cost-tracker-plugin
```

### Local Development

```bash
git clone https://github.com/MayurBhavsar/claude-cost-tracker-plugin.git
cd claude-cost-tracker-plugin
npm install
claude --plugin-dir .
```

After installing, run `/reload-plugins` to activate the hook.

## What's Included

### PostToolUse Hook (automatic)

Fires after every tool call. Captures token counts, calculates cost using the configured model's pricing, and writes a record to `~/.claude-cost-tracker/usage.db`. Also checks alert thresholds and budget caps, firing macOS notifications and stderr warnings when exceeded.

The hook is non-blocking and pass-through -- it never interferes with Claude Code's operation.

### Slash Command

```
/claude-cost-tracker:cost-report
```

Generates a formatted cost report with today's spend, project breakdown, tool breakdown, and 7-day trend.

```
/claude-cost-tracker:cost-report csv
```

Includes raw CSV export of recent usage data.

### Agent Skill

Claude automatically uses the `cost-status` skill when you ask about spending, costs, or budgets. Just ask naturally:

- "How much have I spent today?"
- "What's my cost breakdown by project?"
- "Am I within budget?"

## Features

- **Automatic tracking** -- PostToolUse hook captures every tool call without manual logging
- **Cost breakdown** -- By developer, project, tool, session, and date
- **Multi-model pricing** -- Sonnet 4.5, Opus, and Haiku with per-token costs
- **Budget caps** -- Daily, weekly, and monthly limits with notifications
- **Cost alerts** -- Configurable thresholds with macOS system notifications
- **Session grouping** -- Track costs per Claude Code session
- **Team sharing** -- Optional HTTP server aggregates data from multiple developers
- **Local by default** -- All data stays on your machine unless you enable optional team sync

## What Makes This Different

Most cost tracking tools give you a number. This plugin gives you actionable intelligence:

- **Full analytics dashboard** -- The only cost tracking plugin that ships a complete web UI with interactive charts, projections, and session drill-down. Not just numbers in a terminal.
- **Budget enforcement** -- Daily, weekly, and monthly caps with real-time macOS notifications. Not just tracking -- actual enforcement that warns you before you overspend.
- **Cost projections** -- "At this rate" monthly estimate based on 7-day rolling average. Know where you're headed, not just where you've been.
- **Session intelligence** -- Group costs by Claude Code session with duration and per-tool-call drill-down. See exactly which session burned your budget.
- **Multi-model awareness** -- Accurate per-token pricing for Sonnet 4.5, Opus, and Haiku with one-command switching. Most trackers assume a single model.
- **Team aggregation** -- Optional self-hosted server collects data from multiple developers. No third-party cloud service, no data leaving your network.
- **Three query interfaces** -- Ask Claude naturally ("how much have I spent?"), use the slash command (`/claude-cost-tracker:cost-report`), or browse the web dashboard. Pick what fits your workflow.

## Token Pricing

| Model | Input (/1M) | Output (/1M) | Cache Read (/1M) | Cache Create (/1M) |
|-------|-------------|---------------|-------------------|---------------------|
| Sonnet 4.5 (default) | $3.00 | $15.00 | $0.30 | $3.75 |
| Opus | $15.00 | $75.00 | $1.50 | $18.75 |
| Haiku | $0.80 | $4.00 | $0.08 | $1.00 |

The active model is stored in `~/.claude-cost-tracker/config.json`. To switch:

```bash
cd /path/to/claude-cost-tracker-plugin
npm run set-model opus
```

## Optional: Web Dashboard

The plugin includes a full Next.js analytics dashboard with charts, budgets, projections, and session views.

```bash
cd /path/to/claude-cost-tracker-plugin
cd dashboard && npm install && cd ..
npm run dashboard
```

Open [http://localhost:3000/dashboard](http://localhost:3000/dashboard) to view:

- Daily cost charts with date range filters
- Cost projection based on 7-day rolling average
- Budget progress bars (green/amber/red)
- Session drill-down with per-session cost
- Developer and project breakdowns
- Export to CSV or JSON

## Optional: Team Server

For multi-developer cost tracking, run the team server:

```bash
npm run server                              # Start on port 4567
npm run configure-remote http://<ip>:4567   # Point hook at team server
```

The hook will forward usage records to the team server in addition to writing locally.

## Data Storage

All data stays on your machine:

- **Database**: `~/.claude-cost-tracker/usage.db` (SQLite)
- **Config**: `~/.claude-cost-tracker/config.json` (model, remote URL)
- **Tables**: `usage`, `alerts`, `budgets` (created by hook); `audit_log` (created by dashboard)

## Plugin Structure

```
claude-cost-tracker-plugin/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── hooks/
│   ├── hooks.json               # PostToolUse hook definition
│   └── cost-tracker.js          # Hook script (plain JS, no build step)
├── skills/
│   └── cost-status/
│       └── SKILL.md             # Agent skill for cost queries
├── commands/
│   └── cost-report.md           # Slash command for reports
├── db/
│   └── database.ts              # SQLite schema + queries
├── server/
│   └── index.ts                 # Team HTTP server (optional)
├── scripts/
│   ├── setup.ts                 # Standalone setup (not needed in plugin mode)
│   ├── status.ts                # CLI cost summary
│   ├── set-model.ts             # Switch pricing model
│   ├── seed-demo.ts             # Populate demo data
│   ├── reset-db.ts              # Wipe database
│   └── configure-remote.ts      # Configure team server URL
├── dashboard/                   # Next.js 14 web dashboard (optional)
├── package.json
├── LICENSE
└── README.md
```

## CLI Commands

These scripts work in both plugin mode and standalone mode:

```bash
npm run status                    # CLI cost summary
npm run set-model sonnet-4.5     # Switch pricing model
npm run seed-demo                # Populate demo data for testing
npm run reset-db                 # Wipe and recreate the database
```

## Standalone Mode (Without Plugin System)

If you're on an older version of Claude Code without plugin support, you can still use this as a standalone tool:

```bash
npm run setup    # Registers the hook in ~/.claude/settings.json
```

## Testing Without Claude Code

Simulate a hook payload to verify the pipeline:

```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":"/src/app.ts"},"tool_output":{"usage":{"input_tokens":2000,"output_tokens":500,"cache_read_input_tokens":1000,"cache_creation_input_tokens":0}}}' | node hooks/cost-tracker.js > /dev/null
```

Then check `npm run status` to confirm the record was written.

## Requirements

- Node.js 18+
- Claude Code CLI
- Git (for project name and developer email detection)
- macOS or Linux

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Hook not firing | Run `/reload-plugins`, verify plugin is listed in `/plugin list` |
| SQLite errors | Check `~/.claude-cost-tracker/` exists and is writable |
| `better-sqlite3` not found | Run `npm install` in the plugin directory |
| Dashboard empty | Run `npm run seed-demo` to populate sample data |
| No token data | Some tool calls don't include usage data -- handled gracefully |

## License

MIT
