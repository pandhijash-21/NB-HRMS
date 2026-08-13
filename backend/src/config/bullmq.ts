import IORedis from 'ioredis';
import { env } from './env';
import { redisUrlWithTls, redisUsesTls } from './redisUrl';

let connection: IORedis | null = null;

export function getBullmqConnection() {
  if (!connection) {
    const url = redisUrlWithTls(env.REDIS_URL);
    connection = new IORedis(url, {
      maxRetriesPerRequest: null,
      enableReadyCheck: false,
      tls: redisUsesTls(url) ? {} : undefined,
      keepAlive: 5000,
      retryStrategy: (times) => Math.min(times * 100, 3000),
    });
    connection.on('error', (err) => {
      console.error('BullMQ Redis error', err);
    });
  }
  return connection;
}
