import bcrypt from 'bcryptjs';
import fs from 'fs/promises';
import path from 'path';
import { prisma } from '../../config/prisma';
import { cloudinary, getCloudinaryCredentials } from '../../config/cloudinary';
import { collabStorage } from '../collaboration/storage';
import { parseCloudinaryDeliveryUrl } from '../personal-education/upload.service';

const LOCAL_COLLAB_DIR = path.join(process.cwd(), 'uploads', 'collab');

type CloudinaryUsage = {
  configured: boolean;
  usedBytes: number;
  limitBytes: number;
  plan: string | null;
};

async function cloudinaryUsage(): Promise<CloudinaryUsage> {
  if (!getCloudinaryCredentials()) {
    return { configured: false, usedBytes: 0, limitBytes: 0, plan: null };
  }
  try {
    const usage = (await cloudinary.api.usage()) as {
      plan?: string;
      storage?: { usage?: number; limit?: number };
    };
    return {
      configured: true,
      usedBytes: Number(usage.storage?.usage) || 0,
      limitBytes: Number(usage.storage?.limit) || 0,
      plan: usage.plan ?? null,
    };
  } catch (err) {
    console.warn('Cloudinary usage lookup failed:', err);
    return { configured: true, usedBytes: 0, limitBytes: 0, plan: null };
  }
}

async function destroyCloudinaryUrl(rawUrl: string): Promise<boolean> {
  if (!getCloudinaryCredentials() || !/cloudinary\.com/i.test(rawUrl)) return false;
  const parsed = parseCloudinaryDeliveryUrl(rawUrl);
  if (!parsed) return false;
  const types: Array<'image' | 'raw' | 'video'> = [
    ...(parsed.resourceType === 'image' || parsed.resourceType === 'raw' || parsed.resourceType === 'video'
      ? [parsed.resourceType]
      : []),
    'image',
    'raw',
    'video',
  ].filter((v, i, a) => a.indexOf(v) === i) as Array<'image' | 'raw' | 'video'>;
  for (const resourceType of types) {
    try {
      const result = (await cloudinary.uploader.destroy(parsed.publicId, {
        resource_type: resourceType,
        invalidate: true,
      })) as { result?: string };
      if (result?.result === 'ok' || result?.result === 'not found') return true;
    } catch {
      // try next resource type
    }
  }
  return false;
}

async function deleteChatAttachmentMedia() {
  const rows = await prisma.chatAttachment.findMany({
    select: { bucketKey: true, fileUrl: true },
  });
  let cloudinaryDeleted = 0;
  let localFilesRemoved = 0;
  let collabObjectsRemoved = 0;
  for (const row of rows) {
    const candidates = [row.bucketKey, row.fileUrl].filter((v): v is string => Boolean(v && v.trim()));
    for (const candidate of candidates) {
      if (/cloudinary\.com/i.test(candidate)) {
        if (await destroyCloudinaryUrl(candidate)) cloudinaryDeleted += 1;
        continue;
      }
      if (candidate.startsWith('meetings/') || /^https?:\/\//i.test(candidate)) continue;
      await collabStorage.removeObject(candidate);
      collabObjectsRemoved += 1;
      const localName = candidate.replace(/^collab\//, '');
      try {
        await fs.unlink(path.join(LOCAL_COLLAB_DIR, localName));
        localFilesRemoved += 1;
      } catch {
        // not stored locally
      }
    }
  }
  return { cloudinaryDeleted, localFilesRemoved, collabObjectsRemoved };
}

async function dbCounts() {
  const [
    chatAttachments,
    chatAttachmentBytes,
    repositoryDocs,
    repositoryBytes,
    erpDocs,
    erpBytes,
    chatMessages,
    meetingChats,
  ] = await Promise.all([
    prisma.chatAttachment.count(),
    prisma.chatAttachment.aggregate({ _sum: { sizeBytes: true } }),
    prisma.companyRepositoryDocument.count(),
    prisma.companyRepositoryDocument.aggregate({ _sum: { fileSize: true } }),
    prisma.erpProjectDocument.count(),
    prisma.erpProjectDocument.aggregate({ _sum: { fileSize: true } }),
    prisma.chatMessage.count({ where: { deletedAt: null, content: { not: null } } }),
    prisma.meetingChatMessage.count(),
  ]);
  return {
    chatAttachments,
    chatAttachmentBytes: chatAttachmentBytes._sum.sizeBytes ?? 0,
    repositoryDocs,
    repositoryBytes: repositoryBytes._sum.fileSize ?? 0,
    erpDocs,
    erpBytes: erpBytes._sum.fileSize ?? 0,
    chatMessages,
    meetingChats,
  };
}

async function clearChatOnly() {
  await prisma.chatAttachment.deleteMany();
  await prisma.chatReaction.deleteMany();
  await prisma.chatMessage.updateMany({
    data: { content: null, deletedAt: new Date() },
  });
  await prisma.meetingChatMessage.deleteMany();
}

export const storageService = {
  async usage() {
    const [media, collab, counts] = await Promise.all([
      cloudinaryUsage(),
      collabStorage.summarize('').catch(() => ({ objectCount: 0, bytes: 0, keys: [] as string[] })),
      dbCounts(),
    ]);
    const usedBytes = media.configured ? media.usedBytes : media.usedBytes + collab.bytes;
    const limitBytes = media.limitBytes;
    const remainingBytes = limitBytes > 0 ? Math.max(0, limitBytes - usedBytes) : 0;
    return {
      usedBytes,
      limitBytes,
      remainingBytes,
      remainingRatio: limitBytes > 0 ? remainingBytes / limitBytes : 1,
      usedRatio: limitBytes > 0 ? Math.min(1, usedBytes / limitBytes) : 0,
      cloudinary: media,
      collab: {
        objectCount: collab.objectCount,
        bytes: collab.bytes,
      },
      counts,
    };
  },

  async purgeTextAndDocuments(userId: string, password: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, passwordHash: true },
    });
    if (!user) return { ok: false as const, error: 'Account not found', status: 404 };
    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) return { ok: false as const, error: 'Incorrect password', status: 403 };

    const media = await deleteChatAttachmentMedia().catch((err) => {
      console.warn('Chat attachment media delete failed:', err);
      return { cloudinaryDeleted: 0, localFilesRemoved: 0, collabObjectsRemoved: 0 };
    });
    await clearChatOnly();

    console.warn(
      `[admin-storage] purged chat by user ${userId} (cloudinary=${media.cloudinaryDeleted}, minio=${media.collabObjectsRemoved}, local=${media.localFilesRemoved})`,
    );

    return {
      ok: true as const,
      data: {
        cloudinaryDeleted: media.cloudinaryDeleted,
        collabObjectsRemoved: media.collabObjectsRemoved,
        localFilesRemoved: media.localFilesRemoved,
      },
    };
  },
};
