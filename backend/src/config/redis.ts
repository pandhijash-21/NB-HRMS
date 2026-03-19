import { createClient } from 'redis';
import { env } from './env';

export const redis = createClient({ url: env.REDIS_URL });

redis.on('error', (err) => {
  // keep process alive; callers should handle unavailable redis gracefully
  console.error('Redis error', err);
});

export async function connectRedis() {
  if (!redis.isOpen) {
    await redis.connect();
  }
}

