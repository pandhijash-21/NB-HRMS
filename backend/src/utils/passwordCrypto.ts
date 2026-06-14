import crypto from 'crypto';
import { env } from '../config/env';

const ALGO = 'aes-256-gcm';

function getKey(): Buffer {
  return crypto.createHash('sha256').update(env.JWT_SECRET).digest();
}

/** Reversible store for admin password viewing (encrypted at rest). */
export function encryptPasswordForAdmin(plain: string): string {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGO, getKey(), iv);
  const enc = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('base64')}:${tag.toString('base64')}:${enc.toString('base64')}`;
}

export function decryptPasswordForAdmin(stored: string | null | undefined): string | null {
  if (!stored) return null;
  try {
    const [ivB, tagB, dataB] = stored.split(':');
    if (!ivB || !tagB || !dataB) return null;
    const decipher = crypto.createDecipheriv(ALGO, getKey(), Buffer.from(ivB, 'base64'));
    decipher.setAuthTag(Buffer.from(tagB, 'base64'));
    return Buffer.concat([
      decipher.update(Buffer.from(dataB, 'base64')),
      decipher.final(),
    ]).toString('utf8');
  } catch {
    return null;
  }
}
