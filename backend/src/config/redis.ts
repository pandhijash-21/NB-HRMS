import { createClient } from 'redis';
import { env } from './env';
import { redisUrlWithTls } from './redisUrl';

export const REDIS_URL = redisUrlWithTls(env.REDIS_URL);

const CONNECT_TIMEOUT_MS = 2500;
const STARTUP_RETRIES = 3;

let everConnected = false;
let loggedRedisError = false;

export const redis = createClient({
  url: REDIS_URL,
  pingInterval: 10_000,
  socket: {
    connectTimeout: CONNECT_TIMEOUT_MS,
    reconnectStrategy: (retries) => {
      // Do not block process startup when Redis (Docker) is down.
      if (!everConnected && retries >= STARTUP_RETRIES) return false;
      if (everConnected && retries >= 20) return false;
      return Math.min(retries * 200, 2000);
    },
  },
});

redis.on('error', (err) => {
  if (loggedRedisError) return;
  loggedRedisError = true;
  const msg = err instanceof Error ? err.message : String(err);
  console.error('Redis error', msg);
});

redis.on('reconnecting', () => {
  if (!everConnected) return;
  console.warn('Redis reconnecting…');
});

redis.on('ready', () => {
  everConnected = true;
  loggedRedisError = false;
});

export async function connectRedis() {
  if (redis.isOpen) return;
  await Promise.race([
    redis.connect(),
    new Promise<never>((_, reject) => {
      setTimeout(
        () => reject(new Error(`Redis connect timed out after ${CONNECT_TIMEOUT_MS}ms`)),
        CONNECT_TIMEOUT_MS,
      );
    }),
  ]);
}

export function getRedisClient() {
  return redis;
}
