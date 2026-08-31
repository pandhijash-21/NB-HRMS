import http from 'http';
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import jwt from 'jsonwebtoken';
import { createClient } from 'redis';
import { env } from '../../config/env';
import { REDIS_URL } from '../../config/redis';
import { chatService } from './chat.service';
import { meetService, type GuestActor, type UserActor } from './meet.service';
import { getProfile } from './profiles';
import { collabStorage } from './storage';

let ioRef: Server | null = null;
let presenceRedis: ReturnType<typeof createClient> | null = null;

export function getIo() {
  return ioRef;
}

export function emitWaitingUpdate(
  meetingId: string,
  hostUserId: string | undefined,
  waiting: unknown[],
  knock?: unknown,
) {
  const io = ioRef;
  if (!io) return;
  const payload = { waiting };
  io.to(`meeting:${meetingId}`).emit('waiting_update', payload);
  if (hostUserId) {
    io.to(`user:${hostUserId}`).emit('waiting_update', payload);
    if (knock) io.to(`user:${hostUserId}`).emit('waiting_knock', knock);
  }
}

export function emitJoinDecision(opts: {
  meetingId: string;
  userId?: string | null;
  participantId: string;
  admitted: boolean;
}) {
  const io = ioRef;
  if (!io) return;
  const event = opts.admitted ? 'join_approved' : 'join_denied';
  const payload = {
    meetingId: opts.meetingId,
    participantId: opts.participantId,
    admitted: opts.admitted,
  };
  io.to(`waiting:${opts.participantId}`).emit(event, payload);
  if (opts.userId) io.to(`user:${opts.userId}`).emit(event, payload);
}

export function emitMeetingInvites(inviteeIds: string[], payload: unknown) {
  const io = ioRef;
  if (!io) return;
  for (const id of inviteeIds) {
    if (id) io.to(`user:${id}`).emit('meeting_invite', payload);
  }
}

export async function isOnline(userId: string) {
  if (!presenceRedis?.isOpen) return false;
  return Boolean(await presenceRedis.exists(`presence:${userId}`));
}

async function markOnline(userId: string) {
  if (!presenceRedis?.isOpen) return;
  await presenceRedis.set(`presence:${userId}`, 'online', { EX: 45 });
}

type SocketUser = UserActor | GuestActor;

async function authenticateSocket(token?: string): Promise<SocketUser | null> {
  if (!token) return null;
  const guest = await meetService.resolveGuest(token);
  if (guest) return guest;
  try {
    const decoded = jwt.verify(token, env.JWT_SECRET) as jwt.JwtPayload;
    const userId = String(decoded.sub ?? '');
    if (!userId) return null;
    const profile = await getProfile(userId);
    return {
      kind: 'user',
      userId,
      name: profile?.name || 'Member',
      photoUrl: profile?.photoUrl || null,
    };
  } catch {
    return null;
  }
}

