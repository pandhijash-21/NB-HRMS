import type { ChatMessage, ChatReaction, ChatAttachment } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { getProfile, getProfiles, searchDirectory, type CollabProfile } from './profiles';
import { collabStorage } from './storage';

export { searchDirectory };

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** WhatsApp-style @Name / @all against channel members. */
export function mentionedUserIdsFromText(
  content: string | null | undefined,
  members: { userId: string; name: string }[],
  isGroup: boolean,
  senderId: string,
): string[] {
  if (!content) return [];
  const others = members.filter((m) => m.userId !== senderId);
  if (isGroup && /(^|[\s])@all\b/i.test(content)) {
    return others.map((m) => m.userId);
  }
  const ids = new Set<string>();
  const sorted = [...others].sort((a, b) => b.name.length - a.name.length);
  for (const m of sorted) {
    const name = m.name.trim();
    if (name.length < 1) continue;
    const re = new RegExp(`(^|[\\s])@${escapeRegExp(name)}(?=$|[\\s,.!?])`, 'i');
    if (re.test(content)) ids.add(m.userId);
  }
  return [...ids];
}

function directKeyFor(a: string, b: string) {
  return [a, b].sort().join(':');
}

function groupReactions(reactions: ChatReaction[], me: string) {
  const map = new Map<string, { emoji: string; count: number; mine: boolean; userIds: string[] }>();
  for (const r of reactions) {
    const cur = map.get(r.emoji) ?? { emoji: r.emoji, count: 0, mine: false, userIds: [] };
    cur.count += 1;
    cur.userIds.push(r.userId);
    if (r.userId === me) cur.mine = true;
    map.set(r.emoji, cur);
  }
  return [...map.values()];
}

type MessageRow = ChatMessage & {
  attachments: ChatAttachment[];
  reactions: ChatReaction[];
  sender?: { id: string };
  replyTo?: ChatMessage | null;
};

async function serializeMessages(rows: MessageRow[], me: string, members: ReceiptMember[] = []) {
  const senderIds = [
    ...rows.map((m) => m.senderId),
    ...rows.map((m) => m.replyTo?.senderId).filter((id): id is string => Boolean(id)),
  ];
  const profiles = await getProfiles(senderIds);
  return Promise.all(
    rows.map(async (m) => {
      const { seenBy, unseenBy } = peopleReceipts(m, members);
      return {
        id: m.id,
        channelId: m.channelId,
        senderId: m.senderId,
        sender: profiles.get(m.senderId) ?? null,
        content: m.deletedAt ? null : m.content,
        replyToId: m.replyToId,
        replyTo: m.replyTo
          ? {
              id: m.replyTo.id,
              content: m.replyTo.deletedAt ? 'This message was deleted' : m.replyTo.content,
              senderId: m.replyTo.senderId,
              senderName: profiles.get(m.replyTo.senderId)?.name ?? 'Member',
            }
          : null,
        createdAt: m.createdAt,
        editedAt: m.editedAt,
        deletedAt: m.deletedAt,
        attachments: m.deletedAt
          ? []
          : await Promise.all(
              m.attachments.map(async (a) => ({
                id: a.id,
                fileName: a.fileName,
                mimeType: a.mimeType,
                sizeBytes: a.sizeBytes,
                bucketKey: a.bucketKey,
                fileUrl: a.scanStatus === 'INFECTED' ? null : await collabStorage.readableUrl(a.bucketKey, a.fileUrl),
                scanStatus: a.scanStatus,
              })),
            ),
        reactions: groupReactions(m.reactions, me),
        seenBy,
        unseenBy,
        mentionedUserIds: mentionedUserIdsFromText(
          m.deletedAt ? null : m.content,
          members,
          true,
          m.senderId,
        ),
      };
    }),
  );
}

type ReceiptMember = { userId: string; lastReadAt: Date | null; name: string; photoUrl: string | null };

async function receiptMembers(channelId: string): Promise<ReceiptMember[]> {
  const members = await prisma.chatChannelMember.findMany({
    where: { channelId, leftAt: null },
    select: { userId: true, lastReadAt: true },
  });
  const profiles = await getProfiles(members.map((m) => m.userId));
  return members.map((m) => ({
    userId: m.userId,
    lastReadAt: m.lastReadAt,
    name: profiles.get(m.userId)?.name || 'User',
    photoUrl: profiles.get(m.userId)?.photoUrl ?? null,
  }));
}

