import { createClient } from 'redis';
import { env } from './env';
import { redisUrlWithTls } from './redisUrl';

export const REDIS_URL = redisUrlWithTls(env.REDIS_URL);

export const redis = createClient({
  url: REDIS_URL,
  pingInterval: 10_000,
  socket: {
    reconnectStrategy: (retries) => Math.min(retries * 100, 3000),
  },
});

redis.on('error', (err) => {
  console.error('Redis error', err);
});

redis.on('reconnecting', () => {
  console.warn('Redis reconnecting…');
});

export async function connectRedis() {
  if (!redis.isOpen) {
    await redis.connect();
  }
}

export function getRedisClient() {
  return redis;
}
