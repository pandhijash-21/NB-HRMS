import http from 'http';
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import jwt from 'jsonwebtoken';
import { createClient } from 'redis';
import { env } from '../../config/env';
import { REDIS_URL } from '../../config/redis';
import { isAllowedCorsOrigin } from '../../utils/corsOrigins';
import { chatService } from './chat.service';
import { meetService, type GuestActor, type UserActor } from './meet.service';
import { getProfile } from './profiles';

let ioRef: Server | null = null;
let presenceRedis: ReturnType<typeof createClient> | null = null;
const meetingBoards = new Map<string, Array<unknown>>();

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
    if (knock) {
      io.to(`user:${hostUserId}`).emit('waiting_knock', knock);
      io.to(`user:${hostUserId}`).emit('push_notify', {
        kind: 'meet',
        title: 'Someone is waiting',
        body: 'A participant is waiting to join your meeting',
        meetingId,
        path: '/meet',
      });
    }
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

export function emitMeetingRemoved(opts: {
  meetingId: string;
  participantId: string;
  userId?: string | null;
  identity: string;
  name?: string;
}) {
  const io = ioRef;
  if (!io) return;
  const payload = {
    meetingId: opts.meetingId,
    participantId: opts.participantId,
    identity: opts.identity,
    name: opts.name ?? 'Participant',
  };
  io.to(`waiting:${opts.participantId}`).emit('meeting_removed', payload);
  io.to(`participant:${opts.participantId}`).emit('meeting_removed', payload);
  if (opts.userId) io.to(`user:${opts.userId}`).emit('meeting_removed', payload);
  io.to(`meeting:${opts.meetingId}`).emit('meeting_peer_removed', payload);
}

export function emitMeetingModeration(opts: {
  meetingId: string;
  action: string;
  targetIdentity?: string;
  targetParticipantId?: string;
  targetUserId?: string;
  byHostUserId?: string;
  byHostName?: string;
}) {
  const io = ioRef;
  if (!io) return;
  const payload = {
    meetingId: opts.meetingId,
    action: opts.action,
    targetIdentity: opts.targetIdentity,
    targetParticipantId: opts.targetParticipantId,
    targetUserId: opts.targetUserId,
    byHostUserId: opts.byHostUserId,
    byHostName: opts.byHostName ?? 'Host',
  };
  io.to(`meeting:${opts.meetingId}`).emit('meeting_moderation', payload);
  if (opts.targetParticipantId) {
    io.to(`participant:${opts.targetParticipantId}`).emit('meeting_moderation', payload);
    io.to(`waiting:${opts.targetParticipantId}`).emit('meeting_moderation', payload);
  }
  if (opts.targetUserId) {
    io.to(`user:${opts.targetUserId}`).emit('meeting_moderation', payload);
  }
}

export function emitChatNewMessage(
  channelId: string,
  message: {
    senderId: string;
    content?: string | null;
    mentionedUserIds?: string[];
    memberUserIds?: string[];
    sender?: { name?: string | null } | null;
  },
) {
  const io = ioRef;
  if (!io) return;
  io.to(`channel:${channelId}`).emit('new_message', message);
  const memberIds = message.memberUserIds ?? [];
  const mentioned = new Set(message.mentionedUserIds ?? []);
  const senderName = message.sender?.name || 'Someone';
  const content = String(message.content || '');
  const preview = (content || 'Sent an attachment').replace(/\s+/g, ' ').slice(0, 140);
  const meet = content.match(/\/meet\/r\/([A-Za-z0-9-]+)/i);
  const voice = /voice=1|voice call/i.test(content);
  const startedCall = /started a (voice call|meeting)/i.test(content);
  for (const id of memberIds) {
    if (!id) continue;
    io.to(`user:${id}`).emit('new_message', message);
    if (id === message.senderId) continue;
    if (meet && startedCall) {
      const code = meet[1];
      const kind = voice ? 'voice_call' : 'meet_call';
      const title = voice ? `${senderName} is calling` : `${senderName} started a meeting`;
      const path = `/meet/r/${code}${voice ? '?voice=1' : ''}`;
      const callPayload = {
        kind,
        title,
        body: preview,
        channelId,
        senderId: message.senderId,
        code,
        voice,
        path,
      };
      io.to(`user:${id}`).emit('incoming_call', callPayload);
      io.to(`user:${id}`).emit('push_notify', callPayload);
      continue;
    }
    const tagged = mentioned.has(id);
    io.to(`user:${id}`).emit('push_notify', {
      kind: tagged ? 'mention' : 'chat',
      title: tagged ? `${senderName} mentioned you` : senderName,
      body: preview,
      channelId,
      senderId: message.senderId,
      path: '/chat',
    });
  }
}

