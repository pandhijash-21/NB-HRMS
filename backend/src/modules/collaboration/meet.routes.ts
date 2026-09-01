import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import jwt from 'jsonwebtoken';
import multer from 'multer';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, type PermissionAction } from '../../middleware/rbac';
import { env } from '../../config/env';
import { ok, fail } from '../../utils/response';
import { meetService, type GuestActor, type UserActor } from './meet.service';
import { emitJoinDecision, emitMeetingChat, emitMeetingEnded, emitMeetingInvites, emitMeetingRemoved, emitMeetingTranscript, emitMeetingTranscriptLanguage, emitWaitingUpdate, getIo } from './socket';
import { getProfile } from './profiles';

export const meetingsRouter = Router();
const p = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) ?? '';
const transcriptUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2_000_000 },
});

async function actorFromReq(req: Request): Promise<UserActor | GuestActor | null> {
  if (req.user) {
    const profile = await getProfile(req.user.id);
    return {
      kind: 'user',
      userId: req.user.id,
      name: profile?.name || 'Member',
      photoUrl: profile?.photoUrl || null,
    };
  }
  const header = req.headers.authorization;
  const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
  if (!token) return null;
  return meetService.resolveGuest(token);
}

function optionalAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
  if (!token) return next();
  try {
    const decoded = jwt.verify(token, env.JWT_SECRET) as jwt.JwtPayload;
    const userId = String(decoded.sub ?? '');
    if (userId) {
      req.user = {
        id: userId,
        employeeId: decoded.employeeId as number | null | undefined,
        roleId: decoded.roleId as string,
        roleName: decoded.roleName as string,
        role: decoded.roleName as string,
        subOrganization: (decoded.subOrganization as string | null | undefined) ?? null,
        employeeViewScope:
          (decoded.employeeViewScope as 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY' | undefined) ?? 'NONE',
        permissions: (decoded.permissions as Record<string, string[]>) ?? {},
      };
    }
  } catch {
    // Continue as anonymous so the lobby still loads.
  }
  next();
}

meetingsRouter.get('/code/:code', optionalAuth, async (req: Request, res: Response) => {
  try {
    const data = await meetService.getByCode(p(req.params.code), req.user?.id);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(404).json(fail(e instanceof Error ? e.message : 'Not found'));
  }
});

meetingsRouter.post('/guest-join', async (req: Request, res: Response) => {
  try {
    const body = z
      .object({
        code: z.string().min(3),
        displayName: z.string().min(2),
        email: z.string().email().optional(),
      })
      .parse(req.body);
    const data = await meetService.guestJoin(body.code, body.displayName, body.email);
    if (data.waiting && data.meeting) {
      emitWaitingUpdate(
        data.meeting.id,
        data.meeting.hostUserId ?? data.meeting.host?.userId,
        data.meeting.waitingParticipants ?? [],
        data.participant,
      );
    }
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Unable to join'));
  }
});

meetingsRouter.post('/guest-enter', async (req: Request, res: Response) => {
  try {
    const actor = await actorFromReq(req);
    if (!actor || actor.kind !== 'guest') {
      return res.status(401).json(fail('Guest session required'));
    }
    const data = await meetService.enterAsGuest(actor);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Unable to join'));
  }
});

