import { z } from 'zod';

const optionalNonEmptyString = z.preprocess((v) => {
  if (v === '') return undefined;
  return v;
}, z.string().min(1).optional());

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).optional(),
  PORT: z.coerce.number().int().positive().default(4000),

  DATABASE_URL: z.string().min(1),
  REDIS_URL: z.string().min(1),

  JWT_SECRET: z.string().min(16),
  ENCRYPTION_KEY: z
    .string()
    .trim()
    .regex(/^[0-9a-fA-F]{64}$/, 'ENCRYPTION_KEY must be 64 hex chars (32 bytes)'),

  /** Single connection string: cloudinary://API_KEY:API_SECRET@CLOUD_NAME */
  CLOUDINARY_URL: z.string().optional(),

  CLOUDINARY_CLOUD_NAME: optionalNonEmptyString,
  CLOUDINARY_API_KEY: optionalNonEmptyString,
  CLOUDINARY_API_SECRET: optionalNonEmptyString,

  CORS_ALLOWED_ORIGINS: z.string().optional(),
  FRONTEND_URL: z.string().default('http://localhost:3000'),

  SMTP_HOST:   z.string().optional(),
  SMTP_PORT:   z.coerce.number().optional().default(587),
  SMTP_SECURE: z.preprocess((v) => v === 'true' || v === true, z.boolean()).optional().default(false),
  SMTP_USER:   z.string().optional(),
  SMTP_PASS:   z.string().optional(),
  SMTP_FROM:   z.string().optional(),
});

export type Env = z.infer<typeof envSchema>;

export const env: Env = envSchema.parse(process.env);

