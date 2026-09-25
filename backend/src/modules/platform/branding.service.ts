import { prisma } from '../../config/prisma';

export const SPLASH_VIDEO_KEY = 'splash_video';
export const APP_MIN_VERSION_KEY = 'app_min_version';
export const APP_MAX_VERSION_KEY = 'app_max_version';
export const APP_UPDATE_URL_WEB_KEY = 'app_update_url_web';
export const APP_UPDATE_URL_ANDROID_KEY = 'app_update_url_android';
export const APP_UPDATE_URL_IOS_KEY = 'app_update_url_ios';

const VERSION_RE = /^\d+(\.\d+){0,3}(\+\d+)?$/;

export function compareAppVersions(a: string, b: string): number {
  const parse = (raw: string) => {
    const [core, build] = raw.trim().split('+');
    const parts = core.split('.').map((n) => Number.parseInt(n, 10) || 0);
    return { parts, build: build == null || build === '' ? null : Number.parseInt(build, 10) || 0 };
  };
  const left = parse(a);
  const right = parse(b);
  const len = Math.max(left.parts.length, right.parts.length);
  for (let i = 0; i < len; i++) {
    const d = (left.parts[i] ?? 0) - (right.parts[i] ?? 0);
    if (d !== 0) return d;
  }
  if (left.build != null && right.build != null && left.build !== right.build) {
    return left.build - right.build;
  }
  return 0;
}

function cleanVersion(value: unknown, label: string): string {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!text) return '';
  if (!VERSION_RE.test(text)) {
    throw new Error(`${label} must look like 1.2.3 or 1.2.3+4`);
  }
  return text;
}

function cleanUrl(value: unknown, label: string): string {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!text) return '';
  if (!/^https?:\/\//i.test(text)) {
    throw new Error(`${label} must start with http:// or https://`);
  }
  return text;
}

export const brandingService = {
  async getPublicBranding() {
    const rows = await prisma.platformBranding.findMany({
      where: {
        key: {
          in: [
            SPLASH_VIDEO_KEY,
            APP_MIN_VERSION_KEY,
            APP_MAX_VERSION_KEY,
            APP_UPDATE_URL_WEB_KEY,
            APP_UPDATE_URL_ANDROID_KEY,
            APP_UPDATE_URL_IOS_KEY,
          ],
        },
      },
      select: { key: true, url: true, meta: true },
    });
    const map = Object.fromEntries(rows.map((r) => [r.key, r.url]));
    return {
      splashVideoUrl: map[SPLASH_VIDEO_KEY] ?? null,
      minVersion: map[APP_MIN_VERSION_KEY] ?? '',
      maxVersion: map[APP_MAX_VERSION_KEY] ?? '',
      updateUrlWeb: map[APP_UPDATE_URL_WEB_KEY] ?? '',
      updateUrlAndroid: map[APP_UPDATE_URL_ANDROID_KEY] ?? '',
      updateUrlIos: map[APP_UPDATE_URL_IOS_KEY] ?? '',
    };
  },

  async getAppVersionPolicy() {
    const branding = await this.getPublicBranding();
    return {
      minVersion: branding.minVersion,
      maxVersion: branding.maxVersion,
      updateUrlWeb: branding.updateUrlWeb,
      updateUrlAndroid: branding.updateUrlAndroid,
      updateUrlIos: branding.updateUrlIos,
    };
  },

  async setAppVersionPolicy(input: {
    minVersion?: unknown;
    maxVersion?: unknown;
    updateUrlWeb?: unknown;
    updateUrlAndroid?: unknown;
    updateUrlIos?: unknown;
    updatedBy?: string | null;
  }) {
    const minVersion = cleanVersion(input.minVersion, 'Minimum version');
    const maxVersion = cleanVersion(input.maxVersion, 'Latest version');
    const updateUrlWeb = cleanUrl(input.updateUrlWeb, 'Web update link');
    const updateUrlAndroid = cleanUrl(input.updateUrlAndroid, 'Android update link');
    const updateUrlIos = cleanUrl(input.updateUrlIos, 'iOS update link');
    if (minVersion && maxVersion && compareAppVersions(minVersion, maxVersion) > 0) {
      throw new Error('Minimum version cannot be higher than the latest version');
    }
    const updatedBy = input.updatedBy ?? null;
    await Promise.all([
      this.upsert(APP_MIN_VERSION_KEY, minVersion, updatedBy),
      this.upsert(APP_MAX_VERSION_KEY, maxVersion, updatedBy),
      this.upsert(APP_UPDATE_URL_WEB_KEY, updateUrlWeb, updatedBy),
      this.upsert(APP_UPDATE_URL_ANDROID_KEY, updateUrlAndroid, updatedBy),
      this.upsert(APP_UPDATE_URL_IOS_KEY, updateUrlIos, updatedBy),
    ]);
    return { minVersion, maxVersion, updateUrlWeb, updateUrlAndroid, updateUrlIos };
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
