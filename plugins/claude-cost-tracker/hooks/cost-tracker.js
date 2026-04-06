#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');
const https = require('https');
const { execSync } = require('child_process');

const DB_DIR = path.join(os.homedir(), '.claude-cost-tracker');
const DB_PATH = path.join(DB_DIR, 'usage.db');
const CONFIG_PATH = path.join(DB_DIR, 'config.json');

function loadConfig() {
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    }
  } catch { /* ignore */ }
  return {};
}

const MODELS = {
  'sonnet-4.5': {
    input: 0.000003,          // $3.00 per 1M
    output: 0.000015,         // $15.00 per 1M
    cache_read: 0.0000003,    // $0.30 per 1M
    cache_creation: 0.00000375 // $3.75 per 1M
  },
  'opus': {
    input: 0.000015,          // $15.00 per 1M
    output: 0.000075,         // $75.00 per 1M
    cache_read: 0.0000015,    // $1.50 per 1M
    cache_creation: 0.00001875 // $18.75 per 1M
  },
  'haiku': {
    input: 0.0000008,         // $0.80 per 1M
    output: 0.000004,         // $4.00 per 1M
    cache_read: 0.00000008,   // $0.08 per 1M
    cache_creation: 0.000001   // $1.00 per 1M
  }
};

function getModelPricing() {
  const config = loadConfig();
  const model = config.model || 'sonnet-4.5';
  return { pricing: MODELS[model] || MODELS['sonnet-4.5'], model };
}

const { pricing: PRICING, model: ACTIVE_MODEL } = getModelPricing();

function getProjectName() {
  try {
    const repoUrl = execSync('git rev-parse --show-toplevel', {
      encoding: 'utf8',
      timeout: 3000,
      stdio: ['pipe', 'pipe', 'pipe']
    }).trim();
    return path.basename(repoUrl);
  } catch {
    return 'unknown';
  }
}

function getDeveloper() {
  try {
    return os.userInfo().username;
  } catch {
    return 'unknown';
  }
}

function getDeveloperEmail() {
  try {
    return execSync('git config user.email', {
      encoding: 'utf8',
      timeout: 3000,
      stdio: ['pipe', 'pipe', 'pipe']
    }).trim() || null;
  } catch {
    return null;
  }
}

function calculateCost(usage) {
  const input = (usage.input_tokens || 0) * PRICING.input;
  const output = (usage.output_tokens || 0) * PRICING.output;
  const cacheRead = (usage.cache_read_input_tokens || 0) * PRICING.cache_read;
  const cacheCreation = (usage.cache_creation_input_tokens || 0) * PRICING.cache_creation;
  return input + output + cacheRead + cacheCreation;
}

function ensureDb() {
  if (!fs.existsSync(DB_DIR)) {
    fs.mkdirSync(DB_DIR, { recursive: true });
  }

  let Database;
  try {
    Database = require('better-sqlite3');
  } catch {
    const pluginRoot = process.env.CLAUDE_PLUGIN_ROOT || path.join(__dirname, '..');
    const pluginModules = path.join(pluginRoot, 'node_modules', 'better-sqlite3');
    Database = require(pluginModules);
  }

  const db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');

  db.exec(`
    CREATE TABLE IF NOT EXISTS usage (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT NOT NULL,
      developer TEXT NOT NULL,
      project TEXT NOT NULL,
      tool_name TEXT NOT NULL,
      file_path TEXT,
      input_tokens INTEGER DEFAULT 0,
      output_tokens INTEGER DEFAULT 0,
      cache_read_tokens INTEGER DEFAULT 0,
      cache_creation_tokens INTEGER DEFAULT 0,
      cost_usd REAL DEFAULT 0,
      session_id TEXT,
      developer_email TEXT
    )
  `);

  try { db.exec(`ALTER TABLE usage ADD COLUMN developer_email TEXT`); } catch { /* exists */ }
  try { db.exec(`ALTER TABLE usage ADD COLUMN model TEXT`); } catch { /* exists */ }

  return db;
}

function extractFilePath(toolInput) {
  if (!toolInput) return null;
  return toolInput.file_path || toolInput.path || toolInput.filename || null;
}

function sendToRemote(record, remoteUrl) {
  return new Promise((resolve) => {
    try {
      const url = new URL('/api/ingest', remoteUrl);
      const isHttps = url.protocol === 'https:';
      const transport = isHttps ? https : http;
      const payload = JSON.stringify(record);

      const options = {
        hostname: url.hostname,
        port: url.port || (isHttps ? 443 : 80),
        path: url.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
        timeout: 3000,
      };

      const req = transport.request(options, (res) => {
        res.resume();
        resolve(true);
      });

      req.on('error', () => resolve(false));
      req.on('timeout', () => { req.destroy(); resolve(false); });
      req.write(payload);
      req.end();
    } catch {
      resolve(false);
    }
  });
}

