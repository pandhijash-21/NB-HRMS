import crypto from 'crypto';
import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import jwt from 'jsonwebtoken';
import { prisma } from '../../config/prisma';
import { env } from '../../config/env';
import { cloudinary, getCloudinaryCredentials } from '../../config/cloudinary';
import { getProfile, getProfiles } from './profiles';
import { issueLiveKitToken, livekitPublicUrl, startRoomRecording, stopRoomRecording, deleteLiveKitRoom, removeLiveKitParticipant } from './livekit';
import { generateMeetingSummary } from './summary.service';
import { sendMeetingInviteEmail, sendMeetingSummaryEmail } from '../../utils/mailer';
import { collabStorage } from './storage';

export type MeetEndProgress = {
  step: 'stop_recording' | 'save_cloud' | 'close_room' | 'summary';
  status: 'running' | 'done' | 'skipped' | 'error';
  label: string;
};

type ProgressFn = (p: MeetEndProgress) => void;

function makeMeetCode() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz';
  const pick = (n: number) =>
    Array.from({ length: n }, () => alphabet[crypto.randomInt(alphabet.length)]).join('');
  return `${pick(3)}-${pick(4)}-${pick(3)}`;
}

function meetingJoinUrl(code: string) {
  const base = env.FRONTEND_URL.replace(/\/$/, '');
  // Flutter web in this app uses hash routes (`/#/meet/r/...`). A path-only
  // URL drops people on login instead of the lobby.
  return `${base}/#/meet/r/${code}`;
}

async function uniqueCode() {
  for (let i = 0; i < 8; i++) {
    const code = makeMeetCode();
    const exists = await prisma.meeting.findUnique({ where: { code } });
    if (!exists) return code;
  }
  return `${makeMeetCode()}-${crypto.randomBytes(2).toString('hex')}`;
}

function canAdminMeetings(user: { roleName?: string; role?: string; permissions?: Record<string, string[]> }) {
  if (isAdminRole(user)) return true;
  return (user.permissions?.MEETINGS ?? []).includes('READ');
}

