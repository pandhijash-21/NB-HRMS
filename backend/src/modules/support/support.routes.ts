import fs from 'fs';
import path from 'path';
import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, type PermissionAction } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { supportService } from './support.service';

export const supportRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

function normalizeRole(raw: unknown): string {
  return String(raw ?? '')
    .toUpperCase()
    .replace(/[\s_-]+/g, '');
}

/** Admin / System Admin can configure who receives Support tickets. */
export function canManageSupportHandlers(req: Request): boolean {
  if ((req.user as any)?.companyAdminGranted === true) return true;
  const role = normalizeRole((req.user as any)?.roleName ?? (req.user as any)?.role);
  return [
    'ADMIN',
    'SYSTEMADMIN',
    'SYSTEMADMINISTRATOR',
    'SUPERADMIN',
  ].includes(role);
}

/** Role-based IT (used when no assignees configured, and as admin override). */
function isRolePrivilegedSupportIt(req: Request): boolean {
  const role = normalizeRole((req.user as any)?.roleName ?? (req.user as any)?.role);
  if (
    [
      'ADMIN',
      'HR',
      'HRMANAGER',
      'SYSTEMADMIN',
      'SYSTEMADMINISTRATOR',
      'SUPERADMIN',
    ].includes(role)
  ) {
    return true;
  }
  if ((req.user as any)?.companyAdminGranted === true) return true;
  const perms = (req.user as any)?.permissions as Record<string, string[]> | undefined;
  const actions = perms?.SUPPORT ?? perms?.support ?? [];
  return actions.map((a) => String(a).toUpperCase()).includes('APPROVE');
}

/** IT queue: assigned handlers, or role fallback / Admin when managing. */
export async function isSupportIt(req: Request): Promise<boolean> {
  const caps = await supportService.capabilities({
    employeeId:
      req.user?.employeeId != null && Number.isFinite(Number(req.user.employeeId))
        ? Number(req.user.employeeId)
        : null,
    rolePrivileged: isRolePrivilegedSupportIt(req),
    canManageHandlers: canManageSupportHandlers(req),
  });
  return caps.isIt;
}

/** Asserts that caller is either Admin OR the specific IT handler assigned to this ticket. */
async function assertCanManageTicket(req: Request, ticketId: string) {
  const isAdmin = canManageSupportHandlers(req);
  if (isAdmin) return;
  const isIt = await isSupportIt(req);
  if (!isIt) throw new Error('Only IT Support or Admin can manage tickets');
  const employeeId =
    req.user?.employeeId != null && Number.isFinite(Number(req.user.employeeId))
      ? Number(req.user.employeeId)
      : null;
  const ticket = await supportService.getById(ticketId);
  if (!employeeId || (ticket.assignedHandlerId !== employeeId && ticket.transferTargetHandlerId !== employeeId)) {
    throw new Error('Only the assigned IT handler can manage this ticket');
  }
}

const getStandaloneExePath = () => {
  const p1 = path.resolve(__dirname, '../../../public/downloads/NB-RemoteSupport.exe');
  if (fs.existsSync(p1)) return p1;
  const p2 = path.resolve(process.cwd(), 'public/downloads/NB-RemoteSupport.exe');
  if (fs.existsSync(p2)) return p2;
  return null;
};

// Standalone Remote Desktop binary (Option B - Native AnyDesk/RustDesk zero-streaming software)
supportRouter.get('/agent.exe', (req: Request, res: Response) => {
  const exePath = getStandaloneExePath();
  if (exePath) {
    return res.download(exePath, 'NB-RemoteSupport.exe');
  }
  return res.redirect('https://github.com/rustdesk/rustdesk/releases/download/1.5.3/rustdesk-1.5.3-x86_64.exe');
});

supportRouter.get('/:id/remote/agent.exe', (req: Request, res: Response) => {
  const exePath = getStandaloneExePath();
  if (exePath) {
    return res.download(exePath, 'NB-RemoteSupport.exe');
  }
  return res.redirect('https://github.com/rustdesk/rustdesk/releases/download/1.5.3/rustdesk-1.5.3-x86_64.exe');
});

// Windows Native Support Agent endpoints (Option 1 - unauthenticated helper script & command polling)
supportRouter.get('/:id/remote/agent.bat', (req: Request, res: Response) => {
  const ticketId = p(req.params.id);
  const host = req.get('host') || 'crm.nbsince1946.com';
  const proto = req.protocol === 'https' || req.get('x-forwarded-proto') === 'https' ? 'https' : 'http';
  const serverUrl = `${proto}://${host}`;
  const bat = `@echo off
title NB-HRMS Remote Support Agent - ${ticketId}
echo ==========================================================
echo Starting NB-HRMS Quick Support Agent for Ticket: ${ticketId}
echo ==========================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $script = (Invoke-WebRequest -Uri '${serverUrl}/api/support/${ticketId}/remote/agent.ps1' -UseBasicParsing).Content; Invoke-Expression $script"
pause
`;
  res.setHeader('Content-Type', 'application/x-bat');
  res.setHeader('Content-Disposition', `attachment; filename="launch-support-agent-${ticketId}.bat"`);
  return res.send(bat);
});