function peopleReceipts(message: { senderId: string; createdAt: Date }, members: ReceiptMember[]) {
  const others = members.filter((m) => m.userId !== message.senderId);
  const seenBy = others.filter((m) => m.lastReadAt && m.lastReadAt >= message.createdAt);
  const unseenBy = others.filter((m) => !m.lastReadAt || m.lastReadAt < message.createdAt);
  return {
    seenBy: seenBy.map(({ userId, name, photoUrl }) => ({ userId, name, photoUrl })),
    unseenBy: unseenBy.map(({ userId, name, photoUrl }) => ({ userId, name, photoUrl })),
  };
}

async function assertUnseenByOthers(message: { channelId: string; senderId: string; createdAt: Date }) {
  const members = await receiptMembers(message.channelId);
  const { seenBy } = peopleReceipts(message, members);
  if (seenBy.length > 0) {
    throw new Error('You can only edit or delete a message before anyone has seen it');
  }
}

async function serializeChannel(
  channelId: string,
  me: string,
  presence: (userId: string) => Promise<boolean> = async () => false,
) {
  const channel = await prisma.chatChannel.findUnique({
    where: { id: channelId },
    include: {
      members: { where: { leftAt: null } },
      messages: {
        where: { deletedAt: null },
        orderBy: { createdAt: 'desc' },
        take: 1,
              include: { attachments: true, reactions: true, replyTo: true },
      },
    },
  });
  if (!channel) return null;
  const mine = channel.members.find((m) => m.userId === me);
  if (!mine) return null;

  const profiles = await getProfiles(channel.members.map((m) => m.userId));
  const members = await Promise.all(
    channel.members.map(async (m) => {
      const profile = profiles.get(m.userId);
      return {
        userId: m.userId,
        employeeId: profile?.employeeId ?? null,
        name: profile?.name || 'User',
        photoUrl: profile?.photoUrl ?? null,
        email: profile?.email ?? null,
        role: m.role,
        username: profile?.username ?? null,
        lastReadAt: m.lastReadAt,
        online: await presence(m.userId),
      };
    }),
  );

  const unread = await prisma.chatMessage.count({
    where: {
      channelId,
      deletedAt: null,
      senderId: { not: me },
      createdAt: { gt: mine.lastReadAt ?? new Date(0) },
    },
  });

  const last = channel.messages[0];
  const isSelfDm =
    channel.type === 'DIRECT' &&
    channel.members.length > 0 &&
    channel.members.every((m) => m.userId === me);

  const other =
    channel.type === 'DIRECT' ? members.find((m) => m.userId !== me) ?? null : null;
  const selfMember = members.find((m) => m.userId === me) ?? null;

  return {
    id: channel.id,
    type: channel.type,
    name: channel.type === 'GROUP' ? channel.name : isSelfDm ? 'Note to self' : other?.name ?? channel.name,
    topic: channel.topic,
    avatarUrl: channel.type === 'GROUP' ? channel.avatarUrl : isSelfDm ? selfMember?.photoUrl ?? null : other?.photoUrl ?? null,
    createdById: channel.createdById,
    createdAt: channel.createdAt,
    updatedAt: channel.updatedAt,
    unread,
    members,
    lastMessage: last
      ? {
          id: last.id,
          content: last.content,
          senderId: last.senderId,
          createdAt: last.createdAt,
          hasAttachment: last.attachments.length > 0,
        }
      : null,
  };
}

