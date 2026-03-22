import dotenv from 'dotenv';
dotenv.config();

// IMPORTANT: load env AFTER dotenv.config() runs.
// Using require here avoids ESM import hoisting ordering issues in tsx/nodemon.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { app } = require('./app') as typeof import('./app');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { env } = require('./config/env') as typeof import('./config/env');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { connectRedis } = require('./config/redis') as typeof import('./config/redis');

async function start() {
  try {
    await connectRedis();
    console.log('Redis connected');
  } catch (err) {
    console.warn('Redis unavailable on startup — sessions will be JWT-only:', err);
  }

  app.listen(env.PORT, () => {
    console.log(`Server running on port ${env.PORT}`);
  });
}

start();

export default app;
