import crypto from 'crypto';
import { env } from '../config/env';

const HEADER = 'x-nb-enc';
export const TRANSPORT_ENC_VERSION = 2;

function deriveKey(secret: string, layer: 'inner' | 'outer'): Buffer {
  return crypto.createHash('sha256').update(`${secret}|${layer}|v2`).digest();
}

function innerKey() {
  return deriveKey(env.TRANSPORT_SECRET, 'inner');
}

function outerKey() {
  return deriveKey(env.TRANSPORT_SECRET, 'outer');
}

function aesGcmEncrypt(key: Buffer, plaintext: Buffer): Buffer {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, encrypted]);
}

function aesGcmDecrypt(key: Buffer, blob: Buffer): Buffer {
  if (blob.length < 29) throw new Error('Invalid encrypted payload');
  const iv = blob.subarray(0, 12);
  const tag = blob.subarray(12, 28);
  const encrypted = blob.subarray(28);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(encrypted), decipher.final()]);
}

export function doubleEncrypt(plaintext: string): string {
  const inner = aesGcmEncrypt(innerKey(), Buffer.from(plaintext, 'utf8'));
  const outer = aesGcmEncrypt(outerKey(), inner);
  return outer.toString('base64');
}

export function doubleDecrypt(payload: string): string {
  const outer = aesGcmDecrypt(outerKey(), Buffer.from(payload, 'base64'));
  return aesGcmDecrypt(innerKey(), outer).toString('utf8');
}

export function wantsTransportEncryption(req: { headers: Record<string, unknown> }): boolean {
  const raw = req.headers[HEADER] ?? req.headers[HEADER.toUpperCase()];
  const value = Array.isArray(raw) ? raw[0] : raw;
  return String(value ?? '') === String(TRANSPORT_ENC_VERSION);
}

export function isEncryptedEnvelope(body: unknown): body is { v: number; p: string } {
  return (
    !!body &&
    typeof body === 'object' &&
    (body as { v?: unknown }).v === TRANSPORT_ENC_VERSION &&
    typeof (body as { p?: unknown }).p === 'string'
  );
}