export function emitMeetingEnded(opts: {
  meetingId: string;
  code?: string;
  userIds?: string[];
}) {
  const io = ioRef;
  if (!io) return;
  const payload = { meetingId: opts.meetingId, code: opts.code ?? '' };
  io.to(`meeting:${opts.meetingId}`).emit('meeting_ended', payload);
  for (const id of opts.userIds ?? []) {
    if (id) io.to(`user:${id}`).emit('meeting_ended', payload);
  }
}

export type MeetingChatPayload = {
  id: string;
  meetingId: string;
  senderUserId: string | null;
  senderParticipantId?: string | null;
  senderName: string;
  senderPhotoUrl?: string | null;
  scope: string;
  recipientUserId: string | null;
  recipientParticipantId?: string | null;
  recipientName?: string | null;
  content: string;
  createdAt: Date | string;
};

export function emitMeetingTranscript(data: {
  meetingId: string;
  utterance: {
    id: string;
    speakerName: string;
    speakerUserId: string | null;
    speakerParticipantId: string | null;
    spokenAt: Date | string;
    endedAt: Date | string | null;
    text: string;
    language: string;
  };
}) {
  const io = ioRef;
  if (!io) return;
  io.to(`meeting:${data.meetingId}`).emit('meeting_transcript', data);
}

export function emitMeetingTranscriptLanguage(meetingId: string, language: string) {
  const io = ioRef;
  if (!io) return;
  io.to(`meeting:${meetingId}`).emit('meeting_transcript_lang', { meetingId, language });
}

export function emitMeetingChat(data: MeetingChatPayload) {
  const io = ioRef;
  if (!io) return;
  if (data.scope === 'DIRECT') {
    const rooms = new Set<string>();
    if (data.recipientUserId) rooms.add(`user:${data.recipientUserId}`);
    if (data.senderUserId) rooms.add(`user:${data.senderUserId}`);
    if (data.recipientParticipantId) {
      rooms.add(`waiting:${data.recipientParticipantId}`);
      rooms.add(`participant:${data.recipientParticipantId}`);
    }
    if (data.senderParticipantId) {
      rooms.add(`waiting:${data.senderParticipantId}`);
      rooms.add(`participant:${data.senderParticipantId}`);
    }
    for (const room of rooms) io.to(room).emit('meeting_chat', data);
    return;
  }
  io.to(`meeting:${data.meetingId}`).emit('meeting_chat', data);
}

export function emitPushNotify(
  userIds: string[],
  payload: {
    kind: string;
    title: string;
    body: string;
    channelId?: string;
    senderId?: string;
    meetingId?: string;
    code?: string;
    path?: string;
  },
) {
  const io = ioRef;
  if (!io) return;
  for (const id of userIds) {
    if (id) io.to(`user:${id}`).emit('push_notify', payload);
  }
}

export function emitMeetingInvites(inviteeIds: string[], payload: {
  meetingId: string;
  title?: string | null;
  code?: string;
  joinUrl?: string;
  scheduledStart?: unknown;
}) {
  const io = ioRef;
  if (!io) return;
  for (const id of inviteeIds) {
    if (!id) continue;
    io.to(`user:${id}`).emit('meeting_invite', payload);
    io.to(`user:${id}`).emit('push_notify', {
      kind: 'meet',
      title: 'Meeting invite',
      body: payload.title || 'You were invited to a meeting',
      meetingId: payload.meetingId,
      code: payload.code,
      path: payload.code ? `/meet/r/${payload.code}` : '/meet',
    });
  }
}

