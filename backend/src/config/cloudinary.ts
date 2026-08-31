import { v2 as cloudinary } from 'cloudinary';
import { env } from './env';

export type CloudinaryCredentials = {
  cloud_name: string;
  api_key: string;
  api_secret: string;
};

/** Parses `cloudinary://api_key:api_secret@cloud_name` */
function parseCloudinaryUrl(raw: string): CloudinaryCredentials | null {
  const url = raw.trim().replace(/^["']|["']$/g, '');
  const m = url.match(/^cloudinary:\/\/([^:]+):([^@]+)@([^/?#]+)$/);
  if (!m) return null;
  return { api_key: m[1], api_secret: m[2], cloud_name: m[3] };
}

export function getCloudinaryCredentials(): CloudinaryCredentials | null {
  if (env.CLOUDINARY_URL) {
    const parsed = parseCloudinaryUrl(env.CLOUDINARY_URL);
    if (parsed) return parsed;
    console.warn('[Cloudinary] CLOUDINARY_URL is set but could not be parsed. Expected cloudinary://KEY:SECRET@CLOUD_NAME');
  }
  if (env.CLOUDINARY_CLOUD_NAME && env.CLOUDINARY_API_KEY && env.CLOUDINARY_API_SECRET) {
    return {
      cloud_name: env.CLOUDINARY_CLOUD_NAME,
      api_key: env.CLOUDINARY_API_KEY,
      api_secret: env.CLOUDINARY_API_SECRET,
    };
  }
  return null;
}

export function configureCloudinary() {
  const cfg = getCloudinaryCredentials();
  if (!cfg) {
    console.warn(
      '[Cloudinary] Not configured — uploads will fail until you set CLOUDINARY_URL or CLOUDINARY_CLOUD_NAME + CLOUDINARY_API_KEY + CLOUDINARY_API_SECRET in backend/.env'
    );
    return;
  }
  cloudinary.config(cfg);
  console.log('[Cloudinary] Configured (cloud:', cfg.cloud_name + ')');
}

export { cloudinary };
