import { prisma } from '../../config/prisma';
import { connectRedis, redis } from '../../config/redis';

const STAGE_ATTEMPTS = [3, 2, 1] as const;
const LOCK_MS = [15 * 60 * 1000, 60 * 60 * 1000, 0] as const;
const REDIS_TTL_SEC = 60 * 60 * 24 * 30;

export type LockDenial = { error: string; status: 401 | 403 | 429 };

type GuardState = {
  stage: number;
  fails: number;
  lockedUntil: string | null;
  blockedAt: string | null;
};

type LockRow = {
  id: string;
  stage: number | bigint | null;
  fails: number | bigint | null;
  lockedUntil: Date | string | null;
  blockedAt: Date | string | null;
};

function redisKey(id: string) {
  return `login_guard:${id.toLowerCase()}`;
}

function remainingPhrase(until: Date): string {
  const ms = until.getTime() - Date.now();
  if (ms <= 0) return 'a moment';
  const mins = Math.max(1, Math.ceil(ms / 60_000));
  if (mins >= 60) {
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    if (m === 0) return h === 1 ? '1 hour' : `${h} hours`;
    return `${h}h ${m}m`;
  }
  return mins === 1 ? '1 minute' : `${mins} minutes`;
}

function toIso(value: Date | string | null | undefined): string | null {
  if (!value) return null;
  const d = value instanceof Date ? value : new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function fromRow(row: LockRow): GuardState {
  return {
    stage: Number(row.stage ?? 0),
    fails: Number(row.fails ?? 0),
    lockedUntil: toIso(row.lockedUntil),
    blockedAt: toIso(row.blockedAt),
  };
}

async function readRedis(id: string): Promise<GuardState | null> {
  try {
    await connectRedis();
    const raw = await redis.get(redisKey(id));
    if (!raw) return null;
    return JSON.parse(raw) as GuardState;
  } catch {
    return null;
  }
}

async function writeRedis(ids: string[], state: GuardState) {
  try {
    await connectRedis();
    const payload = JSON.stringify(state);
    await Promise.all(ids.filter(Boolean).map((id) => redis.set(redisKey(id), payload, { EX: REDIS_TTL_SEC })));
  } catch {
    // Redis optional — DB still holds known users
  }
}

async function deleteRedis(ids: string[]) {
  try {
    await connectRedis();
    const keys = ids.filter(Boolean).map(redisKey);
    if (keys.length) await redis.del(keys);
  } catch {
    // ignore
  }
}

async function readDb(userId: string): Promise<GuardState | null> {
  try {
    const rows = await prisma.$queryRaw<LockRow[]>`
      SELECT
        id,
        login_lock_stage AS stage,
        login_fail_count AS fails,
        login_locked_until AS "lockedUntil",
        login_blocked_at AS "blockedAt"
      FROM users
      WHERE id = ${userId}
      LIMIT 1
    `;
    return rows[0] ? fromRow(rows[0]) : null;
  } catch (err) {
    console.error('login lock read failed', err);
    return null;
  }
}

async function writeDb(userId: string, state: GuardState) {
  try {
    await prisma.$executeRaw`
      UPDATE users SET
        login_lock_stage = ${state.stage},
        login_fail_count = ${state.fails},
        login_locked_until = ${state.lockedUntil ? new Date(state.lockedUntil) : null},
        login_blocked_at = ${state.blockedAt ? new Date(state.blockedAt) : null}
      WHERE id = ${userId}
    `;
  } catch (err) {
    console.error('login lock write failed', err);
  }
}

function lockedMessage(until: Date): LockDenial {
  return {
    error: `Login is blocked. Try again in ${remainingPhrase(until)}.`,
    status: 429,
  };
}

const BLOCKED: LockDenial = {
  error: 'This ID is blocked. Only an administrator can unblock it from the Users tab.',
  status: 403,
};

function checkState(state: GuardState | null): LockDenial | null {
  if (!state) return null;
  if (state.stage >= 3 || state.blockedAt) return BLOCKED;
  if (state.lockedUntil) {
    const until = new Date(state.lockedUntil);
    if (until.getTime() > Date.now()) return lockedMessage(until);
  }
  return null;
}

export async function assertNotLocked(params: {
  userId?: string | null;
  identifier: string;
}): Promise<LockDenial | null> {
  if (params.userId) {
    const fromDb = await readDb(params.userId);
    if (fromDb) return checkState(fromDb);
  }
  return checkState(await readRedis(params.identifier));
}

function applyFail(state: GuardState): { next: GuardState; message: string; status: 401 | 403 | 429 } {
  let stage = state.stage;
  if (stage > 2) stage = 2;
  const max = STAGE_ATTEMPTS[stage as 0 | 1 | 2];
  const fails = state.fails + 1;

  if (fails < max) {
    const remaining = max - fails;
    const next = { ...state, stage, fails, lockedUntil: null };
    if (stage === 0) {
      return {
        next,
        status: 401,
        message: `${fails}/${max} attempts failed. ${remaining} remaining.`,
      };
    }
    if (stage === 1) {
      return {
        next,
        status: 401,
        message: `Warning: ${fails}/${max} attempts failed. ${remaining} remaining. Next failure blocks login for 1 hour.`,
      };
    }
    return {
      next,
      status: 401,
      message: 'Final attempt failed.',
    };
  }

  if (stage === 0) {
    const until = new Date(Date.now() + LOCK_MS[0]);
    return {
      next: { stage: 1, fails: 0, lockedUntil: until.toISOString(), blockedAt: null },
      status: 429,
      message: '3/3 attempts failed. Login is blocked for 15 minutes. After that you will have 2 attempts.',
    };
  }

  if (stage === 1) {
    const until = new Date(Date.now() + LOCK_MS[1]);
    return {
      next: { stage: 2, fails: 0, lockedUntil: until.toISOString(), blockedAt: null },
      status: 429,
      message: '2/2 attempts failed. Login is blocked for 1 hour. After that you have 1 final chance.',
    };
  }

  return {
    next: { stage: 3, fails: 0, lockedUntil: null, blockedAt: new Date().toISOString() },
    status: 403,
    message: BLOCKED.error,
  };
}

export async function recordLoginFailure(params: {
  userId?: string | null;
  identifier: string;
  aliases?: string[];
}): Promise<LockDenial> {
  let current: GuardState | null = null;
  if (params.userId) current = await readDb(params.userId);
  if (!current) {
    current = (await readRedis(params.identifier)) ?? {
      stage: 0,
      fails: 0,
      lockedUntil: null,
      blockedAt: null,
    };
  }

  const blocked = checkState(current);
  if (blocked && (current.stage >= 3 || (current.lockedUntil && new Date(current.lockedUntil).getTime() > Date.now()))) {
    return blocked;
  }

  const { next, message, status } = applyFail(current);
  const aliases = [params.identifier, ...(params.aliases ?? [])];

  if (params.userId) {
    await writeDb(params.userId, next);
    aliases.push(params.userId);
  }

  await writeRedis(aliases, next);
  return { error: message, status };
}

export async function clearLoginLock(params: { userId?: string | null; aliases: string[] }) {
  if (params.userId) {
    await writeDb(params.userId, { stage: 0, fails: 0, lockedUntil: null, blockedAt: null });
  }
  await deleteRedis([...(params.userId ? [params.userId] : []), ...params.aliases]);
}

export async function loadLocksByUserIds(ids: string[]): Promise<Record<string, ReturnType<typeof lockSummary>>> {
  const out: Record<string, ReturnType<typeof lockSummary>> = {};
  await Promise.all(
    ids.map(async (id) => {
      const state = (await readDb(id)) ?? { stage: 0, fails: 0, lockedUntil: null, blockedAt: null };
      out[id] = lockSummary(state);
    }),
  );
  return out;
}

export function lockSummary(state: GuardState) {
  const lockedUntil = state.lockedUntil ? new Date(state.lockedUntil) : null;
  const stillLocked = lockedUntil != null && lockedUntil.getTime() > Date.now();
  return {
    loginLockStage: state.stage,
    loginFailCount: state.fails,
    loginLockedUntil: lockedUntil?.toISOString() ?? null,
    loginBlockedAt: state.blockedAt,
    loginBlocked: state.stage >= 3 || !!state.blockedAt,
    loginTemporarilyLocked: stillLocked,
  };
}
