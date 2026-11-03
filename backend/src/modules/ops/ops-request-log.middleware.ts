import type { NextFunction, Request, Response } from 'express';
import { pushLiveLog } from './live-log';

const SKIP = new Set([
  '/health',
  '/system-health',
  '/system-health.html',
  '/docs',
  '/api/ops/live-logs',
  '/api/ops/dashboard',
]);

export function opsRequestLogMiddleware(req: Request, res: Response, next: NextFunction) {
  const path = req.path || req.url || '';
  if (SKIP.has(path) || path.startsWith('/socket')) return next();

  const t0 = Date.now();
  res.on('finish', () => {
    try {
      const user = (req as any).user;
      pushLiveLog({
        method: req.method,
        path: path.length > 180 ? `${path.slice(0, 180)}…` : path,
        status: res.statusCode,
        ms: Date.now() - t0,
        userId: user?.id,
        userRole: user?.role,
        employeeId: user?.employeeId,
        ip: req.ip,
        scope: String(req.headers['x-crm-scope'] || ''),
      });
    } catch {
      /* never break requests */
    }
  });
  next();
}
