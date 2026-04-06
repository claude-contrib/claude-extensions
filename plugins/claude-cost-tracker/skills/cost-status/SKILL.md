---
name: cost-status
description: Check current Claude Code spending, token usage, and budget status. Use when the user asks about costs, spending, usage, tokens, or budgets.
---

# Cost Status

Query the Claude Code cost tracking database to report current spending.

## How to check

Run this command to get a formatted cost summary:

```bash
sqlite3 ~/.claude-cost-tracker/usage.db "
  SELECT
    'Today: $' || ROUND(COALESCE(SUM(CASE WHEN date(timestamp) = date('now') THEN cost_usd END), 0), 4) ||
    ' | Total: $' || ROUND(COALESCE(SUM(cost_usd), 0), 4) ||
    ' | Calls: ' || COUNT(*) ||
    ' | Sessions: ' || COUNT(DISTINCT session_id)
  FROM usage;
"
```

If the user wants more detail, also run:

```bash
sqlite3 -header -column ~/.claude-cost-tracker/usage.db "
  SELECT project, ROUND(SUM(cost_usd), 4) as cost, COUNT(*) as calls
  FROM usage GROUP BY project ORDER BY cost DESC LIMIT 10;
"
```

And for budget status:

```bash
sqlite3 -header -column ~/.claude-cost-tracker/usage.db "
  SELECT type, limit_usd FROM budgets;
"
```

## What to report

- Today's spend and comparison to yesterday
- Total all-time spend
- Top projects by cost
- Any active budgets and whether they are close to being exceeded
- Number of sessions tracked

If the database file does not exist at `~/.claude-cost-tracker/usage.db`, tell the user the cost tracker is not yet set up and suggest running `npm install` in the plugin directory followed by reloading plugins.
