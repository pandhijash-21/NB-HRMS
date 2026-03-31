import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { sseService } from './sse.service';

export const eventsRouter = Router();

/**
 * GET /api/events/stream?token=<jwt>
 * Authenticated SSE stream — each logged-in user keeps one persistent connection.
 * Token can be passed as query param since EventSource cannot set custom headers.
 */
eventsRouter.get('/stream', (req, res, next) => {
  // Allow token via query string for EventSource (which can't set headers)
  if (req.query.token && !req.headers.authorization) {
    req.headers.authorization = `Bearer ${req.query.token}`;
  }
  next();
}, requireAuth, (req, res) => {
  const userId = req.user!.id;
  const employeeId = req.user!.employeeId ? Number(req.user!.employeeId) : null;
  const role = req.user!.role ?? 'EMPLOYEE';

  // SSE headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no'); // disable nginx buffering
  res.flushHeaders();

  // Register client
  sseService.add(userId, { userId, employeeId, role, res });

  // Send initial ping so client knows connection is live
  res.write(`event: connected\ndata: ${JSON.stringify({ userId, employeeId, role })}\n\n`);

  // Heartbeat every 25s to keep connection alive through proxies
  const heartbeat = setInterval(() => {
    try { res.write(': ping\n\n'); } catch { clearInterval(heartbeat); }
  }, 25_000);

  // Cleanup on disconnect
  req.on('close', () => {
    clearInterval(heartbeat);
    sseService.remove(userId);
  });
});