export async function setupCollaborationSocket(httpServer: http.Server) {
  const io = new Server(httpServer, {
    cors: { origin: true, credentials: true },
    path: '/socket.io',
  });

  try {
    const pub = createClient({
      url: REDIS_URL,
      socket: {
        connectTimeout: 2500,
        reconnectStrategy: (retries) => (retries >= 2 ? false : 200),
      },
    });
    pub.on('error', () => { /* fail-open when Redis is down */ });
    const sub = pub.duplicate();
    sub.on('error', () => { /* fail-open when Redis is down */ });
    presenceRedis = pub;
    await Promise.race([
      Promise.all([pub.connect(), sub.connect()]),
      new Promise<never>((_, reject) => {
        setTimeout(() => reject(new Error('Socket.io Redis adapter timed out')), 3000);
      }),
    ]);
    io.adapter(createAdapter(pub, sub));
  } catch (err) {
    console.warn('Socket.io Redis adapter unavailable — single-node only:', err instanceof Error ? err.message : err);
  }

  void collabStorage.allowPublicGetCors();

  io.on('connection', async (socket) => {
    const token = (socket.handshake.auth as { token?: string })?.token
      || (typeof socket.handshake.query.token === 'string' ? socket.handshake.query.token : undefined);
    const actor = await authenticateSocket(token);
    if (!actor) {
      socket.disconnect(true);
      return;
    }

    socket.data.actor = actor;
    if (actor.kind === 'user') {
      socket.join(`user:${actor.userId}`);
      await markOnline(actor.userId);
      io.emit('presence', { userId: actor.userId, online: true });
    } else {
      socket.join(`meeting:${actor.meetingId}`);
      socket.join(`waiting:${actor.participantId}`);
    }

    socket.on('heartbeat', async () => {
      if (actor.kind === 'user') await markOnline(actor.userId);
    });

    socket.on('join_channel', async (channelId: string) => {
      if (actor.kind !== 'user') return;
      try {
        await chatService.getChannel(channelId, actor.userId);
        socket.join(`channel:${channelId}`);
      } catch {
        /* ignore */
      }
    });

    socket.on('leave_channel', (channelId: string) => {
      socket.leave(`channel:${channelId}`);
    });

    socket.on('send_message', async (payload: { channelId: string; content?: string; replyToId?: string }) => {
      if (actor.kind !== 'user') return;
      try {
        const message = await chatService.sendMessage({
          channelId: payload.channelId,
          senderId: actor.userId,
          content: payload.content,
          replyToId: payload.replyToId,
        });
        io.to(`channel:${payload.channelId}`).emit('new_message', message);
      } catch (err) {
        socket.emit('error_message', { error: err instanceof Error ? err.message : 'Send failed' });
      }
    });

    socket.on('typing', async (payload: { channelId: string }) => {
      if (actor.kind !== 'user') return;
      socket.to(`channel:${payload.channelId}`).emit('user_typing', {
        channelId: payload.channelId,
        userId: actor.userId,
        name: actor.name,
      });
    });

    socket.on('mark_read', async (payload: { channelId: string }) => {
      if (actor.kind !== 'user') return;
      const data = await chatService.markRead(payload.channelId, actor.userId);
      io.to(`channel:${payload.channelId}`).emit('channel_read', data);
    });

    socket.on('react', async (payload: { messageId: string; emoji: string }) => {
      if (actor.kind !== 'user') return;
      try {
        const message = await chatService.toggleReaction(payload.messageId, actor.userId, payload.emoji);
        io.to(`channel:${message.channelId}`).emit('message_updated', message);
      } catch {
        /* ignore */
      }
    });

    socket.on('join_meeting', async (meetingId: string | { meetingId?: string }) => {
      const id = typeof meetingId === 'string' ? meetingId : String(meetingId?.meetingId ?? '');
      if (!id) return;
      socket.join(`meeting:${id}`);
      if (actor.kind === 'guest') {
        socket.join(`waiting:${actor.participantId}`);
        return;
      }
      try {
        const meeting = await meetService.getById(id, actor.userId);
        const selfWait = (meeting?.waitingParticipants ?? []).find((p: { userId?: string | null }) => p.userId === actor.userId);
        if (selfWait?.id) socket.join(`waiting:${selfWait.id}`);
        if (meeting?.isHost) {
          socket.emit('waiting_update', { waiting: meeting.waitingParticipants ?? [] });
        }
      } catch {
        /* ignore */
      }
    });

    socket.on('meeting_chat', async (payload: {
      meetingId: string;
      content: string;
      scope?: 'ROOM' | 'DIRECT';
      recipientUserId?: string;
    }) => {
      try {
        if (payload.meetingId) socket.join(`meeting:${payload.meetingId}`);
        const data = await meetService.postChat({
          meetingId: payload.meetingId,
          actor,
          content: payload.content,
          scope: payload.scope,
          recipientUserId: payload.recipientUserId,
        });
        // Always echo to the sender (host-only rooms never see io.to(room) if they
        // missed join_meeting). socket.to() broadcasts to everyone else in the room.
        socket.emit('meeting_chat', data);
        if (data.scope === 'DIRECT' && data.recipientUserId) {
          io.to(`user:${data.recipientUserId}`).emit('meeting_chat', data);
        } else {
          socket.to(`meeting:${payload.meetingId}`).emit('meeting_chat', data);
        }
      } catch (err) {
        socket.emit('error_message', { error: err instanceof Error ? err.message : 'Chat failed' });
      }
    });

    socket.on('meeting_hand', (payload: { meetingId?: string; raised?: boolean }) => {
      const meetingId = String(payload?.meetingId ?? '');
      if (!meetingId) return;
      io.to(`meeting:${meetingId}`).emit('meeting_hand', {
        meetingId,
        raised: payload.raised !== false,
        name: actor.name,
        identity: actor.kind === 'user' ? `user:${actor.userId}` : `guest:${actor.participantId}`,
        userId: actor.kind === 'user' ? actor.userId : null,
        participantId: actor.kind === 'guest' ? actor.participantId : null,
      });
    });

    socket.on('meeting_reaction', (payload: { meetingId?: string; emoji?: string }) => {
      const meetingId = String(payload?.meetingId ?? '');
      const emoji = String(payload?.emoji ?? '').slice(0, 8);
      const allowed = new Set(['👍', '👏', '❤️', '😂', '🎉', '👋']);
      if (!meetingId || !allowed.has(emoji)) return;
      io.to(`meeting:${meetingId}`).emit('meeting_reaction', {
        meetingId,
        emoji,
        name: actor.name,
        identity: actor.kind === 'user' ? `user:${actor.userId}` : `guest:${actor.participantId}`,
      });
    });

    socket.on('disconnect', async () => {
      if (actor.kind === 'user') {
        io.emit('presence', { userId: actor.userId, online: false });
      }
    });
  });

  ioRef = io;
  return io;
}
