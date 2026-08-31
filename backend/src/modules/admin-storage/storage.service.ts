import bcrypt from 'bcryptjs';
import { prisma } from '../../config/prisma';
import { cloudinary, getCloudinaryCredentials } from '../../config/cloudinary';
import { collabStorage } from '../collaboration/storage';

const HRMS_PREFIX = 'hrms';

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

async function deleteCloudinaryPrefix(prefix: string): Promise<number> {
  if (!getCloudinaryCredentials()) return 0;
  const types: Array<'image' | 'raw' | 'video'> = ['image', 'raw', 'video'];
  let deleted = 0;
  for (const resourceType of types) {
    let nextCursor: string | undefined;
    for (let i = 0; i < 50; i += 1) {
      try {
        const result = (await cloudinary.api.delete_resources_by_prefix(prefix, {
          resource_type: resourceType,
          invalidate: true,
          ...(nextCursor ? { next_cursor: nextCursor } : {}),
        })) as {
          deleted?: Record<string, string>;
          next_cursor?: string;
          partial?: boolean;
        };
        deleted += Object.keys(result.deleted ?? {}).length;
        nextCursor = result.next_cursor;
        if (!nextCursor && !result.partial) break;
      } catch (err) {
        const http = err as { http_code?: number; error?: { http_code?: number } };
        const code = http.http_code ?? http.error?.http_code;
        if (code === 404) break;
        console.warn(`Cloudinary ${resourceType} purge skipped:`, err);
        break;
      }
    }
  }
  try {
    await cloudinary.api.delete_folder(prefix);
  } catch {
    // folder may already be gone or still have derived assets
  }
  return deleted;
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

async function clearDocumentUrls() {
  await prisma.employee.updateMany({ data: { photoUrl: null, signatureUrl: null } });
  await prisma.employeePersonalInfo.updateMany({
    data: { aadhaarCardUrl: null, panCardUrl: null, otherDocumentUrl: null },
  });
  await prisma.employeeOtherInfo.updateMany({ data: { passportUrl: null } });
  await prisma.familyMember.updateMany({ data: { aadhaarUrl: null } });
  await prisma.academicQualification.updateMany({
    data: {
      certificateUrl: null,
      sem1MarksheetUrl: null,
      sem2MarksheetUrl: null,
      sem3MarksheetUrl: null,
      sem4MarksheetUrl: null,
      sem5MarksheetUrl: null,
      sem6MarksheetUrl: null,
      sem7MarksheetUrl: null,
      sem8MarksheetUrl: null,
    },
  });
  await prisma.employeeExperience.updateMany({
    data: {
      experienceLetterUrl: null,
      lastPaycheckUrl: null,
      recommendationLetters: [],
    },
  });
  await prisma.employeeBankInfo.updateMany({
    data: { cancelledChequeUrl: null, passbookUrl: null },
  });
  await prisma.leaveApplication.updateMany({ data: { documentUrl: null } });
  await prisma.reimbursementClaim.updateMany({ data: { proofUrl: null } });
  await prisma.workTask.updateMany({
    data: { attachmentUrl: null, attachmentName: null, attachmentMime: null },
  });
  await prisma.workTaskSubtask.updateMany({
    data: { attachmentUrl: null, attachmentName: null, attachmentMime: null },
  });
  await prisma.recruitmentCandidate.updateMany({
    data: { resumeUrl: null, resumeFileName: null },
  });
  await prisma.letterTemplate.updateMany({ data: { logoUrl: null } });
  await prisma.erpProject.updateMany({ data: { imageUrl: null } });
  await prisma.chatChannel.updateMany({ data: { avatarUrl: null, topic: null } });
  await prisma.meeting.updateMany({ data: { recordingUrl: null } });
  await prisma.meetingParticipant.updateMany({ data: { photoUrl: null } });
}

async function clearTextAndDocuments() {
  await prisma.chatAttachment.deleteMany();
  await prisma.chatReaction.deleteMany();
  await prisma.chatMessage.updateMany({
    data: { content: null, deletedAt: new Date() },
  });
  await prisma.meetingChatMessage.deleteMany();
  await prisma.companyRepositoryDocument.deleteMany();
  await prisma.erpProjectDocument.deleteMany();
  await prisma.employeeLetterDocument.deleteMany();
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

    const cloudinaryDeleted = await deleteCloudinaryPrefix(HRMS_PREFIX).catch((err) => {
      console.warn('Cloudinary prefix delete failed:', err);
      return 0;
    });
    const collab = await collabStorage.purgeStoredFiles().catch((err) => {
      console.warn('Collab file purge failed:', err);
      return { objectsRemoved: 0, localFilesRemoved: 0 };
    });
    await clearDocumentUrls();
    await clearTextAndDocuments();

    console.warn(
      `[admin-storage] purged text/documents by user ${userId} (cloudinary=${cloudinaryDeleted}, minio=${collab.objectsRemoved}, local=${collab.localFilesRemoved})`,
    );

    return {
      ok: true as const,
      data: {
        cloudinaryDeleted,
        collabObjectsRemoved: collab.objectsRemoved,
        localFilesRemoved: collab.localFilesRemoved,
      },
    };
  },
};
