import dotenv from 'dotenv';
dotenv.config();

// IMPORTANT: load env AFTER dotenv.config() runs.
// Using require here avoids ESM import hoisting ordering issues in tsx/nodemon.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { app } = require('./app') as typeof import('./app');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { env } = require('./config/env') as typeof import('./config/env');

app.listen(env.PORT, () => {
  console.log(`Server running on port ${env.PORT}`);
});

export default app;
