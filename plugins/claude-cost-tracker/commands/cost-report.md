---
description: Show a quick cost report for Claude Code token usage and spending
---

# Cost Report

Generate a cost report from the Claude Code cost tracking database.

Run these queries against `~/.claude-cost-tracker/usage.db` to gather the data:

```bash
sqlite3 -header -column ~/.claude-cost-tracker/usage.db "
  SELECT
    COALESCE(SUM(CASE WHEN date(timestamp) = date('now') THEN cost_usd END), 0) as today_cost,
    COALESCE(SUM(CASE WHEN date(timestamp) = date('now', '-1 day') THEN cost_usd END), 0) as yesterday_cost,
    ROUND(SUM(cost_usd), 4) as total_cost,
    COUNT(*) as total_calls,
    COUNT(DISTINCT session_id) as sessions,
    COUNT(DISTINCT developer) as developers
  FROM usage;
"
```

```bash
sqlite3 -header -column ~/.claude-cost-tracker/usage.db "
  SELECT project, ROUND(SUM(cost_usd), 4) as cost, COUNT(*) as calls
  FROM usage GROUP BY project ORDER BY cost DESC;
"
```

```bash
sqlite3 -header -column ~/.claude-cost-tracker/usage.db "
  SELECT tool_name, ROUND(SUM(cost_usd), 4) as cost, COUNT(*) as calls
  FROM usage GROUP BY tool_name ORDER BY cost DESC;
"
```

```bash
sqlite3 -header -column ~/.claude-cost-tracker/usage.db "
  SELECT date(timestamp) as date, ROUND(SUM(cost_usd), 4) as cost, COUNT(*) as calls
  FROM usage GROUP BY date(timestamp) ORDER BY date DESC LIMIT 7;
"
```

Present the results as a formatted report with:
1. **Summary** -- today's spend, yesterday's spend, trend direction, total spend
2. **By Project** -- table of projects ranked by cost
3. **By Tool** -- table of tools ranked by cost
4. **Last 7 Days** -- daily cost trend

If `$ARGUMENTS` includes "csv", also export the raw data:

```bash
sqlite3 -csv -header ~/.claude-cost-tracker/usage.db "SELECT * FROM usage ORDER BY timestamp DESC LIMIT 100;"
```