export async function isOnline(userId: string) {
  if (presenceRedis?.isOpen) {
    return Boolean(await presenceRedis.exists(`presence:${userId}`));
  }
  const io = ioRef;
  if (!io) return false;
  try {
    const sockets = await io.in(`user:${userId}`).fetchSockets();
    return sockets.length > 0;
  } catch {
    return false;
  }
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
    cors: {
      origin: (origin, callback) => {
        if (isAllowedCorsOrigin(origin)) {
          callback(null, true);
          return;
        }
        callback(new Error('CORS not allowed'), false);
      },
      credentials: true,
    },
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
      socket.join(`participant:${actor.participantId}`);
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
        socket.emit('new_message', message);
        emitChatNewMessage(payload.channelId, message);
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
      socket.data.meetingId = id;
      socket.join(`meeting:${id}`);
      try {
        socket.emit('recording', { active: await meetService.recordingActive(id) });
      } catch {
        /* ignore */
      }
      if (actor.kind === 'guest') {
        socket.join(`waiting:${actor.participantId}`);
        socket.join(`participant:${actor.participantId}`);
        return;
      }
      try {
        const meeting = await meetService.getById(id, actor.userId);
        const self =
          (meeting?.participants ?? []).find((p: { userId?: string | null }) => p.userId === actor.userId) ??
          (meeting?.waitingParticipants ?? []).find((p: { userId?: string | null }) => p.userId === actor.userId);
        if (self?.id) {
          socket.join(`waiting:${self.id}`);
          socket.join(`participant:${self.id}`);
        }
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
      recipientParticipantId?: string;
    }) => {
      try {
        if (payload.meetingId) socket.join(`meeting:${payload.meetingId}`);
        const data = await meetService.postChat({
          meetingId: payload.meetingId,
          actor,
          content: payload.content,
          scope: payload.scope,
          recipientUserId: payload.recipientUserId,
          recipientParticipantId: payload.recipientParticipantId,
        });
        // Echo to the sender even if they missed join_meeting.
        socket.emit('meeting_chat', data);
        emitMeetingChat(data);
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
      const allowed = new Set(['👍', '👏', '❤️', '😂', '🎉', '😮', '👋', '🔥']);
      if (!meetingId || !allowed.has(emoji)) return;
      io.to(`meeting:${meetingId}`).emit('meeting_reaction', {
        meetingId,
        emoji,
        name: actor.name,
        identity: actor.kind === 'user' ? `user:${actor.userId}` : `guest:${actor.participantId}`,
        userId: actor.kind === 'user' ? actor.userId : null,
        participantId: actor.kind === 'guest' ? actor.participantId : null,
      });
    });

    socket.on('meeting_moderation', async (payload: {
      meetingId: string;
      action: 'mute_mic' | 'unmute_mic' | 'stop_video' | 'allow_video' | 'stop_screen' | 'allow_screen' | 'mute_all';
      targetIdentity?: string;
      targetParticipantId?: string;
      targetUserId?: string;
    }) => {
      const meetingId = String(payload?.meetingId ?? '');
      if (!meetingId || !payload?.action) return;
      if (actor.kind !== 'user') return;
      try {
        await meetService.moderateParticipant(meetingId, actor.userId, {
          action: payload.action,
          targetIdentity: payload.targetIdentity,
          targetParticipantId: payload.targetParticipantId,
          targetUserId: payload.targetUserId,
        });
      } catch (err) {
        socket.emit('error_message', { error: err instanceof Error ? err.message : 'Moderation failed' });
      }
    });

    socket.on('meeting_board_draw', (payload: { meetingId: string; stroke: unknown }) => {
      const meetingId = String(payload?.meetingId ?? '');
      if (!meetingId || !payload?.stroke) return;
      if (!meetingBoards.has(meetingId)) {
        meetingBoards.set(meetingId, []);
      }
      const strokes = meetingBoards.get(meetingId)!;
      if (strokes.length > 2000) strokes.shift();
      strokes.push(payload.stroke);
      io.to(`meeting:${meetingId}`).emit('meeting_board_draw', {
        meetingId,
        stroke: payload.stroke,
        sender: {
          name: actor.name,
          identity: actor.kind === 'user' ? `user:${actor.userId}` : `guest:${actor.participantId}`,
        },
      });
    });

    socket.on('meeting_board_clear', (payload: { meetingId: string }) => {
      const meetingId = String(payload?.meetingId ?? '');
      if (!meetingId) return;
      meetingBoards.delete(meetingId);
      io.to(`meeting:${meetingId}`).emit('meeting_board_clear', {
        meetingId,
        sender: {
          name: actor.name,
          identity: actor.kind === 'user' ? `user:${actor.userId}` : `guest:${actor.participantId}`,
        },
      });
    });

    socket.on('meeting_board_get_history', (payload: { meetingId: string }) => {
      const meetingId = String(payload?.meetingId ?? '');
      if (!meetingId) return;
      const history = meetingBoards.get(meetingId) ?? [];
      socket.emit('meeting_board_history', { meetingId, strokes: history });
    });

    socket.on('meeting_whisper_toggle', (payload: { meetingId: string; enabled: boolean }) => {
      const meetingId = String(payload?.meetingId ?? '');
      if (!meetingId) return;
      io.to(`meeting:${meetingId}`).emit('meeting_whisper_status', {
        meetingId,
        enabled: Boolean(payload.enabled),
        by: actor.name,
      });
    });

    socket.on('disconnect', async () => {
      if (actor.kind === 'user') {
        io.emit('presence', { userId: actor.userId, online: false });
      }
      const meetingId = typeof socket.data.meetingId === 'string' ? socket.data.meetingId : '';
      if (meetingId) {
        setTimeout(() => {
          void meetService.closeAbandonedLive(meetingId);
        }, 2000);
      }
    });
  });

  ioRef = io;
  return io;
}