supportRouter.get('/:id/remote/agent.ps1', (req: Request, res: Response) => {
  const ticketId = p(req.params.id);
  const host = req.get('host') || 'crm.nbsince1946.com';
  const proto = req.protocol === 'https' || req.get('x-forwarded-proto') === 'https' ? 'https' : 'http';
  const serverUrl = `${proto}://${host}`;
  const script = supportService.generateAgentScript(ticketId, serverUrl);
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="nb-support-agent-${ticketId}.ps1"`);
  return res.send(script);
});

supportRouter.get('/:id/remote/commands', (req: Request, res: Response) => {
  const ticketId = p(req.params.id);
  const commands = supportService.popRemoteCommands(ticketId);
  return res.json(ok(commands));
});

supportRouter.get('/:id/remote/agent-status', (req: Request, res: Response) => {
  const ticketId = p(req.params.id);
  const status = supportService.getAgentStatus(ticketId);
  return res.json(ok(status));
});

supportRouter.use(requireAuth);
supportRouter.use((req, res, next) => {
  const action: PermissionAction = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)
    ? 'WRITE'
    : 'READ';
  if (
    req.path === '/queue' ||
    req.path === '/queue/status' ||
    req.path === '/handlers' ||
    req.path === '/capabilities' ||
    req.path.endsWith('/review') ||
    req.path.endsWith('/resolve') ||
    req.path.endsWith('/force-close') ||
    req.path.endsWith('/assign') ||
    req.path.endsWith('/messages') ||
    req.path.includes('/transfer') ||
    req.path.includes('/remote')
  ) {
    return requirePermission('SUPPORT', 'READ')(req, res, next);
  }
  return requirePermission('SUPPORT', action)(req, res, next);
});

supportRouter.get('/capabilities', async (req: Request, res: Response) => {
  try {
    const employeeId =
      req.user!.employeeId != null && Number.isFinite(Number(req.user!.employeeId))
        ? Number(req.user!.employeeId)
        : null;
    const data = await supportService.capabilities({
      employeeId,
      rolePrivileged: isRolePrivilegedSupportIt(req),
      canManageHandlers: canManageSupportHandlers(req),
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.get('/handlers', async (req: Request, res: Response) => {
  try {
    // Anyone who can act as IT (or manage) may see who is assigned.
    if (!(await isSupportIt(req)) && !canManageSupportHandlers(req)) {
      return res.status(403).json(fail('Not allowed to view Support handlers'));
    }
    const data = await supportService.listHandlers();
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.put('/handlers', async (req: Request, res: Response) => {
  try {
    if (!canManageSupportHandlers(req)) {
      return res.status(403).json(fail('Only Admin can assign Support handlers'));
    }
    const raw = req.body?.employeeIds ?? req.body?.employeeId ?? [];
    const employeeIds = Array.isArray(raw)
      ? raw.map((v: unknown) => Number(v))
      : [Number(raw)];
    const data = await supportService.setHandlers({
      employeeIds,
      actorId: String(req.user!.id),
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.post('/', async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId || !Number.isFinite(employeeId)) {
      return res.status(400).json(fail('Employee profile is required to raise a ticket'));
    }
    const ticket = await supportService.create({
      employeeId,
      createdBy: String(req.user!.id),
      title: String(req.body?.title ?? ''),
      description: String(req.body?.description ?? ''),
      photoUrl: req.body?.photoUrl != null ? String(req.body.photoUrl) : null,
      assignedHandlerId:
        req.body?.assignedHandlerId != null && Number.isFinite(Number(req.body.assignedHandlerId))
          ? Number(req.body.assignedHandlerId)
          : null,
    });
    return res.status(201).json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.get('/my', async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId || !Number.isFinite(employeeId)) {
      return res.json(ok([]));
    }
    const data = await supportService.listMine(employeeId);
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.get('/queue', async (req: Request, res: Response) => {
  try {
    if (!(await isSupportIt(req))) {
      return res.status(403).json(fail('Only IT Support can view the queue'));
    }
    const includeClosed =
      req.query.includeClosed === 'true' || req.query.includeClosed === '1';
    const isAdmin = canManageSupportHandlers(req);
    const employeeId =
      req.user?.employeeId != null && Number.isFinite(Number(req.user.employeeId))
        ? Number(req.user.employeeId)
        : null;

    const data = await supportService.listQueue({
      includeClosed,
      employeeId,
      isAdmin,
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const employeeId = req.user!.employeeId != null ? Number(req.user!.employeeId) : null;
    const ticket = await supportService.assertCanView(p(req.params.id), {
      userId: String(req.user!.id),
      employeeId: employeeId && Number.isFinite(employeeId) ? employeeId : null,
      isIt: await isSupportIt(req),
      isAdmin: canManageSupportHandlers(req),
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    const msg = e.message ?? 'Failed';
    return res.status(msg === 'Ticket not found' ? 404 : 403).json(fail(msg));
  }
});

supportRouter.patch('/:id/review', async (req: Request, res: Response) => {
  try {
    const ticketId = p(req.params.id);
    await assertCanManageTicket(req, ticketId);
    const ticket = await supportService.setInReview({
      ticketId,
      actorId: String(req.user!.id),
      etaAt: req.body?.etaAt ?? req.body?.eta,
      note: req.body?.note != null ? String(req.body.note) : null,
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.patch('/:id/resolve', async (req: Request, res: Response) => {
  try {
    const ticketId = p(req.params.id);
    await assertCanManageTicket(req, ticketId);
    const ticket = await supportService.markResolved({
      ticketId,
      actorId: String(req.user!.id),
      remarks: String(req.body?.remarks ?? req.body?.resolveRemarks ?? ''),
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.patch('/:id/confirm', async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId || !Number.isFinite(employeeId)) {
      return res.status(400).json(fail('Employee profile required'));
    }
    const ticket = await supportService.confirm({
      ticketId: p(req.params.id),
      actorId: String(req.user!.id),
      employeeId,
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.patch('/:id/deny', async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId || !Number.isFinite(employeeId)) {
      return res.status(400).json(fail('Employee profile required'));
    }
    const ticket = await supportService.deny({
      ticketId: p(req.params.id),
      actorId: String(req.user!.id),
      employeeId,
      note: req.body?.note != null ? String(req.body.note) : null,
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.get('/queue/status', async (req: Request, res: Response) => {
  try {
    const data = await supportService.getQueueStatus();
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// ==========================================
// TICKET MESSAGES / LIVE CHAT
// ==========================================
supportRouter.get('/:id/messages', async (req: Request, res: Response) => {
  try {
    const ticketId = p(req.params.id);
    const messages = await supportService.listMessages(ticketId);
    return res.json(ok(messages));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.post('/:id/messages', async (req: Request, res: Response) => {
  try {
    const ticketId = p(req.params.id);
    const ticket = await supportService.getById(ticketId);
    const employeeId =
      req.user?.employeeId != null && Number.isFinite(Number(req.user.employeeId))
        ? Number(req.user.employeeId)
        : null;
    const isOwner = employeeId != null && ticket.employeeId === employeeId;
    const isAssigned =
      employeeId != null &&
      (ticket.assignedHandlerId === employeeId || ticket.transferTargetHandlerId === employeeId);
    const isAdmin = canManageSupportHandlers(req);

    if (!isOwner && !isAssigned && !isAdmin) {
      return res.status(403).json(fail('You are not authorized to message on this ticket'));
    }

    const isIt = await isSupportIt(req);
    const senderRole = isIt ? 'IT_HANDLER' : 'EMPLOYEE';
    const senderName =
      (req.user as any)?.employee?.generalInfo?.fullName ??
      (req.user as any)?.username ??
      (isIt ? 'IT Support' : 'Employee');

    const msg = await supportService.sendMessage({
      ticketId,
      senderId: String(req.user!.id),
      senderRole,
      senderName,
      message: String(req.body?.message ?? ''),
      attachmentUrl: req.body?.attachmentUrl ? String(req.body.attachmentUrl) : null,
      attachmentName: req.body?.attachmentName ? String(req.body.attachmentName) : null,
    });
    return res.status(201).json(ok(msg));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// ==========================================
// TICKET TRANSFER WITH APPROVALS
// ==========================================
supportRouter.post('/:id/transfer/request', async (req: Request, res: Response) => {
  try {
    const ticketId = p(req.params.id);
    await assertCanManageTicket(req, ticketId);
    const targetHandlerEmployeeId = Number(req.body?.targetHandlerEmployeeId);
    if (!targetHandlerEmployeeId || !Number.isFinite(targetHandlerEmployeeId)) {
      return res.status(400).json(fail('Target handler employee ID is required'));
    }
    const reason = String(req.body?.reason ?? '');
    const ticket = await supportService.requestTransfer({
      ticketId,
      actorId: String(req.user!.id),
      targetHandlerEmployeeId,
      reason,
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.post('/:id/transfer/respond', async (req: Request, res: Response) => {
  try {
    if (!(await isSupportIt(req))) {
      return res.status(403).json(fail('Only IT Support handlers can respond to transfers'));
    }
    const accept = req.body?.accept === true || req.body?.accept === 'true';
    const remarks = req.body?.remarks ? String(req.body.remarks) : null;
    const ticket = await supportService.respondTransfer({
      ticketId: p(req.params.id),
      actorId: String(req.user!.id),
      accept,
      remarks,
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// ==========================================
// CUSTOM REMOTE OPERATOR SIGNALING
// ==========================================
supportRouter.post('/:id/remote/request', async (req: Request, res: Response) => {
  try {
    const ticketId = p(req.params.id);
    await assertCanManageTicket(req, ticketId);
    const session = await supportService.requestRemoteSession({
      ticketId,
      handlerUserId: String(req.user!.id),
      accessLevel: req.body?.accessLevel ?? 'FULL_CONTROL',
      uacEnabled: req.body?.uacEnabled !== false,
    });
    return res.status(201).json(ok(session));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.post('/:id/remote/respond', async (req: Request, res: Response) => {
  try {
    const sessionId = String(req.body?.sessionId ?? '');
    const accept = req.body?.accept === true || req.body?.accept === 'true';
    const session = await supportService.respondRemoteSession({
      sessionId,
      employeeUserId: String(req.user!.id),
      accept,
    });
    return res.json(ok(session));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.post('/:id/remote/end', async (req: Request, res: Response) => {
  try {
    const sessionId = String(req.body?.sessionId ?? '');
    const session = await supportService.endRemoteSession({
      sessionId,
      endedByUserId: String(req.user!.id),
    });
    return res.json(ok(session));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.post('/:id/assign', async (req: Request, res: Response) => {
  try {
    if (!(await isSupportIt(req))) {
      return res.status(403).json(fail('Only IT Support or Admin can assign tickets'));
    }
    const handlerId = Number(req.body?.handlerId ?? req.body?.assignedHandlerId);
    if (!handlerId || !Number.isFinite(handlerId)) {
      return res.status(400).json(fail('Valid target handlerId is required'));
    }
    const updated = await supportService.reassignTicket({
      ticketId: p(req.params.id),
      newHandlerId: handlerId,
      actorId: String(req.user!.id),
      note: req.body?.note != null ? String(req.body.note) : undefined,
    });
    return res.json(ok(updated));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.get('/:id/remote/active', async (req: Request, res: Response) => {
  try {
    const ticketId = p(req.params.id);
    const session = await supportService.getActiveRemoteSession(ticketId);
    if (!session) return res.json(ok(null));

    let remoteDeskId: string | null = null;
    let remoteDeskPassword: string | null = null;
    if (session.roomName) {
      try {
        const parsed = JSON.parse(session.roomName);
        if (parsed && parsed.deskId) {
          remoteDeskId = String(parsed.deskId);
          remoteDeskPassword = parsed.password ? String(parsed.password) : null;
        }
      } catch {}
    }

    // Also issue livekit token so the caller can directly connect if needed
    let tokenData: any = null;
    try {
      tokenData = await supportService.generateRemoteToken({
        ticketId,
        userId: String(req.user!.id),
        userName: (req.user as any)?.name || (req.user as any)?.fullName || 'User',
      });
    } catch {}

    return res.json(
      ok({
        ...session,
        remoteDeskId,
        remoteDeskPassword,
        token: tokenData?.token ?? null,
        livekitUrl: tokenData?.livekitUrl ?? null,
      }),
    );
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.post('/:id/remote/credentials', async (req: Request, res: Response) => {
  try {
    const ticketId = p(req.params.id);
    const deskId = String(req.body?.deskId ?? req.body?.remoteDeskId ?? '').trim();
    if (!deskId) {
      return res.status(400).json(fail('Desk ID is required'));
    }
    const password = req.body?.password ?? req.body?.remoteDeskPassword;
    const session = await supportService.updateRemoteCredentials({
      ticketId,
      deskId,
      password: password != null ? String(password) : undefined,
    });
    return res.json(ok(session));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.post('/:id/remote/token', async (req: Request, res: Response) => {
  try {
    const ticketId = p(req.params.id);
    const data = await supportService.generateRemoteToken({
      ticketId,
      userId: String(req.user!.id),
      userName: (req.user as any)?.name || (req.user as any)?.fullName || 'User',
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Windows Native Support Agent - Remote control dispatch from operator (requires Auth)
supportRouter.post('/:id/remote/control', (req: Request, res: Response) => {
  const ticketId = p(req.params.id);
  const result = supportService.pushRemoteCommand(ticketId, req.body || {});
  return res.json(ok(result));
});