function isAdminRole(user: { roleName?: string; role?: string }) {
  const role = String(user.roleName ?? user.role ?? '').toUpperCase().replace(/\s+/g, '');
  return ['ADMIN', 'SUPERADMIN', 'SYSTEMADMIN'].includes(role);
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isCloudinaryUrl(url: string | null | undefined) {
  return Boolean(url && /res\.cloudinary\.com|cloudinary\.com/i.test(url));
}

async function uploadRecordingToCloudinary(code: string, objectKey: string) {
  const creds = getCloudinaryCredentials();
  if (!creds) {
    throw new Error(
      'Cloudinary is not configured. Set CLOUDINARY_URL or CLOUDINARY_CLOUD_NAME + API key/secret to save meeting recordings.',
    );
  }
  cloudinary.config(creds);

  let size = 0;
  for (let i = 0; i < 30; i++) {
    const objectStat = await collabStorage.objectStat(objectKey);
    if (objectStat && objectStat.size > 0) {
      size = objectStat.size;
      break;
    }
    await sleep(1000);
  }
  if (!size) {
    throw new Error('Recording file is not in storage yet. Wait a few seconds and try Watch recording again.');
  }

  const safeId = code.replace(/[^a-z0-9-]/gi, '') || `meet-${Date.now()}`;
  const tmp = path.join(os.tmpdir(), `nb-meet-${safeId}-${Date.now()}.mp4`);
  await collabStorage.downloadToFile(objectKey, tmp);
  try {
    const stat = await fs.stat(tmp);
    if (!stat.size) throw new Error('Recording file is empty');
    const filePath = tmp.replace(/\\/g, '/');
    const result = (await cloudinary.uploader.upload_large(filePath, {
      resource_type: 'video',
      chunk_size: 6_000_000,
      folder: 'hrms/meetings',
      public_id: safeId,
      overwrite: true,
      invalidate: true,
      timeout: 180_000,
      access_mode: 'public',
    })) as { secure_url?: string };
    if (!result.secure_url) throw new Error('Cloudinary did not return a recording URL');
    return result.secure_url;
  } catch (err: unknown) {
    const anyErr = err as { error?: { message?: string }; message?: string };
    const detail = anyErr.error?.message || anyErr.message || String(err);
    throw new Error(`Cloudinary upload failed: ${detail}`);
  } finally {
    await fs.unlink(tmp).catch(() => undefined);
  }
}

async function waitForRecordingFile(
  meeting: { code: string; recordingKey: string | null; recordingUrl: string | null },
  attempts = 4,
) {
  let signed = await playableRecordingUrl(meeting, { lookupStorage: true });
  for (let i = 0; i < attempts && !signed.url; i++) {
    await sleep(1000);
    signed = await playableRecordingUrl(meeting, { lookupStorage: true });
  }
  return signed;
}

async function finalizeMeetingRecording(
  meeting: {
    id: string;
    code: string;
    egressId: string | null;
    recordingKey: string | null;
    recordingUrl: string | null;
  },
  progress?: ProgressFn,
) {
  const hasJob = Boolean(meeting.egressId || meeting.recordingKey || meeting.recordingUrl);
  if (!hasJob) {
    progress?.({ step: 'stop_recording', status: 'skipped', label: 'No recording to stop' });
    progress?.({ step: 'save_cloud', status: 'skipped', label: 'No recording to save' });
    return null;
  }
  progress?.({ step: 'stop_recording', status: 'running', label: 'Stopping recording' });
  if (meeting.egressId) {
    try {
      await stopRoomRecording(meeting.egressId);
    } catch (err) {
      console.warn('LiveKit egress stop failed:', err);
    }
  }
  progress?.({ step: 'stop_recording', status: 'done', label: 'Recording stopped' });

  progress?.({ step: 'save_cloud', status: 'running', label: 'Saving recording to Cloudinary' });
  const signed = await waitForRecordingFile(
    {
      code: meeting.code,
      recordingKey: meeting.recordingKey,
      recordingUrl: meeting.recordingUrl,
    },
    45,
  );
  let cloudUrl: string | null = isCloudinaryUrl(signed.url) ? signed.url : null;
  const objectKey = signed.key || meeting.recordingKey;
  if (!cloudUrl && objectKey) {
    try {
      cloudUrl = await uploadRecordingToCloudinary(meeting.code, objectKey);
    } catch (err) {
      console.warn('Cloudinary recording upload failed:', err);
      progress?.({
        step: 'save_cloud',
        status: 'error',
        label: err instanceof Error ? err.message : 'Could not save recording to Cloudinary',
      });
    }
  }
  const playbackUrl = cloudUrl || signed.url;
  if (playbackUrl) {
    progress?.({ step: 'save_cloud', status: 'done', label: 'Recording saved' });
  } else if (!getCloudinaryCredentials()) {
    progress?.({
      step: 'save_cloud',
      status: 'error',
      label: 'Cloudinary is not configured in backend/.env',
    });
  } else {
    progress?.({ step: 'save_cloud', status: 'error', label: 'Recording file was not found' });
  }
  await prisma.meeting.update({
    where: { id: meeting.id },
    data: {
      recordEnabled: false,
      recordingKey: objectKey,
      recordingUrl: playbackUrl,
      egressId: null,
    },
  });
  return { key: objectKey, url: playbackUrl };
}

function canRecordMeeting(
  meetingHostId: string,
  user: { id: string; roleName?: string; role?: string; permissions?: Record<string, string[]> },
) {
  return meetingHostId === user.id || canAdminMeetings(user);
}

async function resolveRecordingKey(
  meeting: { code: string; recordingKey: string | null; recordingUrl: string | null },
  opts?: { index?: Map<string, string>; lookupStorage?: boolean },
) {
  if (meeting.recordingKey) return meeting.recordingKey;
  const stored = meeting.recordingUrl?.match(/meetings\/[^/?#]+\.mp4/i)?.[0];
  if (stored) return stored;
  if (opts?.index) return opts.index.get(meeting.code) ?? null;
  if (!opts?.lookupStorage) return null;
  try {
    const keys = await collabStorage.listObjectKeys(`meetings/${meeting.code}`);
    keys.sort();
    return keys.length ? keys[keys.length - 1] : null;
  } catch {
    return null;
  }
}

async function playableRecordingUrl(
  meeting: { code: string; recordingKey: string | null; recordingUrl: string | null },
  opts?: { index?: Map<string, string>; lookupStorage?: boolean },
) {
  if (isCloudinaryUrl(meeting.recordingUrl)) {
    return { key: meeting.recordingKey, url: meeting.recordingUrl };
  }
  const key = await resolveRecordingKey(meeting, opts);
  if (key && collabStorage.isMinioConfigured()) {
    try {
      if (await collabStorage.objectExists(key)) {
        return { key, url: await collabStorage.presignGet(key) };
      }
    } catch (err) {
      console.warn('Could not sign meeting recording:', err);
    }
  }
  if (meeting.recordingUrl) return { key, url: meeting.recordingUrl };
  return { key, url: null as string | null };
}

function serializeParticipant(p: {
  id: string;
  userId: string | null;
  guestName: string | null;
  role: string;
  admission?: string;
  photoUrl: string | null;
  email: string | null;
  joinedAt: Date | null;
  leftAt: Date | null;
  profile?: { name: string; photoUrl: string | null; email: string | null; department?: string | null } | null;
}) {
  return {
    id: p.id,
    userId: p.userId,
    name: p.profile?.name || p.guestName || 'Guest',
    photoUrl: p.profile?.photoUrl || p.photoUrl,
    email: p.profile?.email || p.email,
    department: p.profile?.department || null,
    role: p.role,
    admission: p.admission || 'ADMITTED',
    isGuest: !p.userId,
    joinedAt: p.joinedAt,
    leftAt: p.leftAt,
  };
}

async function serializeMeeting(meetingId: string, viewerUserId?: string | null) {
  const meeting = await prisma.meeting.findUnique({
    where: { id: meetingId },
    include: { participants: true },
  });
  if (!meeting) return null;
  const profiles = await getProfiles(
    meeting.participants.map((p) => p.userId).filter((id): id is string => Boolean(id)),
  );
  const host = profiles.get(meeting.hostUserId) ?? (await getProfile(meeting.hostUserId));
  const recordingUrl = meeting.recordingUrl || null;
    const hasRecording = Boolean(recordingUrl);
  return {
    id: meeting.id,
    code: meeting.code,
    title: meeting.title,
    agenda: meeting.agenda,
    status: meeting.status,
    scheduledStart: meeting.scheduledStart,
    scheduledEnd: meeting.scheduledEnd,
    startedAt: meeting.startedAt,
    endedAt: meeting.endedAt,
    allowGuests: meeting.allowGuests,
    waitingRoom: meeting.waitingRoom,
    recordEnabled: meeting.recordEnabled,
    hasRecording,
    recordingUrl,
    summaryText: meeting.summaryText,
    livekitRoom: meeting.livekitRoom,
    host,
    hostUserId: meeting.hostUserId,
    isHost: viewerUserId === meeting.hostUserId,
    joinUrl: meetingJoinUrl(meeting.code),
    participants: meeting.participants
      .filter((p) => p.admission !== 'WAITING' && p.admission !== 'DENIED')
      .map((p) =>
        serializeParticipant({ ...p, profile: p.userId ? profiles.get(p.userId) ?? null : null }),
      ),
    waitingParticipants: meeting.participants
      .filter((p) => p.admission === 'WAITING')
      .map((p) =>
        serializeParticipant({ ...p, profile: p.userId ? profiles.get(p.userId) ?? null : null }),
      ),
  };
}

export type GuestActor = {
  kind: 'guest';
  participantId: string;
  meetingId: string;
  name: string;
  photoUrl: string | null;
};

export type UserActor = {
  kind: 'user';
  userId: string;
  name: string;
  photoUrl: string | null;
};

export const meetService = {
  canAdminMeetings,

  async create(
    hostUserId: string,
    input: {
      title: string;
      agenda?: string;
      scheduledStart?: string;
      scheduledEnd?: string;
      inviteeIds?: string[];
      allowGuests?: boolean;
      waitingRoom?: boolean;
      recordEnabled?: boolean;
      instant?: boolean;
    },
  ) {
    const host = await getProfile(hostUserId);
    if (!host) throw new Error('Host not found');
    const title = (input.title || 'Meeting').trim();
    const code = await uniqueCode();
    const instant = input.instant !== false && !input.scheduledStart;
    const meeting = await prisma.meeting.create({
      data: {
        code,
        title,
        agenda: input.agenda?.trim() || null,
        hostUserId,
        scheduledStart: input.scheduledStart ? new Date(input.scheduledStart) : instant ? new Date() : null,
        scheduledEnd: input.scheduledEnd ? new Date(input.scheduledEnd) : null,
        status: instant ? 'LIVE' : 'SCHEDULED',
        startedAt: instant ? new Date() : null,
        livekitRoom: `crm-${code.replace(/-/g, '')}`,
        allowGuests: input.allowGuests !== false,
        waitingRoom: Boolean(input.waitingRoom),
        recordEnabled: Boolean(input.recordEnabled),
        participants: {
          create: [
            {
              userId: hostUserId,
              role: 'HOST',
              admission: 'ADMITTED',
              photoUrl: host.photoUrl,
              email: host.email,
              joinedAt: instant ? new Date() : null,
            },
            ...(input.inviteeIds ?? [])
              .filter((id) => id && id !== hostUserId)
              .map((userId) => ({
                userId,
                role: 'ATTENDEE' as const,
                admission: 'ADMITTED' as const,
              })),
          ],
        },
      },
    });
    const serialized = await serializeMeeting(meeting.id, hostUserId);
    if (input.inviteeIds?.length) {
      await this.notifyInvitees(meeting.id, input.inviteeIds.filter((id) => id !== hostUserId));
    }
    return serialized;
  },

  async listMine(userId: string) {
    const rows = await prisma.meeting.findMany({
      where: {
        OR: [{ hostUserId: userId }, { participants: { some: { userId } } }],
      },
      orderBy: [{ scheduledStart: 'desc' }, { createdAt: 'desc' }],
      take: 100,
    });
    return Promise.all(rows.map((m) => serializeMeeting(m.id, userId)));
  },

  async listAdmin() {
    const rows = await prisma.meeting.findMany({
      orderBy: [{ scheduledStart: 'desc' }, { createdAt: 'desc' }],
      take: 300,
      include: {
        host: {
          include: {
            employee: { select: { photoUrl: true, generalInfo: { select: { fullName: true } } } },
            role: { select: { name: true } },
          },
        },
        participants: true,
      },
    });
    return rows.map((m) => ({
      id: m.id,
      code: m.code,
      title: m.title,
      agenda: m.agenda,
      status: m.status,
      scheduledStart: m.scheduledStart,
      scheduledEnd: m.scheduledEnd,
      startedAt: m.startedAt,
      endedAt: m.endedAt,
      hostName: m.host.employee?.generalInfo?.fullName || m.host.username || 'Host',
      attendeeCount: m.participants.length,
      hasRecording: Boolean(m.recordingUrl),
      recordingUrl: m.recordingUrl,
      joinUrl: meetingJoinUrl(m.code),
    }));
  },

  async getByCode(code: string, viewerUserId?: string | null) {
    const meeting = await prisma.meeting.findUnique({ where: { code: code.trim().toLowerCase() } });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.status === 'LIVE') {
      await this.closeAbandonedLive(meeting.id);
    }
    return serializeMeeting(meeting.id, viewerUserId);
  },

  async getById(id: string, viewerUserId?: string | null) {
    const data = await serializeMeeting(id, viewerUserId);
    if (!data) throw new Error('Meeting not found');
    return data;
  },

  async cancel(id: string, userId: string) {
    const meeting = await prisma.meeting.findUnique({ where: { id } });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.hostUserId !== userId) throw new Error('Only the host can cancel');
    if (meeting.status === 'ENDED') throw new Error('Meeting already ended');
    await prisma.meeting.update({ where: { id }, data: { status: 'CANCELLED', endedAt: new Date() } });
    return serializeMeeting(id, userId);
  },

  async invite(id: string, hostUserId: string, userIds: string[]) {
    const meeting = await prisma.meeting.findUnique({ where: { id } });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.hostUserId !== hostUserId) throw new Error('Only the host can invite');
    const added: string[] = [];
    for (const userId of userIds) {
      const existing = await prisma.meetingParticipant.findFirst({ where: { meetingId: id, userId } });
      if (existing) continue;
      const profile = await getProfile(userId);
      await prisma.meetingParticipant.create({
        data: {
          meetingId: id,
          userId,
          role: 'ATTENDEE',
          admission: 'ADMITTED',
          photoUrl: profile?.photoUrl,
          email: profile?.email,
        },
      });
      added.push(userId);
    }
    const serialized = await serializeMeeting(id, hostUserId);
    if (added.length) await this.notifyInvitees(id, added);
    return serialized;
  },

  async update(
    id: string,
    hostUserId: string,
    input: {
      title?: string;
      agenda?: string;
      scheduledStart?: string;
      scheduledEnd?: string | null;
      waitingRoom?: boolean;
      recordEnabled?: boolean;
      allowGuests?: boolean;
      inviteeIds?: string[];
    },
  ) {
    const meeting = await prisma.meeting.findUnique({
      where: { id },
      include: { participants: true },
    });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.hostUserId !== hostUserId) throw new Error('Only the host can edit this meeting');
    if (meeting.status !== 'SCHEDULED') throw new Error('Only scheduled meetings can be edited');

    const title = input.title !== undefined ? input.title.trim() : meeting.title;
    if (!title) throw new Error('Title is required');

    await prisma.meeting.update({
      where: { id },
      data: {
        title,
        agenda: input.agenda !== undefined ? input.agenda.trim() || null : meeting.agenda,
        scheduledStart: input.scheduledStart ? new Date(input.scheduledStart) : meeting.scheduledStart,
        scheduledEnd:
          input.scheduledEnd === undefined
            ? meeting.scheduledEnd
            : input.scheduledEnd
              ? new Date(input.scheduledEnd)
              : null,
        waitingRoom: input.waitingRoom ?? meeting.waitingRoom,
        recordEnabled: input.recordEnabled ?? meeting.recordEnabled,
        allowGuests: input.allowGuests ?? meeting.allowGuests,
      },
    });

    let addedIds: string[] = [];
    if (input.inviteeIds) {
      const wanted = new Set(input.inviteeIds.filter((uid) => uid && uid !== hostUserId));
      const existing = meeting.participants.filter((p) => p.userId && p.userId !== hostUserId);
      for (const row of existing) {
        if (!row.userId || wanted.has(row.userId)) continue;
        if (row.joinedAt) continue;
        await prisma.meetingParticipant.delete({ where: { id: row.id } });
      }
      const have = new Set(existing.map((p) => p.userId).filter((uid): uid is string => Boolean(uid)));
      addedIds = [...wanted].filter((uid) => !have.has(uid));
      for (const userId of addedIds) {
        const profile = await getProfile(userId);
        await prisma.meetingParticipant.create({
          data: {
            meetingId: id,
            userId,
            role: 'ATTENDEE',
            admission: 'ADMITTED',
            photoUrl: profile?.photoUrl,
            email: profile?.email,
          },
        });
      }
    }

    const serialized = await serializeMeeting(id, hostUserId);
    if (addedIds.length) await this.notifyInvitees(id, addedIds);
    return serialized;
  },

  async notifyInvitees(meetingId: string, inviteeIds: string[]) {
    const unique = [...new Set(inviteeIds.filter(Boolean))];
    if (unique.length === 0) return;
    const meeting = await prisma.meeting.findUnique({ where: { id: meetingId } });
    if (!meeting) return;
    const [host, profiles] = await Promise.all([getProfile(meeting.hostUserId), getProfiles(unique)]);
    const emails = unique
      .map((id) => profiles.get(id)?.email)
      .filter((e): e is string => Boolean(e));
    const when = (meeting.scheduledStart || meeting.createdAt).toLocaleString();
    const joinUrl = meetingJoinUrl(meeting.code);
    try {
      await sendMeetingInviteEmail({
        to: emails,
        title: meeting.title,
        code: meeting.code,
        when,
        agenda: meeting.agenda,
        hostName: host?.name || 'Host',
        joinUrl,
      });
    } catch (err) {
      console.warn('Meeting invite email failed:', err);
    }
    return {
      meetingId,
      title: meeting.title,
      code: meeting.code,
      agenda: meeting.agenda,
      scheduledStart: meeting.scheduledStart,
      hostName: host?.name || 'Host',
      joinUrl,
      inviteeIds: unique,
    };
  },

  async joinAsUser(code: string, userId: string) {
    const meeting = await prisma.meeting.findUnique({
      where: { code: code.trim().toLowerCase() },
      include: { participants: true },
    });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.status === 'CANCELLED') throw new Error('This meeting was cancelled');
    if (meeting.status === 'ENDED') throw new Error('This meeting has ended');

    const profile = await getProfile(userId);
    if (!profile) throw new Error('User not found');

    const isHost = meeting.hostUserId === userId;

    let participant = meeting.participants.find((p) => p.userId === userId);
    if (participant?.admission === 'DENIED' && meeting.waitingRoom && !isHost) {
      throw new Error('The host declined your request to join');
    }

    // Host always enters. Waiting room only knocks other people, and only when
    // the host turned it on. Invitees already admitted (joinedAt set) may re-enter.
    const previouslyLetIn =
      isHost ||
      participant?.role === 'HOST' ||
      (participant?.admission === 'ADMITTED' && participant.joinedAt != null);
    const nextAdmission = isHost || !meeting.waitingRoom || previouslyLetIn ? 'ADMITTED' : 'WAITING';

    if (!participant) {
      participant = await prisma.meetingParticipant.create({
        data: {
          meetingId: meeting.id,
          userId,
          role: isHost ? 'HOST' : 'ATTENDEE',
          admission: nextAdmission,
          photoUrl: profile.photoUrl,
          email: profile.email,
          joinedAt: nextAdmission === 'ADMITTED' ? new Date() : null,
        },
      });
    } else {
      participant = await prisma.meetingParticipant.update({
        where: { id: participant.id },
        data: {
          leftAt: null,
          photoUrl: profile.photoUrl,
          admission: nextAdmission,
          joinedAt: nextAdmission === 'ADMITTED' ? new Date() : participant.joinedAt,
          role: isHost ? 'HOST' : participant.role,
        },
      });
    }

    if (meeting.status === 'SCHEDULED' && (isHost || nextAdmission === 'ADMITTED')) {
      await prisma.meeting.update({
        where: { id: meeting.id },
        data: { status: 'LIVE', startedAt: meeting.startedAt ?? new Date() },
      });
    }

    if (nextAdmission === 'WAITING') {
      return {
        waiting: true,
        meeting: await serializeMeeting(meeting.id, userId),
        participant: serializeParticipant({ ...participant, profile }),
      };
    }

    await Promise.race([
      removeLiveKitParticipant(meeting.livekitRoom, `user:${userId}`),
      sleep(2000),
    ]);
    const token = await issueLiveKitToken({
      roomName: meeting.livekitRoom,
      identity: `user:${userId}`,
      name: profile.name,
      metadata: { userId, photoUrl: profile.photoUrl, role: participant.role },
    });

    return {
      waiting: false,
      meeting: await serializeMeeting(meeting.id, userId),
      livekit: { url: livekitPublicUrl(), token, room: meeting.livekitRoom },
      participant: serializeParticipant({ ...participant, profile }),
    };
  },

  async guestJoin(code: string, displayName: string, email?: string) {
    const meeting = await prisma.meeting.findUnique({
      where: { code: code.trim().toLowerCase() },
    });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.status === 'CANCELLED') throw new Error('This meeting was cancelled');
    if (meeting.status === 'ENDED') throw new Error('This meeting has ended');
    const name = displayName.trim();
    if (name.length < 2) throw new Error('Please enter your name');

    if (meeting.allowGuests === false) {
      throw new Error('This meeting does not allow guests');
    }

    const guestToken = crypto.randomBytes(24).toString('hex');
    const admission = meeting.waitingRoom ? 'WAITING' : 'ADMITTED';
    const participant = await prisma.meetingParticipant.create({
      data: {
        meetingId: meeting.id,
        guestName: name,
        guestToken,
        role: 'GUEST',
        admission,
        email: email?.trim() || null,
        joinedAt: admission === 'ADMITTED' ? new Date() : null,
      },
    });

    if (meeting.status === 'SCHEDULED' && admission === 'ADMITTED') {
      await prisma.meeting.update({
        where: { id: meeting.id },
        data: { status: 'LIVE', startedAt: meeting.startedAt ?? new Date() },
      });
    }

    const appJwt = jwt.sign(
      {
        typ: 'meet-guest',
        meetingId: meeting.id,
        participantId: participant.id,
        name,
      },
      env.JWT_SECRET,
      { expiresIn: '12h' },
    );

    if (admission === 'WAITING') {
      return {
        waiting: true,
        guestToken: appJwt,
        meeting: await serializeMeeting(meeting.id),
        participant: serializeParticipant({ ...participant, profile: null }),
      };
    }

    const token = await issueLiveKitToken({
      roomName: meeting.livekitRoom,
      identity: `guest:${participant.id}`,
      name,
      metadata: { guest: true, participantId: participant.id },
    });

    return {
      waiting: false,
      guestToken: appJwt,
      meeting: await serializeMeeting(meeting.id),
      livekit: { url: livekitPublicUrl(), token, room: meeting.livekitRoom },
      participant: serializeParticipant({ ...participant, profile: null }),
    };
  },

  async enterAsGuest(actor: GuestActor) {
    const participant = await prisma.meetingParticipant.findUnique({
      where: { id: actor.participantId },
      include: { meeting: true },
    });
    if (!participant || participant.meetingId !== actor.meetingId) {
      throw new Error('Guest session is not valid');
    }
    const meeting = participant.meeting;
    if (meeting.status === 'CANCELLED') throw new Error('This meeting was cancelled');
    if (meeting.status === 'ENDED') throw new Error('This meeting has ended');
    if (participant.admission === 'DENIED') {
      throw new Error('The host declined your request to join');
    }
    if (participant.admission !== 'ADMITTED') {
      return {
        waiting: true,
        meeting: await serializeMeeting(meeting.id),
        participant: serializeParticipant({ ...participant, profile: null }),
      };
    }

    const name = participant.guestName || actor.name;
    const token = await issueLiveKitToken({
      roomName: meeting.livekitRoom,
      identity: `guest:${participant.id}`,
      name,
      metadata: { guest: true, participantId: participant.id },
    });
    return {
      waiting: false,
      meeting: await serializeMeeting(meeting.id),
      livekit: { url: livekitPublicUrl(), token, room: meeting.livekitRoom },
      participant: serializeParticipant({ ...participant, profile: null }),
    };
  },

  async admit(meetingId: string, hostUserId: string, participantId: string) {
    const meeting = await prisma.meeting.findUnique({ where: { id: meetingId } });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.hostUserId !== hostUserId) throw new Error('Only the host can admit people');
    const participant = await prisma.meetingParticipant.findUnique({ where: { id: participantId } });
    if (!participant || participant.meetingId !== meetingId) throw new Error('Participant not found');

    const updated = await prisma.meetingParticipant.update({
      where: { id: participantId },
      data: { admission: 'ADMITTED', joinedAt: new Date(), leftAt: null },
    });

    if (meeting.status === 'SCHEDULED') {
      await prisma.meeting.update({
        where: { id: meetingId },
        data: { status: 'LIVE', startedAt: meeting.startedAt ?? new Date() },
      });
    }

    const profile = updated.userId ? await getProfile(updated.userId) : null;
    return {
      meeting: await serializeMeeting(meetingId, hostUserId),
      participant: serializeParticipant({ ...updated, profile }),
    };
  },

  async deny(meetingId: string, hostUserId: string, participantId: string) {
    const meeting = await prisma.meeting.findUnique({ where: { id: meetingId } });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.hostUserId !== hostUserId) throw new Error('Only the host can decline people');
    const participant = await prisma.meetingParticipant.findUnique({ where: { id: participantId } });
    if (!participant || participant.meetingId !== meetingId) throw new Error('Participant not found');

    const updated = await prisma.meetingParticipant.update({
      where: { id: participantId },
      data: { admission: 'DENIED', leftAt: new Date() },
    });
    const profile = updated.userId ? await getProfile(updated.userId) : null;
    return {
      meeting: await serializeMeeting(meetingId, hostUserId),
      participant: serializeParticipant({ ...updated, profile }),
    };
  },

  /** End a LIVE meeting if nobody is still connected (tab closed / hung up). */
  async closeAbandonedLive(meetingId: string) {
    const meeting = await prisma.meeting.findUnique({
      where: { id: meetingId },
      include: { participants: { select: { userId: true } } },
    });
    if (!meeting || meeting.status !== 'LIVE') return false;
    const started = meeting.startedAt ?? meeting.createdAt;
    if (Date.now() - started.getTime() < 90_000) return false;
    let occupied = false;
    try {
      const { getIo } = await import('./socket');
      const io = getIo();
      if (io) {
        const sockets = await io.in(`meeting:${meeting.id}`).fetchSockets();
        occupied = sockets.length > 0;
      }
    } catch {
      occupied = false;
    }
    if (occupied) return false;
    await prisma.meeting.update({
      where: { id: meeting.id },
      data: { status: 'ENDED', endedAt: new Date() },
    });
    try {
      await deleteLiveKitRoom(meeting.livekitRoom);
    } catch {
      /* room may already be gone */
    }
    try {
      const { emitMeetingEnded } = await import('./socket');
      emitMeetingEnded({
        meetingId: meeting.id,
        code: meeting.code,
        userIds: [
          meeting.hostUserId,
          ...meeting.participants.map((p) => p.userId).filter((id): id is string => Boolean(id)),
        ],
      });
    } catch {
      /* sockets optional */
    }
    return true;
  },

  async endMeeting(
    id: string,
    userId: string,
    onClosed?: (ended: { meetingId: string; code: string; userIds: string[] }) => void,
    onProgress?: ProgressFn,
  ) {
    const meeting = await prisma.meeting.findUnique({
      where: { id },
      include: { participants: true, chatMessages: { orderBy: { createdAt: 'asc' } } },
    });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.hostUserId !== userId) throw new Error('Only the host can end the meeting');
    if (meeting.status === 'ENDED') return serializeMeeting(id, userId);

    await finalizeMeetingRecording(meeting, onProgress);

    onProgress?.({ step: 'close_room', status: 'running', label: 'Closing the meeting room' });
    await prisma.meeting.update({
      where: { id },
      data: { status: 'ENDED', endedAt: new Date() },
    });
    await deleteLiveKitRoom(meeting.livekitRoom);
    onClosed?.({
      meetingId: meeting.id,
      code: meeting.code,
      userIds: [
        meeting.hostUserId,
        ...meeting.participants.map((p) => p.userId).filter((x): x is string => Boolean(x)),
      ],
    });
    onProgress?.({ step: 'close_room', status: 'done', label: 'Meeting closed' });

    onProgress?.({ step: 'summary', status: 'running', label: 'Preparing meeting summary' });

    const profiles = await getProfiles(
      [
        meeting.hostUserId,
        ...meeting.participants.map((p) => p.userId).filter((x): x is string => Boolean(x)),
        ...meeting.chatMessages.map((c) => c.senderUserId).filter((x): x is string => Boolean(x)),
      ],
    );
    const host = profiles.get(meeting.hostUserId);
    const attendees = meeting.participants.map(
      (p) => (p.userId ? profiles.get(p.userId)?.name : p.guestName) || 'Guest',
    );
    const transcript = meeting.chatMessages.map((c) => ({
      who: c.senderUserId
        ? profiles.get(c.senderUserId)?.name || 'Member'
        : c.senderGuestName || 'Guest',
      at: c.createdAt,
      text: c.content,
      scope: c.scope,
    }));

    let summary = 'Meeting ended.';
    try {
      summary = await generateMeetingSummary({
        title: meeting.title,
        agenda: meeting.agenda,
        hostName: host?.name || 'Host',
        startedAt: meeting.startedAt,
        endedAt: new Date(),
        attendees,
        transcript,
      });
      await prisma.meeting.update({
        where: { id },
        data: {
          summaryText: summary,
          summarySentAt: new Date(),
        },
      });
    } catch (err) {
      console.warn('Meeting summary failed:', err);
    }

    const emails = [
      host?.email,
      ...meeting.participants.map((p) => p.email || (p.userId ? profiles.get(p.userId)?.email : null)),
    ].filter((e): e is string => Boolean(e));

    const when = (meeting.startedAt || meeting.scheduledStart || meeting.createdAt).toLocaleString();
    try {
      await sendMeetingSummaryEmail({
        to: emails,
        title: meeting.title,
        code: meeting.code,
        when,
        agenda: meeting.agenda,
        summary,
        joinUrl: meetingJoinUrl(meeting.code),
      });
    } catch (err) {
      console.warn('Meeting summary email failed:', err);
    }

    onProgress?.({ step: 'summary', status: 'done', label: 'All done' });
    return serializeMeeting(id, userId);
  },

  async startRecording(
    id: string,
    user: { id: string; roleName?: string; role?: string; permissions?: Record<string, string[]> },
  ) {
    const meeting = await prisma.meeting.findUnique({ where: { id } });
    if (!meeting) throw new Error('Meeting not found');
    if (!canRecordMeeting(meeting.hostUserId, user)) {
      throw new Error('Only the host or an admin can record');
    }
    if (meeting.status !== 'LIVE') throw new Error('Start the meeting before recording');
    try {
      const rec = await startRoomRecording(meeting.livekitRoom, `${meeting.code}-${Date.now()}`);
      await prisma.meeting.update({
        where: { id },
        data: {
          recordEnabled: true,
          egressId: rec.egressId,
          recordingKey: rec.filepath,
          recordingUrl: null,
        },
      });
    } catch (err) {
      console.warn('LiveKit egress not available:', err);
      throw new Error(
        err instanceof Error && err.message
          ? err.message
          : 'Recording is not available. Start LiveKit egress and MinIO.',
      );
    }
    return serializeMeeting(id, user.id);
  },

  async stopRecording(
    id: string,
    user: { id: string; roleName?: string; role?: string; permissions?: Record<string, string[]> },
  ) {
    const meeting = await prisma.meeting.findUnique({ where: { id } });
    if (!meeting) throw new Error('Meeting not found');
    if (!canRecordMeeting(meeting.hostUserId, user)) {
      throw new Error('Only the host or an admin can stop recording');
    }
    await finalizeMeetingRecording(meeting);
    return serializeMeeting(id, user.id);
  },

  async getRecordingPlayback(
    id: string,
    user: { id: string; roleName?: string; role?: string; permissions?: Record<string, string[]> },
  ) {
    const meeting = await prisma.meeting.findUnique({
      where: { id },
      include: { participants: true },
    });
    if (!meeting) throw new Error('Meeting not found');
    const allowed =
      meeting.hostUserId === user.id ||
      meeting.participants.some((p) => p.userId === user.id) ||
      canAdminMeetings(user);
    if (!allowed) throw new Error('You do not have access to this recording');
    let signed = await playableRecordingUrl(meeting, { lookupStorage: true });
    if (!signed.url && (meeting.recordingKey || meeting.egressId)) {
      signed = await waitForRecordingFile(meeting, 8);
    }
    if (!signed.url && !meeting.recordingKey && !meeting.recordingUrl) {
      throw new Error('No recording is available for this meeting');
    }
    if (signed.key && signed.key !== meeting.recordingKey) {
      await prisma.meeting.update({
        where: { id },
        data: { recordingKey: signed.key, recordingUrl: signed.url },
      });
    }
    const profiles = await getProfiles(
      meeting.participants.map((p) => p.userId).filter((uid): uid is string => Boolean(uid)),
    );
    const host = profiles.get(meeting.hostUserId) ?? (await getProfile(meeting.hostUserId));
    return {
      url: signed.url || '',
      ready: Boolean(signed.url),
      title: meeting.title,
      code: meeting.code,
      agenda: meeting.agenda,
      summaryText: meeting.summaryText,
      startedAt: meeting.startedAt,
      endedAt: meeting.endedAt,
      hostName: host?.name || 'Host',
      canDelete: isAdminRole(user),
      attendees: meeting.participants
        .filter((p) => p.admission !== 'WAITING' && p.admission !== 'DENIED')
        .map((p) =>
          serializeParticipant({ ...p, profile: p.userId ? profiles.get(p.userId) ?? null : null }),
        ),
    };
  },

  async deleteRecording(
    id: string,
    user: { id: string; roleName?: string; role?: string; permissions?: Record<string, string[]> },
  ) {
    if (!isAdminRole(user)) {
      throw new Error('Only an admin can delete a meeting recording');
    }
    const meeting = await prisma.meeting.findUnique({ where: { id } });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.recordEnabled && meeting.egressId) {
      throw new Error('Stop recording before deleting it');
    }
    const key = await resolveRecordingKey(meeting, { lookupStorage: true });
    if (key) {
      await collabStorage.removeObject(key);
    }
    try {
      const extras = await collabStorage.listObjectKeys(`meetings/${meeting.code}`);
      for (const extra of extras) {
        await collabStorage.removeObject(extra);
      }
    } catch (err) {
      console.warn('Could not list meeting recordings to delete:', err);
    }
    await prisma.meeting.update({
      where: { id },
      data: {
        recordingUrl: null,
        recordingKey: null,
        egressId: null,
      },
    });
    return serializeMeeting(id, user.id);
  },

  async postChat(opts: {
    meetingId: string;
    actor: UserActor | GuestActor;
    content: string;
    scope?: 'ROOM' | 'DIRECT';
    recipientUserId?: string;
  }) {
    const content = opts.content.trim();
    if (!content) throw new Error('Message is empty');
    const meeting = await prisma.meeting.findUnique({ where: { id: opts.meetingId } });
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.status === 'ENDED' || meeting.status === 'CANCELLED') {
      throw new Error('Meeting is not active');
    }
    const scope = opts.scope === 'DIRECT' ? 'DIRECT' : 'ROOM';
    if (scope === 'DIRECT' && !opts.recipientUserId && opts.actor.kind === 'user') {
      throw new Error('Direct messages need a recipient');
    }
    const row = await prisma.meetingChatMessage.create({
      data: {
        meetingId: opts.meetingId,
        senderUserId: opts.actor.kind === 'user' ? opts.actor.userId : null,
        senderGuestName: opts.actor.kind === 'guest' ? opts.actor.name : null,
        senderPhotoUrl: opts.actor.photoUrl,
        scope,
        recipientUserId: scope === 'DIRECT' ? opts.recipientUserId || null : null,
        content,
      },
    });
    return {
      id: row.id,
      meetingId: row.meetingId,
      senderUserId: row.senderUserId,
      senderName: opts.actor.name,
      senderPhotoUrl: opts.actor.photoUrl,
      scope: row.scope,
      recipientUserId: row.recipientUserId,
      content: row.content,
      createdAt: row.createdAt,
    };
  },

  async listChat(meetingId: string, actor: UserActor | GuestActor) {
    const rows = await prisma.meetingChatMessage.findMany({
      where: { meetingId },
      orderBy: { createdAt: 'asc' },
      take: 500,
    });
    const profiles = await getProfiles(
      rows.map((r) => r.senderUserId).filter((id): id is string => Boolean(id)),
    );
    return rows
      .filter((r) => {
        if (r.scope === 'ROOM') return true;
        if (actor.kind === 'guest') return false;
        return r.senderUserId === actor.userId || r.recipientUserId === actor.userId;
      })
      .map((r) => ({
        id: r.id,
        meetingId: r.meetingId,
        senderUserId: r.senderUserId,
        senderName: r.senderUserId
          ? profiles.get(r.senderUserId)?.name || 'Member'
          : r.senderGuestName || 'Guest',
        senderPhotoUrl: r.senderUserId
          ? profiles.get(r.senderUserId)?.photoUrl || r.senderPhotoUrl
          : r.senderPhotoUrl,
        scope: r.scope,
        recipientUserId: r.recipientUserId,
        content: r.content,
        createdAt: r.createdAt,
      }));
  },

  async resolveGuest(token: string): Promise<GuestActor | null> {
    try {
      const decoded = jwt.verify(token, env.JWT_SECRET) as jwt.JwtPayload;
      if (decoded.typ !== 'meet-guest') return null;
      const participant = await prisma.meetingParticipant.findUnique({
        where: { id: String(decoded.participantId) },
      });
      if (!participant || participant.meetingId !== decoded.meetingId) return null;
      return {
        kind: 'guest',
        participantId: participant.id,
        meetingId: participant.meetingId,
        name: participant.guestName || String(decoded.name || 'Guest'),
        photoUrl: participant.photoUrl,
      };
    } catch {
      return null;
    }
  },
};