meetingsRouter.get('/stt-status', async (_req: Request, res: Response) => {
  try {
    const data = await meetService.sttStatus();
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

meetingsRouter.get('/:id/transcript', optionalAuth, async (req: Request, res: Response) => {
  try {
    const actor = await actorFromReq(req);
    if (!actor) return res.status(401).json(fail('Unauthenticated'));
    const data = await meetService.listTranscript(p(req.params.id), actor);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

meetingsRouter.post(
  '/:id/transcript',
  optionalAuth,
  transcriptUpload.single('audio'),
  async (req: Request, res: Response) => {
    try {
      const actor = await actorFromReq(req);
      if (!actor) return res.status(401).json(fail('Unauthenticated'));
      const audioBase64 = req.file
        ? req.file.buffer.toString('base64')
        : String((req.body as { audioBase64?: string })?.audioBase64 || '');
      const body = z
        .object({
          audioBase64: z.string().min(1),
          audioFormat: z.string().optional(),
          samplingRate: z.coerce.number().int().positive().optional(),
          language: z.string().optional(),
          startedAt: z.string().optional(),
          endedAt: z.string().optional(),
        })
        .parse({
          ...(req.body ?? {}),
          audioBase64,
          audioFormat:
            (req.body as { audioFormat?: string })?.audioFormat ||
            (req.file?.mimetype.includes('wav') ? 'wav' : undefined),
        });
      const data = await meetService.ingestSpeechChunk(p(req.params.id), actor, body);
      if (!data.skipped && 'utterance' in data && data.utterance) {
        emitMeetingTranscript({ meetingId: p(req.params.id), utterance: data.utterance });
      }
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to transcribe'));
    }
  },
);

// In-meeting chat — guests use meet JWT (not user session); must stay before requireAuth.
meetingsRouter.get('/:id/chat', async (req: Request, res: Response) => {
  try {
    const actor = await actorFromReq(req);
    if (!actor) return res.status(401).json(fail('Unauthenticated'));
    const data = await meetService.listChat(p(req.params.id), actor);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

meetingsRouter.post('/:id/chat', async (req: Request, res: Response) => {
  try {
    const actor = await actorFromReq(req);
    if (!actor) return res.status(401).json(fail('Unauthenticated'));
    const body = z
      .object({
        content: z.string().min(1),
        scope: z.enum(['ROOM', 'DIRECT']).optional(),
        recipientUserId: z.string().optional(),
        recipientParticipantId: z.string().optional(),
      })
      .parse(req.body);
    const data = await meetService.postChat({
      meetingId: p(req.params.id),
      actor,
      content: body.content,
      scope: body.scope,
      recipientUserId: body.recipientUserId,
      recipientParticipantId: body.recipientParticipantId,
    });
    emitMeetingChat(data);
    return res.status(201).json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

meetingsRouter.use(requireAuth);
meetingsRouter.use((req, res, next) => {
  const action: PermissionAction = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)
    ? 'WRITE'
    : 'READ';
  return requirePermission('MEETINGS', action)(req, res, next);
});

meetingsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const data = await meetService.listMine(req.user!.id);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list meetings'));
  }
});

meetingsRouter.get('/admin', async (req: Request, res: Response) => {
  try {
    if (!meetService.canAdminMeetings(req.user!)) {
      return res.status(403).json(fail('Admin meeting access required'));
    }
    const data = await meetService.listAdmin();
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

meetingsRouter.post('/', async (req: Request, res: Response) => {
  try {
    const body = z
      .object({
        title: z.string().min(1),
        agenda: z.string().optional(),
        scheduledStart: z.string().optional(),
        scheduledEnd: z.string().optional(),
        inviteeIds: z.array(z.string()).optional(),
        allowGuests: z.boolean().optional(),
        waitingRoom: z.boolean().optional(),
        recordEnabled: z.boolean().optional(),
        instant: z.boolean().optional(),
      })
      .parse(req.body);
    const data = await meetService.create(req.user!.id, body);
    if (body.inviteeIds?.length && data) {
      emitMeetingInvites(body.inviteeIds, {
        meetingId: data.id,
        title: data.title,
        code: data.code,
        joinUrl: data.joinUrl,
        scheduledStart: data.scheduledStart,
      });
    }
    return res.status(201).json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to create meeting'));
  }
});

meetingsRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const data = await meetService.getById(p(req.params.id), req.user!.id);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(404).json(fail(e instanceof Error ? e.message : 'Not found'));
  }
});

meetingsRouter.patch('/:id', async (req: Request, res: Response) => {
  try {
    const body = z
      .object({
        title: z.string().min(1).optional(),
        agenda: z.string().optional(),
        scheduledStart: z.string().optional(),
        scheduledEnd: z.string().nullable().optional(),
        waitingRoom: z.boolean().optional(),
        recordEnabled: z.boolean().optional(),
        allowGuests: z.boolean().optional(),
        inviteeIds: z.array(z.string()).optional(),
      })
      .parse(req.body);
    const data = await meetService.update(p(req.params.id), req.user!.id, body);
    if (body.inviteeIds?.length && data) {
      emitMeetingInvites(body.inviteeIds, {
        meetingId: data.id,
        title: data.title,
        code: data.code,
        joinUrl: data.joinUrl,
        scheduledStart: data.scheduledStart,
      });
    }
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to update meeting'));
  }
});

meetingsRouter.post('/:id/transcript-language', async (req: Request, res: Response) => {
  try {
    const body = z.object({ language: z.string().min(2).max(8) }).parse(req.body);
    const data = await meetService.setTranscriptLanguage(p(req.params.id), req.user!.id, body.language);
    emitMeetingTranscriptLanguage(p(req.params.id), data.language);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

meetingsRouter.post('/:id/cancel', async (req: Request, res: Response) => {
  try {
    const data = await meetService.cancel(p(req.params.id), req.user!.id);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

meetingsRouter.post('/:id/invite', async (req: Request, res: Response) => {
  try {
    const body = z.object({ userIds: z.array(z.string()).min(1) }).parse(req.body);
    const data = await meetService.invite(p(req.params.id), req.user!.id, body.userIds);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

meetingsRouter.post('/join', async (req: Request, res: Response) => {
  try {
    const body = z.object({ code: z.string().min(3) }).parse(req.body);
    const data = await meetService.joinAsUser(body.code, req.user!.id);
    if (data.waiting && data.meeting) {
      emitWaitingUpdate(
        data.meeting.id,
        data.meeting.hostUserId ?? data.meeting.host?.userId,
        data.meeting.waitingParticipants ?? [],
        data.participant,
      );
    }
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Unable to join'));
  }
});

meetingsRouter.post('/:id/join', async (req: Request, res: Response) => {
  try {
    const idOrCode = p(req.params.id);
    let meeting;
    try {
      meeting = await meetService.getById(idOrCode, req.user!.id);
    } catch {
      meeting = await meetService.getByCode(idOrCode, req.user!.id);
    }
    const data = await meetService.joinAsUser(meeting!.code, req.user!.id);
    if (data.waiting && data.meeting) {
      emitWaitingUpdate(
        data.meeting.id,
        data.meeting.hostUserId ?? data.meeting.host?.userId,
        data.meeting.waitingParticipants ?? [],
        data.participant,
      );
    }
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Unable to join'));
  }
});

meetingsRouter.post('/:id/admit', async (req: Request, res: Response) => {
  try {
    const body = z.object({ participantId: z.string().min(1) }).parse(req.body);
    const data = await meetService.admit(p(req.params.id), req.user!.id, body.participantId);
    emitJoinDecision({
      meetingId: p(req.params.id),
      userId: data.participant.userId,
      participantId: data.participant.id,
      admitted: true,
    });
    emitWaitingUpdate(
      data.meeting!.id,
      data.meeting!.hostUserId ?? data.meeting!.host?.userId,
      data.meeting!.waitingParticipants ?? [],
    );
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to admit'));
  }
});

meetingsRouter.post('/:id/deny', async (req: Request, res: Response) => {
  try {
    const body = z.object({ participantId: z.string().min(1) }).parse(req.body);
    const data = await meetService.deny(p(req.params.id), req.user!.id, body.participantId);
    emitJoinDecision({
      meetingId: p(req.params.id),
      userId: data.participant.userId,
      participantId: data.participant.id,
      admitted: false,
    });
    emitWaitingUpdate(
      data.meeting!.id,
      data.meeting!.hostUserId ?? data.meeting!.host?.userId,
      data.meeting!.waitingParticipants ?? [],
    );
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to decline'));
  }
});

meetingsRouter.post('/:id/remove', async (req: Request, res: Response) => {
  try {
    const body = z.object({ participantId: z.string().min(1) }).parse(req.body);
    const data = await meetService.removeFromMeeting(
      p(req.params.id),
      req.user!.id,
      body.participantId,
      req.user,
    );
    emitMeetingRemoved({
      meetingId: p(req.params.id),
      participantId: data.participant.id,
      userId: data.participant.userId,
      identity: data.identity,
      name: data.participant.name,
    });
    return res.json(ok(data));
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : 'Failed to remove';
    const status = message.includes('Only the host') ? 403 : 400;
    return res.status(status).json(fail(message));
  }
});

meetingsRouter.post('/:id/end', async (req: Request, res: Response) => {
  try {
    const meetingId = p(req.params.id);
    const emitProgress = (payload: { step: string; status: string; label: string }) => {
      const io = getIo();
      io?.to(`meeting:${meetingId}`).emit('meeting_end_progress', payload);
      io?.to(`user:${req.user!.id}`).emit('meeting_end_progress', payload);
    };
    const data = await meetService.endMeeting(
      meetingId,
      req.user!.id,
      (ended) => {
        emitMeetingEnded({
          meetingId: ended.meetingId,
          code: ended.code,
          userIds: ended.userIds,
        });
      },
      emitProgress,
    );
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to end meeting'));
  }
});

meetingsRouter.post('/:id/recording/start', async (req: Request, res: Response) => {
  try {
    const data = await meetService.startRecording(p(req.params.id), req.user!);
    getIo()?.to(`meeting:${p(req.params.id)}`).emit('recording', { active: true });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to start recording'));
  }
});

meetingsRouter.post('/:id/recording/stop', async (req: Request, res: Response) => {
  try {
    const data = await meetService.stopRecording(p(req.params.id), req.user!);
    getIo()?.to(`meeting:${p(req.params.id)}`).emit('recording', { active: false });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to stop recording'));
  }
});

meetingsRouter.get('/:id/recording', async (req: Request, res: Response) => {
  try {
    const data = await meetService.getRecordingPlayback(p(req.params.id), req.user!);
    return res.json(ok(data));
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : 'Recording unavailable';
    const status = message.includes('not found')
      ? 404
      : message.includes('do not have access')
        ? 403
        : 400;
    return res.status(status).json(fail(message));
  }
});

meetingsRouter.delete('/:id/recording', async (req: Request, res: Response) => {
  try {
    const data = await meetService.deleteRecording(p(req.params.id), req.user!);
    return res.json(ok(data));
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : 'Failed to delete recording';
    const status = message.includes('Only an admin') ? 403 : 400;
    return res.status(status).json(fail(message));
  }
});
