#!/usr/bin/env node
import { readFileSync, existsSync, writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';
import { DatabaseSync } from 'node:sqlite';

const HOME = process.env.HOME || '/home/ecb';
const DB_PATH = join(HOME, '.local/share/opencode/opencode.db');
const GO_CONFIG_PATH = join(HOME, '.config/opencode/opencode-quota/opencode-go.json');

function formatTokens(n) {
  n = Number(n) || 0;
  if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
  if (n >= 1000) return Math.round(n / 1000) + 'K';
  return String(n);
}

const data = {
  daily: { tok: 0, sess: 0, in: 0, out: 0, reas: 0, cr: 0, cw: 0 },
  weekly: { tok: 0, sess: 0, in: 0, out: 0, reas: 0, cr: 0, cw: 0 },
  monthly: { tok: 0, sess: 0, in: 0, out: 0, reas: 0, cr: 0, cw: 0 },
};

if (existsSync(DB_PATH)) {
  try {
    const db = new DatabaseSync(DB_PATH);
    const nowMs = Date.now();
    const queries = [
      { ms: nowMs - 86400000, store: data.daily },
      { ms: nowMs - 604800000, store: data.weekly },
      { ms: nowMs - 2592000000, store: data.monthly },
    ];

    for (const q of queries) {
      const rows = db.prepare(`SELECT
        COALESCE(SUM(tokens_input),0) as ti,
        COALESCE(SUM(tokens_output),0) as to_,
        COALESCE(SUM(tokens_reasoning),0) as tr,
        COALESCE(SUM(tokens_cache_read),0) as tcr,
        COALESCE(SUM(tokens_cache_write),0) as tcw,
        COUNT(*) as cnt
        FROM session WHERE time_created >= ?`).all(q.ms);
      const r = rows[0];
      q.store.tok = Number(r.ti) + Number(r.to_) + Number(r.tr) + Number(r.tcr) + Number(r.tcw);
      q.store.sess = Number(r.cnt);
      q.store.in = Number(r.ti);
      q.store.out = Number(r.to_);
      q.store.reas = Number(r.tr);
      q.store.cr = Number(r.tcr);
      q.store.cw = Number(r.tcw);
    }
    db.close();
  } catch (e) {
  }
}

let goPercentRemaining = null;

if (existsSync(GO_CONFIG_PATH)) {
  try {
    const goConfig = JSON.parse(readFileSync(GO_CONFIG_PATH, 'utf-8'));
    const wsId = goConfig.workspaceId?.trim();
    const authCookie = goConfig.authCookie?.trim();

    if (wsId && authCookie) {
      const url = `https://opencode.ai/workspace/${encodeURIComponent(wsId)}/go`;
      const res = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Gecko/20100101 Firefox/148.0',
          Accept: 'text/html',
          Cookie: `auth=${authCookie}`,
        },
        signal: AbortSignal.timeout(10000),
      });

      if (res.ok) {
        const html = await res.text();
        const resetFirst = /monthlyUsage:\s*\$R\[\d+\]=\{[^}]*resetInSec:(\d+)[^}]*usagePercent:(\d+)[^}]*\}/;
        const pctFirst = /monthlyUsage:\s*\$R\[\d+\]=\{[^}]*usagePercent:(\d+)[^}]*resetInSec:(\d+)[^}]*\}/;
        const match = resetFirst.exec(html) || pctFirst.exec(html);

        if (match) {
          const a = Number(match[1]);
          const b = Number(match[2]);
          const usagePercent = a <= 100 && a >= 0 ? a : b <= 100 && b >= 0 ? b : 0;
          goPercentRemaining = 100 - Math.max(0, usagePercent);
        }
      }
    }
  } catch (e) {
  }
}

const dLabel = formatTokens(data.daily.tok);
const wLabel = formatTokens(data.weekly.tok);
const mLabel = formatTokens(data.monthly.tok);

let barText = `<span font_weight="bold" foreground="#df6124" letter_spacing="1">▌OC▐</span> D:${dLabel}`;
if (data.weekly.tok > 0) barText += ` W:${wLabel}`;
if (data.monthly.tok > 0) barText += ` M:${mLabel}`;
if (goPercentRemaining != null) barText += `  ${goPercentRemaining}%`;

let tooltip = `<b>OpenCode</b>\n`;

tooltip += `\n<b>Today</b> (${data.daily.sess} sessions)\n`;
tooltip += `  Input:    ${formatTokens(data.daily.in)}\n`;
tooltip += `  Output:   ${formatTokens(data.daily.out)}\n`;
if (data.daily.reas > 0) tooltip += `  Reasoning: ${formatTokens(data.daily.reas)}\n`;
tooltip += `  Cache R/W: ${formatTokens(data.daily.cr)}/${formatTokens(data.daily.cw)}\n`;
tooltip += `  Total:    <b>${dLabel}</b>\n`;

tooltip += `\n<b>This Week</b> (${data.weekly.sess} sessions)\n`;
tooltip += `  Input:    ${formatTokens(data.weekly.in)}\n`;
tooltip += `  Output:   ${formatTokens(data.weekly.out)}\n`;
if (data.weekly.reas > 0) tooltip += `  Reasoning: ${formatTokens(data.weekly.reas)}\n`;
tooltip += `  Cache R/W: ${formatTokens(data.weekly.cr)}/${formatTokens(data.weekly.cw)}\n`;
tooltip += `  Total:    <b>${wLabel}</b>\n`;

tooltip += `\n<b>This Month</b> (${data.monthly.sess} sessions)\n`;
tooltip += `  Input:    ${formatTokens(data.monthly.in)}\n`;
tooltip += `  Output:   ${formatTokens(data.monthly.out)}\n`;
if (data.monthly.reas > 0) tooltip += `  Reasoning: ${formatTokens(data.monthly.reas)}\n`;
tooltip += `  Cache R/W: ${formatTokens(data.monthly.cr)}/${formatTokens(data.monthly.cw)}\n`;
tooltip += `  Total:    <b>${mLabel}</b>\n`;

if (goPercentRemaining != null) {
  const bar = '█'.repeat(Math.round(goPercentRemaining * 12 / 100)) + '░'.repeat(12 - Math.round(goPercentRemaining * 12 / 100));
  tooltip += `\n<b>Monthly Quota:</b> ${bar} ${goPercentRemaining}%\n`;
}

console.log(JSON.stringify({ text: barText, tooltip, class: 'available' }));
