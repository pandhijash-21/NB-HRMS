import IORedis from 'ioredis';
import { env } from './env';

let connection: IORedis | null = null;

export function getBullmqConnection() {
  if (!connection) {
    connection = new IORedis(env.REDIS_URL, {
      maxRetriesPerRequest: null,
      enableReadyCheck: false,
    });
  }
  return connection;
}

