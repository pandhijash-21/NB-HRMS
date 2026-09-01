import { env } from '../config/env';

const configuredCorsOrigins =
  env.CORS_ALLOWED_ORIGINS?.split(',')
    .map((o) => o.trim())
    .filter(Boolean) ?? ['http://localhost:3000', 'http://localhost:9695'];

/** Allow configured origins, localhost (dev), Vercel, Netlify, and prod CRM host. */
export function isAllowedCorsOrigin(origin: string | undefined): boolean {
  if (!origin) return true;
  if (configuredCorsOrigins.includes(origin)) return true;
  if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) return true;
  if (/^https:\/\/([a-z0-9-]+\.)*vercel\.app$/i.test(origin)) return true;
  if (/^https:\/\/([a-z0-9-]+\.)*netlify\.app$/i.test(origin)) return true;
  if (/^https:\/\/crm\.nbdeveloper\.co\.in$/i.test(origin)) return true;
  return false;
}

export function allowedCorsOriginList(): string[] {
  const set = new Set(configuredCorsOrigins);
  set.add('https://crm.nbdeveloper.co.in');
  return [...set];
}
