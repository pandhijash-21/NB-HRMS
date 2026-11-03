import fs from 'fs';
import path from 'path';
import { spawn } from 'child_process';
import { env } from '../../config/env';

const BACKUP_DIR = path.resolve(process.cwd(), 'backups', 'db');
const RETAIN_DAYS = 14;

export type BackupInfo = {
  fileName: string;
  path: string;
  sizeBytes: number;
  createdAt: string;
};

function ensureDir() {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
}

function parseDatabaseUrl(url: string) {
  const u = new URL(url);
  return {
    host: u.hostname,
    port: u.port || '5432',
    user: decodeURIComponent(u.username),
    password: decodeURIComponent(u.password),
    database: u.pathname.replace(/^\//, '').split('?')[0],
  };
}

export function listLocalBackups(): BackupInfo[] {
  ensureDir();
  const files = fs
    .readdirSync(BACKUP_DIR)
    .filter((f) => f.endsWith('.sql') || f.endsWith('.sql.gz') || f.endsWith('.dump'));
  return files
    .map((fileName) => {
      const full = path.join(BACKUP_DIR, fileName);
      const st = fs.statSync(full);
      return {
        fileName,
        path: full,
        sizeBytes: st.size,
        createdAt: st.mtime.toISOString(),
      };
    })
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

function pruneOldBackups() {
  const cutoff = Date.now() - RETAIN_DAYS * 24 * 60 * 60 * 1000;
  for (const b of listLocalBackups()) {
    if (new Date(b.createdAt).getTime() < cutoff) {
      try {
        fs.unlinkSync(b.path);
      } catch {
        /* ignore */
      }
    }
  }
}

export async function runLocalDbBackup(reason = 'manual'): Promise<BackupInfo> {
  ensureDir();
  const db = parseDatabaseUrl(env.DATABASE_URL);
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const fileName = `nb-hrms-${stamp}-${reason}.sql`;
  const outPath = path.join(BACKUP_DIR, fileName);

  await new Promise<void>((resolve, reject) => {
    const args = [
      '-h',
      db.host,
      '-p',
      db.port,
      '-U',
      db.user,
      '-d',
      db.database,
      '--no-owner',
      '--no-acl',
      '-f',
      outPath,
    ];
    const child = spawn('pg_dump', args, {
      env: { ...process.env, PGPASSWORD: db.password },
      windowsHide: true,
    });
    let stderr = '';
    child.stderr.on('data', (d) => {
      stderr += String(d);
    });
    child.on('error', (err) => {
      reject(
        new Error(
          `pg_dump failed to start (${err.message}). Ensure PostgreSQL client tools are on PATH.`,
        ),
      );
    });
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`pg_dump exited ${code}: ${stderr.slice(0, 500)}`));
    });
  });

  pruneOldBackups();
  const st = fs.statSync(outPath);
  return {
    fileName,
    path: outPath,
    sizeBytes: st.size,
    createdAt: st.mtime.toISOString(),
  };
}

let backupTimer: NodeJS.Timeout | null = null;

export function startDailyBackupScheduler() {
  if (backupTimer) return;
  const tick = async () => {
    try {
      const latest = listLocalBackups()[0];
      const ageMs = latest ? Date.now() - new Date(latest.createdAt).getTime() : Infinity;
      if (ageMs > 20 * 60 * 60 * 1000) {
        const info = await runLocalDbBackup('daily');
        // eslint-disable-next-line no-console
        console.log(`[ops-backup] daily backup ok: ${info.fileName} (${info.sizeBytes} bytes)`);
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('[ops-backup] daily backup failed:', err instanceof Error ? err.message : err);
    }
  };
  // Check shortly after boot, then hourly
  setTimeout(() => void tick(), 45_000);
  backupTimer = setInterval(() => void tick(), 60 * 60 * 1000);
}
