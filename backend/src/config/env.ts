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
  /** Shared with the Flutter client for double AES-GCM transport encryption.
   *  Client-visible protocol key (especially on Flutter Web) — not JWT/DB/SMTP secrecy.
   *  AuthZ still depends on HTTPS + JWT + RBAC.
   */
  TRANSPORT_SECRET: z.string().min(16).default('nb-crm-double-enc-v2-local'),
  ENCRYPTION_KEY: z
    .string()
    .trim()
    .regex(/^[0-9a-fA-F]{64}$/, 'ENCRYPTION_KEY must be 64 hex chars (32 bytes)'),

  /** Single connection string: cloudinary://API_KEY:API_SECRET@CLOUD_NAME */
  CLOUDINARY_URL: optionalNonEmptyString,

  CLOUDINARY_CLOUD_NAME: optionalNonEmptyString,
  CLOUDINARY_API_KEY: optionalNonEmptyString,
  CLOUDINARY_API_SECRET: optionalNonEmptyString,

  CORS_ALLOWED_ORIGINS: z.string().optional(),
  FRONTEND_URL: z.string().default('http://localhost:3000'),

  /** When unset: on in production, off in development. Explicit true/false overrides. */
  VPN_BLOCK_ENABLED: z.preprocess((v) => {
    if (v === undefined || v === '') return undefined;
    if (v === true || v === 'true') return true;
    if (v === false || v === 'false') return false;
    return undefined;
  }, z.boolean().optional()),
  /** Comma-separated public IPs that skip the VPN check (office WAN, etc.). */
  VPN_ALLOW_IPS: z.string().optional(),

  SMTP_HOST:   z.string().optional(),
  SMTP_PORT:   z.coerce.number().optional().default(587),
  SMTP_SECURE: z.preprocess((v) => v === 'true' || v === true, z.boolean()).optional().default(false),
  SMTP_USER:   z.string().optional(),
  SMTP_PASS:   z.string().optional(),
  SMTP_FROM:   z.string().optional(),

  /** eTimeOffice HTTP attendance API (optional / other sites). */
  ETIMEOFFICE_BASE_URL: z.string().default('https://api.etimeoffice.com'),
  ETIMEOFFICE_CORPORATE_ID: optionalNonEmptyString,
  ETIMEOFFICE_USERNAME: optionalNonEmptyString,
  ETIMEOFFICE_PASSWORD: optionalNonEmptyString,

  /** PayTime / Mantra MSSQL dump (primary machine source for this site). */
  MSSQL_HOST: optionalNonEmptyString,
  MSSQL_INSTANCE: optionalNonEmptyString,
  MSSQL_PORT: z.coerce.number().int().positive().default(1433),
  MSSQL_DB: optionalNonEmptyString,
  MSSQL_USER: optionalNonEmptyString,
  MSSQL_PASSWORD: optionalNonEmptyString,
  MSSQL_TABLE: z.string().default('tmpDmpTerminalData'),
  MSSQL_ENCRYPT: z.preprocess((v) => v === 'true' || v === true, z.boolean()).default(false),
  MSSQL_TRUST_SERVER_CERT: z
    .preprocess((v) => v === undefined || v === '' || v === 'true' || v === true, z.boolean())
    .default(true),
  /** Optional overrides if auto column detect fails */
  MSSQL_PUNCH_ID_COLUMN: optionalNonEmptyString,
  MSSQL_PUNCH_AT_COLUMN: optionalNonEmptyString,
  MSSQL_TERMINAL_COLUMN: optionalNonEmptyString,
  MSSQL_MODE_COLUMN: optionalNonEmptyString,

  /** LiveKit (voice/video/screen). Defaults match `livekit-server --dev`. */
  LIVEKIT_URL: z.string().default('http://127.0.0.1:7880'),
  LIVEKIT_PUBLIC_URL: optionalNonEmptyString,
  LIVEKIT_API_KEY: z.string().default('devkey'),
  LIVEKIT_API_SECRET: z.string().default('secret'),

  /** MinIO S3-compatible storage for chat/meet files. Falls back to Cloudinary/local. */
  MINIO_ENDPOINT: optionalNonEmptyString,
  MINIO_PORT: z.coerce.number().int().positive().default(9000),
  MINIO_ACCESS_KEY: optionalNonEmptyString,
  MINIO_SECRET_KEY: optionalNonEmptyString,
  MINIO_BUCKET: z.string().default('crm-files'),
  MINIO_USE_SSL: z.preprocess((v) => v === 'true' || v === true, z.boolean()).default(false),
  MINIO_PUBLIC_URL: optionalNonEmptyString,
  /** Hostname LiveKit egress uses to reach MinIO (docker service name, not localhost). */
  MINIO_EGRESS_ENDPOINT: optionalNonEmptyString,

  /** Optional OpenAI key for meeting AI summaries. Transcript fallback if unset. */
  OPENAI_API_KEY: optionalNonEmptyString,
  OPENAI_MODEL: z.string().default('gpt-4o-mini'),

  CLAMAV_HOST: optionalNonEmptyString,
  CLAMAV_PORT: z.coerce.number().int().positive().default(3310),
})

export type Env = z.infer<typeof envSchema>;

export const env: Env = envSchema.parse(process.env);

