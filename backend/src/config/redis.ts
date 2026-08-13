import { createClient } from 'redis';
import { env } from './env';
import { redisUrlWithTls, redisUsesTls } from './redisUrl';

export const REDIS_URL = redisUrlWithTls(env.REDIS_URL);
const useTls = redisUsesTls(REDIS_URL);

export const redis = createClient({
  url: REDIS_URL,
  socket: {
    tls: useTls,
    keepAlive: 5000,
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