export const chatService = {
  searchDirectory,

  async listChannels(userId: string, presence?: (id: string) => Promise<boolean>) {
    const memberships = await prisma.chatChannelMember.findMany({
      where: { userId, leftAt: null },
      select: { channelId: true },
    });
    const channels = await Promise.all(
      memberships.map((m) => serializeChannel(m.channelId, userId, presence)),
    );
    return channels
      .filter(Boolean)
      .sort((a, b) => +new Date(b!.updatedAt) - +new Date(a!.updatedAt));
  },

  async getChannel(channelId: string, userId: string, presence?: (id: string) => Promise<boolean>) {
    const data = await serializeChannel(channelId, userId, presence);
    if (!data) throw new Error('Channel not found');
    return data;
  },

  async getOrCreateDm(me: string, otherUserId: string) {
    const other = await getProfile(otherUserId);
    if (!other) throw new Error('User not found');
    const self = me === otherUserId;
    const key = directKeyFor(me, otherUserId);
    const existing = await prisma.chatChannel.findUnique({ where: { directKey: key } });
    if (existing) {
      await prisma.chatChannelMember.updateMany({
        where: {
          channelId: existing.id,
          userId: { in: [...new Set([me, otherUserId])] },
          leftAt: { not: null },
        },
        data: { leftAt: null, joinedAt: new Date() },
      });
      return this.getChannel(existing.id, me);
    }
    const channel = await prisma.chatChannel.create({
      data: {
        type: 'DIRECT',
        name: self ? 'Note to self' : null,
        directKey: key,
        createdById: me,
        members: {
          create: self
            ? [{ userId: me, role: 'owner' }]
            : [
                { userId: me, role: 'owner' },
                { userId: otherUserId, role: 'member' },
              ],
        },
      },
    });
    return this.getChannel(channel.id, me);
  },

  async createGroup(me: string, name: string, memberIds: string[], topic?: string) {
    const title = name.trim();
    if (title.length < 2) throw new Error('Group name is required');
    const unique = [...new Set(memberIds.filter((id) => id && id !== me))];
    if (unique.length < 1) throw new Error('Add at least one member');
    const channel = await prisma.chatChannel.create({
      data: {
        type: 'GROUP',
        name: title,
        topic: topic?.trim() || null,
        createdById: me,
        members: {
          create: [
            { userId: me, role: 'owner' },
            ...unique.map((userId) => ({ userId, role: 'member' })),
          ],
        },
      },
    });
    return this.getChannel(channel.id, me);
  },

  async updateGroup(
    channelId: string,
    me: string,
    patch: {
      name?: string;
      topic?: string;
      avatarUrl?: string | null;
      addMemberIds?: string[];
      removeMemberIds?: string[];
    },
  ) {
    const member = await prisma.chatChannelMember.findFirst({
      where: { channelId, userId: me, leftAt: null },
    });
    if (!member) throw new Error('Not a member of this chat');
    const channel = await prisma.chatChannel.findUnique({ where: { id: channelId } });
    if (!channel || channel.type !== 'GROUP') throw new Error('Not a group');
    if (member.role !== 'owner' && member.role !== 'admin') throw new Error('Only group admins can edit');

    if (patch.name || patch.topic !== undefined || patch.avatarUrl !== undefined) {
      await prisma.chatChannel.update({
        where: { id: channelId },
        data: {
          ...(patch.name ? { name: patch.name.trim() } : {}),
          ...(patch.topic !== undefined ? { topic: patch.topic.trim() || null } : {}),
          ...(patch.avatarUrl !== undefined ? { avatarUrl: patch.avatarUrl?.trim() || null } : {}),
        },
      });
    }
    if (patch.addMemberIds?.length) {
      for (const userId of patch.addMemberIds) {
        await prisma.chatChannelMember.upsert({
          where: { channelId_userId: { channelId, userId } },
          update: { leftAt: null, joinedAt: new Date() },
          create: { channelId, userId, role: 'member' },
        });
      }
    }
    if (patch.removeMemberIds?.length) {
      await prisma.chatChannelMember.updateMany({
        where: { channelId, userId: { in: patch.removeMemberIds }, role: { not: 'owner' } },
        data: { leftAt: new Date() },
      });
    }
    await prisma.chatChannel.update({ where: { id: channelId }, data: { updatedAt: new Date() } });
    return this.getChannel(channelId, me);
  },

  async setMemberRole(channelId: string, me: string, userId: string, role: 'admin' | 'member') {
    const actor = await prisma.chatChannelMember.findFirst({
      where: { channelId, userId: me, leftAt: null },
    });
    if (!actor || actor.role !== 'owner') throw new Error('Only the group owner can change roles');
    const channel = await prisma.chatChannel.findUnique({ where: { id: channelId } });
    if (!channel || channel.type !== 'GROUP') throw new Error('Not a group');
    if (userId === me) throw new Error('You cannot change your own role');
    const target = await prisma.chatChannelMember.findFirst({
      where: { channelId, userId, leftAt: null },
    });
    if (!target) throw new Error('Member not found');
    if (target.role === 'owner') throw new Error('Cannot change the owner role');
    await prisma.chatChannelMember.update({
      where: { id: target.id },
      data: { role },
    });
    return this.getChannel(channelId, me);
  },

  async leaveGroup(channelId: string, me: string) {
    const member = await prisma.chatChannelMember.findFirst({
      where: { channelId, userId: me, leftAt: null },
    });
    if (!member) throw new Error('Not a member of this chat');
    const channel = await prisma.chatChannel.findUnique({ where: { id: channelId } });
    if (!channel || channel.type !== 'GROUP') throw new Error('Not a group');
    const others = await prisma.chatChannelMember.findMany({
      where: { channelId, userId: { not: me }, leftAt: null },
      orderBy: { joinedAt: 'asc' },
    });
    if (member.role === 'owner' && others.length > 0) {
      const successor = others.find((m) => m.role === 'admin') ?? others[0];
      await prisma.chatChannelMember.update({
        where: { id: successor.id },
        data: { role: 'owner' },
      });
    }
    await prisma.chatChannelMember.update({
      where: { id: member.id },
      data: { leftAt: new Date() },
    });
    await prisma.chatChannel.update({ where: { id: channelId }, data: { updatedAt: new Date() } });
    return { left: true, channelId };
  },

  async listMessages(channelId: string, me: string, cursor?: string, limit = 50) {
    const member = await prisma.chatChannelMember.findFirst({
      where: { channelId, userId: me, leftAt: null },
    });
    if (!member) throw new Error('Not a member of this chat');
    const take = Math.min(Math.max(limit, 1), 100);
    const rows = await prisma.chatMessage.findMany({
      where: {
        channelId,
        ...(cursor ? { createdAt: { lt: new Date(cursor) } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take,
            include: { attachments: true, reactions: true, replyTo: true },
    });
    const receipts = await receiptMembers(channelId);
    const items = await serializeMessages(rows, me, receipts);
    return { items: items.reverse(), nextCursor: rows.length ? rows[rows.length - 1].createdAt.toISOString() : null };
  },

  async searchMessages(channelId: string, me: string, q: string) {
    const member = await prisma.chatChannelMember.findFirst({
      where: { channelId, userId: me, leftAt: null },
    });
    if (!member) throw new Error('Not a member of this chat');
    const term = q.trim();
    if (!term) return [];
    const rows = await prisma.chatMessage.findMany({
      where: {
        channelId,
        deletedAt: null,
        content: { contains: term, mode: 'insensitive' },
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
            include: { attachments: true, reactions: true, replyTo: true },
    });
    const receipts = await receiptMembers(channelId);
    return serializeMessages(rows, me, receipts);
  },

  async sendMessage(opts: {
    channelId: string;
    senderId: string;
    content?: string;
    replyToId?: string;
    attachments?: { bucketKey: string; fileUrl: string; fileName: string; mimeType: string; sizeBytes: number }[];
  }) {
    const member = await prisma.chatChannelMember.findFirst({
      where: { channelId: opts.channelId, userId: opts.senderId, leftAt: null },
    });
    if (!member) throw new Error('Not a member of this chat');
    const content = opts.content?.replace(/\r\n/g, '\n').trim() || null;
    const attachments = opts.attachments ?? [];
    if (!content && attachments.length === 0) throw new Error('Message is empty');
    if (opts.replyToId) {
      const parent = await prisma.chatMessage.findFirst({
        where: { id: opts.replyToId, channelId: opts.channelId },
        select: { id: true },
      });
      if (!parent) throw new Error('Original message not found');
    }

    const message = await prisma.chatMessage.create({
      data: {
        channelId: opts.channelId,
        senderId: opts.senderId,
        content,
        replyToId: opts.replyToId || null,
        attachments: attachments.length
          ? {
              create: attachments.map((a) => ({
                ...a,
                scanStatus: 'SKIPPED',
              })),
            }
          : undefined,
      },
            include: { attachments: true, reactions: true, replyTo: true },
    });
    await prisma.chatChannel.update({
      where: { id: opts.channelId },
      data: { updatedAt: new Date() },
    });
    await prisma.chatChannelMember.update({
      where: { id: member.id },
      data: { lastReadAt: new Date() },
    });
    const receipts = await receiptMembers(opts.channelId);
    const channel = await prisma.chatChannel.findUnique({
      where: { id: opts.channelId },
      select: { type: true },
    });
    const mentionedUserIds = mentionedUserIdsFromText(
      content,
      receipts,
      channel?.type === 'GROUP',
      opts.senderId,
    );
    const [serialized] = await serializeMessages([message], opts.senderId, receipts);
    return {
      ...serialized,
      mentionedUserIds,
      memberUserIds: receipts.map((m) => m.userId),
    };
  },

  async editMessage(messageId: string, me: string, content: string) {
    const msg = await prisma.chatMessage.findUnique({ where: { id: messageId } });
    if (!msg || msg.senderId !== me) throw new Error('Cannot edit this message');
    if (msg.deletedAt) throw new Error('Message was deleted');
    await assertUnseenByOthers(msg);
    const updated = await prisma.chatMessage.update({
      where: { id: messageId },
      data: { content: content.trim(), editedAt: new Date() },
            include: { attachments: true, reactions: true, replyTo: true },
    });
    const receipts = await receiptMembers(updated.channelId);
    const [serialized] = await serializeMessages([updated], me, receipts);
    return serialized;
  },

  async deleteMessage(messageId: string, me: string) {
    const msg = await prisma.chatMessage.findUnique({
      where: { id: messageId },
      include: { channel: { include: { members: true } } },
    });
    if (!msg) throw new Error('Message not found');
    const member = msg.channel.members.find((m) => m.userId === me && !m.leftAt);
    const can = msg.senderId === me || member?.role === 'owner' || member?.role === 'admin';
    if (!can) throw new Error('Cannot delete this message');
    if (msg.senderId === me) await assertUnseenByOthers(msg);
    const updated = await prisma.chatMessage.update({
      where: { id: messageId },
      data: { deletedAt: new Date(), content: null },
            include: { attachments: true, reactions: true, replyTo: true },
    });
    const receipts = await receiptMembers(updated.channelId);
    const [serialized] = await serializeMessages([updated], me, receipts);
    return serialized;
  },

  async toggleReaction(messageId: string, me: string, emoji: string) {
    const msg = await prisma.chatMessage.findUnique({ where: { id: messageId } });
    if (!msg) throw new Error('Message not found');
    const member = await prisma.chatChannelMember.findFirst({
      where: { channelId: msg.channelId, userId: me, leftAt: null },
    });
    if (!member) throw new Error('Not a member of this chat');
    const existing = await prisma.chatReaction.findUnique({
      where: { messageId_userId_emoji: { messageId, userId: me, emoji } },
    });
    if (existing) {
      await prisma.chatReaction.delete({ where: { id: existing.id } });
    } else {
      await prisma.chatReaction.create({ data: { messageId, userId: me, emoji } });
    }
    const fresh = await prisma.chatMessage.findUnique({
      where: { id: messageId },
            include: { attachments: true, reactions: true, replyTo: true },
    });
    const receipts = await receiptMembers(fresh!.channelId);
    const [serialized] = await serializeMessages([fresh!], me, receipts);
    return serialized;
  },

  async markRead(channelId: string, me: string) {
    await prisma.chatChannelMember.updateMany({
      where: { channelId, userId: me, leftAt: null },
      data: { lastReadAt: new Date() },
    });
    return { channelId, userId: me, lastReadAt: new Date().toISOString() };
  },

  async attachmentUrl(attachmentId: string, me: string) {
    const attachment = await prisma.chatAttachment.findUnique({
      where: { id: attachmentId },
      include: { message: { select: { channelId: true } } },
    });
    if (!attachment) throw new Error('File not found');
    const member = await prisma.chatChannelMember.findFirst({
      where: { channelId: attachment.message.channelId, userId: me, leftAt: null },
    });
    if (!member) throw new Error('Not a member of this chat');
    if (attachment.scanStatus === 'INFECTED') throw new Error('This file is not available');
    const url = await collabStorage.readableUrl(attachment.bucketKey, attachment.fileUrl);
    if (!url) throw new Error('File is not available');
    return { url, fileName: attachment.fileName, mimeType: attachment.mimeType };
  },

  async memberIds(channelId: string) {
    const members = await prisma.chatChannelMember.findMany({
      where: { channelId, leftAt: null },
      select: { userId: true },
    });
    return members.map((m) => m.userId);
  },

  async uploadAndAttach(file: Express.Multer.File) {
    return collabStorage.uploadBuffer({
      buffer: file.buffer,
      fileName: file.originalname || 'file',
      mimeType: file.mimetype || 'application/octet-stream',
    });
  },
};

export type { CollabProfile };