function notifySystem(msg, title) {
  if (process.platform === 'darwin') {
    try {
      const safeMsg = msg.replace(/'/g, "\\'");
      const safeTitle = title.replace(/'/g, "\\'");
      execSync(
        `osascript -e 'display notification "${safeMsg}" with title "${safeTitle}"'`,
        { timeout: 2000, stdio: ['pipe', 'pipe', 'pipe'] }
      );
    } catch { /* ignore notification failures */ }
  }
}

function checkAlerts(db, todayCost) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS alerts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL DEFAULT 'daily_spend',
      threshold_usd REAL NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      last_triggered_at TEXT
    )
  `);

  const todayDate = new Date().toISOString().split('T')[0];
  const activeAlerts = db.prepare(
    `SELECT * FROM alerts WHERE enabled = 1 AND (last_triggered_at IS NULL OR date(last_triggered_at) != ?)`
  ).all(todayDate);

  const triggered = activeAlerts.filter(a => todayCost >= a.threshold_usd);
  if (triggered.length === 0) return;

  const now = new Date().toISOString();
  const updateStmt = db.prepare(`UPDATE alerts SET last_triggered_at = ? WHERE id = ?`);
  for (const alert of triggered) {
    updateStmt.run(now, alert.id);
  }

  const costStr = todayCost >= 1 ? `$${todayCost.toFixed(2)}` : `$${todayCost.toFixed(4)}`;
  const msg = `Daily Claude spend ${costStr} exceeded threshold`;
  process.stderr.write(`[ALERT] ${msg}\n`);
  notifySystem(msg, 'Claude Cost Tracker');
}

function checkBudgets(db, todayCost) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS budgets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL DEFAULT 'daily',
      limit_usd REAL NOT NULL,
      created_at TEXT NOT NULL
    )
  `);

  const budgets = db.prepare(`SELECT * FROM budgets`).all();
  for (const budget of budgets) {
    let spend = 0;
    if (budget.type === 'daily') {
      spend = todayCost;
    } else if (budget.type === 'weekly') {
      spend = (db.prepare(
        `SELECT COALESCE(SUM(cost_usd), 0) as s FROM usage WHERE timestamp >= datetime('now', '-7 days')`
      ).get()).s;
    } else if (budget.type === 'monthly') {
      const now = new Date();
      const monthStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
      spend = (db.prepare(
        `SELECT COALESCE(SUM(cost_usd), 0) as s FROM usage WHERE date(timestamp) >= ?`
      ).get(monthStart)).s;
    }

    if (spend >= budget.limit_usd) {
      const budgetCostStr = spend >= 1 ? `$${spend.toFixed(2)}` : `$${spend.toFixed(4)}`;
      const budgetMsg = `${budget.type} budget ${budgetCostStr} exceeded limit $${budget.limit_usd.toFixed(2)}`;
      process.stderr.write(`[BUDGET EXCEEDED] ${budgetMsg}\n`);
      notifySystem(budgetMsg, 'Claude Cost Tracker - Budget');
    }
  }
}

function checkAndNotify(db) {
  try {
    const todayResult = db.prepare(
      `SELECT COALESCE(SUM(cost_usd), 0) as today_cost FROM usage WHERE date(timestamp) = date('now')`
    ).get();
    const todayCost = todayResult.today_cost;

    checkAlerts(db, todayCost);
    checkBudgets(db, todayCost);
  } catch { /* never crash the hook over alert/budget checks */ }
}

async function main() {
  let rawInput = '';

  try {
    rawInput = fs.readFileSync('/dev/stdin', 'utf8');
  } catch {
    process.exit(0);
  }

  // Always pass through the original JSON
  if (rawInput) {
    process.stdout.write(rawInput);
  }

  try {
    const data = JSON.parse(rawInput);

    const usage = data?.tool_output?.usage || data?.usage || {};
    if (!usage.input_tokens && !usage.output_tokens) {
      process.exit(0);
    }

    const record = {
      timestamp: new Date().toISOString(),
      developer: getDeveloper(),
      developer_email: getDeveloperEmail(),
      project: getProjectName(),
      tool_name: data.tool_name || 'unknown',
      file_path: extractFilePath(data.tool_input),
      input_tokens: usage.input_tokens || 0,
      output_tokens: usage.output_tokens || 0,
      cache_read_tokens: usage.cache_read_input_tokens || 0,
      cache_creation_tokens: usage.cache_creation_input_tokens || 0,
      cost_usd: calculateCost(usage),
      session_id: process.env.CLAUDE_SESSION_ID || null,
      model: ACTIVE_MODEL
    };

    const config = loadConfig();

    // Always write locally
    const db = ensureDb();
    const stmt = db.prepare(`
      INSERT INTO usage (
        timestamp, developer, developer_email, project, tool_name, file_path,
        input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens,
        cost_usd, session_id, model
      ) VALUES (
        @timestamp, @developer, @developer_email, @project, @tool_name, @file_path,
        @input_tokens, @output_tokens, @cache_read_tokens, @cache_creation_tokens,
        @cost_usd, @session_id, @model
      )
    `);
    stmt.run(record);

    // Check alert thresholds after inserting
    checkAndNotify(db);

    db.close();

    // Also send to team server if configured
    if (config.remote_url) {
      await sendToRemote(record, config.remote_url);
    }
  } catch (err) {
    // Never crash — silently fail and let Claude Code continue
    process.stderr.write(`[cost-tracker] ${err.message}\n`);
  }
}

main();
