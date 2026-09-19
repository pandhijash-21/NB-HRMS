import { prisma } from '../../config/prisma';

export const SPLASH_VIDEO_KEY = 'splash_video';

export const brandingService = {
  async getPublicBranding() {
    const rows = await prisma.platformBranding.findMany({
      where: { key: { in: [SPLASH_VIDEO_KEY] } },
      select: { key: true, url: true, meta: true },
    });
    const map = Object.fromEntries(rows.map((r) => [r.key, r.url]));
    return {
      splashVideoUrl: map[SPLASH_VIDEO_KEY] ?? null,
    };
  },

  async get(key: string) {
    return prisma.platformBranding.findUnique({ where: { key } });
  },

  async upsert(key: string, url: string, updatedBy?: string | null, meta?: string | null) {
    return prisma.platformBranding.upsert({
      where: { key },
      create: { key, url, updatedBy: updatedBy ?? null, meta: meta ?? null },
      update: { url, updatedBy: updatedBy ?? null, meta: meta ?? null },
    });
  },
};
