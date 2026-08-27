import type { NextFunction, Request, Response } from 'express';
import { fail } from '../utils/response';
import {
  doubleDecrypt,
  doubleEncrypt,
  isEncryptedEnvelope,
  wantsTransportEncryption,
} from '../utils/transportCrypto';

const SKIP_PATHS = new Set(['/', '/health', '/vpn-gate']);

export function transportEncryptionMiddleware(req: Request, res: Response, next: NextFunction) {
  if (SKIP_PATHS.has(req.path)) return next();
  if (String(req.headers.accept ?? '').includes('text/event-stream')) return next();

  const isApiRoute = req.path.startsWith('/api/');
  const hasEncryptedBody =
    req.body &&
    typeof req.body === 'object' &&
    isEncryptedEnvelope(req.body);
  const useEnc = wantsTransportEncryption(req) || !!hasEncryptedBody;
  const isMultipart = String(req.headers['content-type'] ?? '').includes('multipart/form-data');
  const isJsonRequest = String(req.headers['content-type'] ?? '').includes('application/json');

  if (isApiRoute && !isMultipart && isJsonRequest && !useEnc) {
    return res.status(400).json(fail('Secure transport required'));
  }

  if (useEnc && !isMultipart && req.body && typeof req.body === 'object' && Object.keys(req.body as object).length > 0) {
    if (!isEncryptedEnvelope(req.body)) {
      return res.status(400).json(fail('Encrypted payload required'));
    }
    try {
      const json = doubleDecrypt(req.body.p);
      req.body = json ? JSON.parse(json) : {};
    } catch (err) {
      console.error('Transport decrypt failed', err);
      return res.status(400).json(fail('Invalid encrypted payload'));
    }
  }

  if (!useEnc) return next();

  const origJson = res.json.bind(res);
  res.json = ((body: unknown) => {
    try {
      const payload = doubleEncrypt(JSON.stringify(body ?? null));
      return origJson({ v: 2, p: payload });
    } catch (err) {
      console.error('Failed to encrypt response', err);
      return origJson(fail('Unable to secure response'));
    }
  }) as Response['json'];

  return next();
}
