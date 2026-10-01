#!/usr/bin/env node
// CI gate: every table / column / enum value in schema.prisma must be created by a migration.
// Prod only runs `prisma migrate deploy` since BASELINE_REF; anything in the schema that no
// migration creates (and was not already in the schema at BASELINE_REF, when prod used
// `db push`) is missing on live and crashes the first query that touches it.
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const BASELINE_REF = 'b9ed312';
const ROOT = path.resolve(__dirname, '..');
const SCHEMA_PATH = 'backend/prisma/schema.prisma';
const MIGRATIONS_DIR = path.join(ROOT, 'backend/prisma/migrations');
const SCALARS = new Set(['String', 'Int', 'BigInt', 'Float', 'Decimal', 'Boolean', 'DateTime', 'Json', 'Bytes']);

function parseSchema(text) {
  const models = [];
  const enums = [];
  for (const [, kind, name, body] of text.matchAll(/^(model|enum)\s+(\w+)\s*\{([\s\S]*?)^\}/gm)) {
    const map = body.match(/@@map\("([^"]+)"\)/);
    const dbName = map ? map[1] : name;
    const lines = body.split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('//') && !l.startsWith('@@'));
    if (kind === 'enum') {
      const values = lines.map((l) => {
        const m = l.match(/^(\w+)/);
        const vm = l.match(/@map\("([^"]+)"\)/);
        return vm ? vm[1] : m && m[1];
      }).filter(Boolean);
      enums.push({ name, dbName, values });
    } else {
      const fields = [];
      for (const l of lines) {
        const m = l.match(/^(\w+)\s+(\w+)/);
        if (!m || /@ignore\b/.test(l)) continue;
        const cm = l.match(/@map\("([^"]+)"\)/);
        fields.push({ field: m[1], type: m[2], column: cm ? cm[1] : m[1] });
      }
      models.push({ name, dbName, fields });
    }
  }
  return { models, enums };
}

function parseMigrations() {
  const tables = new Map();
  const enumValues = new Map();
  const addCol = (t, c) => {
    if (!tables.has(t)) tables.set(t, new Set());
    tables.get(t).add(c);
  };
  const addVal = (e, v) => {
    if (!enumValues.has(e)) enumValues.set(e, new Set());
    enumValues.get(e).add(v);
  };
  const dirs = fs.readdirSync(MIGRATIONS_DIR)
    .filter((d) => fs.statSync(path.join(MIGRATIONS_DIR, d)).isDirectory())
    .sort();
  for (const d of dirs) {
    const file = path.join(MIGRATIONS_DIR, d, 'migration.sql');
    if (!fs.existsSync(file)) continue;
    const sql = fs.readFileSync(file, 'utf8').replace(/--.*$/gm, '');

    for (const m of sql.matchAll(/CREATE TABLE\s+(?:IF NOT EXISTS\s+)?(?:"?public"?\.)?"?(\w+)"?\s*\(([\s\S]*?)\n\s*\)\s*;/gi)) {
      if (!tables.has(m[1])) tables.set(m[1], new Set());
      for (const c of m[2].matchAll(/^\s*"?(\w+)"?\s+[A-Za-z"]/gm)) addCol(m[1], c[1]);
    }
    for (const stmt of sql.split(';')) {
      const a = stmt.match(/ALTER TABLE\s+(?:IF EXISTS\s+)?(?:ONLY\s+)?(?:"?public"?\.)?"?(\w+)"?/i);
      if (!a) continue;
      for (const c of stmt.matchAll(/ADD(?:\s+COLUMN)?\s+(?:IF NOT EXISTS\s+)?"?(\w+)"?\s+[A-Za-z"]/gi)) {
        if (!/^(CONSTRAINT|PRIMARY|FOREIGN|UNIQUE|CHECK|VALUE)$/i.test(c[1])) addCol(a[1], c[1]);
      }
      for (const c of stmt.matchAll(/RENAME COLUMN\s+"?(\w+)"?\s+TO\s+"?(\w+)"?/gi)) addCol(a[1], c[2]);
      const r = stmt.match(/RENAME TO\s+"?(\w+)"?/i);
      if (r && !/RENAME COLUMN/i.test(stmt)) {
        tables.set(r[1], new Set([...(tables.get(a[1]) || []), ...(tables.get(r[1]) || [])]));
      }
    }
    for (const m of sql.matchAll(/CREATE TYPE\s+(?:"?public"?\.)?"?(\w+)"?\s+AS ENUM\s*\(([^)]*)\)/gi)) {
      if (!enumValues.has(m[1])) enumValues.set(m[1], new Set());
      for (const v of m[2].matchAll(/'([^']+)'/g)) addVal(m[1], v[1]);
    }
    for (const m of sql.matchAll(/ALTER TYPE\s+(?:"?public"?\.)?"?(\w+)"?\s+ADD VALUE\s+(?:IF NOT EXISTS\s+)?'([^']+)'/gi)) addVal(m[1], m[2]);
    for (const m of sql.matchAll(/ALTER TYPE\s+(?:"?public"?\.)?"?(\w+)"?\s+RENAME VALUE\s+'[^']+'\s+TO\s+'([^']+)'/gi)) addVal(m[1], m[2]);
  }
  return { tables, enumValues };
}

function baselineKeys() {
  let text;
  try {
    text = execFileSync('git', ['show', `${BASELINE_REF}:${SCHEMA_PATH}`], { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  } catch {
    console.error(`Cannot read ${SCHEMA_PATH} at ${BASELINE_REF}. Checkout full history (fetch-depth: 0).`);
    process.exit(2);
  }
  const { models, enums } = parseSchema(text);
  const keys = new Set();
  for (const m of models) {
    keys.add(`T:${m.dbName}`);
    for (const f of m.fields) keys.add(`C:${m.dbName}.${f.column}`);
  }
  for (const e of enums) {
    keys.add(`E:${e.dbName}`);
    for (const v of e.values) keys.add(`V:${e.dbName}.${v}`);
  }
  return keys;
}

const { models, enums } = parseSchema(fs.readFileSync(path.join(ROOT, SCHEMA_PATH), 'utf8'));
const enumNames = new Set(enums.map((e) => e.name));
const { tables, enumValues } = parseMigrations();
const baseline = baselineKeys();
const problems = [];

for (const m of models) {
  if (!tables.has(m.dbName)) {
    if (!baseline.has(`T:${m.dbName}`)) problems.push(`table "${m.dbName}" (model ${m.name})`);
    continue;
  }
  for (const f of m.fields) {
    if (!SCALARS.has(f.type) && !enumNames.has(f.type)) continue;
    if (tables.get(m.dbName).has(f.column) || baseline.has(`C:${m.dbName}.${f.column}`)) continue;
    problems.push(`column "${m.dbName}"."${f.column}" (${m.name}.${f.field})`);
  }
}
for (const e of enums) {
  const have = enumValues.get(e.dbName);
  if (!have) {
    if (!baseline.has(`E:${e.dbName}`)) problems.push(`enum type "${e.dbName}"`);
    continue;
  }
  for (const v of e.values) {
    if (!have.has(v) && !baseline.has(`V:${e.dbName}.${v}`)) problems.push(`enum value "${e.dbName}".'${v}'`);
  }
}

if (problems.length) {
  console.error('schema.prisma has items that no migration creates (they will be missing on prod):');
  for (const p of problems) console.error(`  - ${p}`);
  console.error('\nAdd a migration under backend/prisma/migrations (use IF NOT EXISTS), or add @map(...) if the column already exists under another name.');
  process.exit(1);
}
console.log('Schema coverage check passed: every schema item is created by a migration.');
