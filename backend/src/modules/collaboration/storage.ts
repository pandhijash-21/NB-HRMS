import fs from 'fs/promises';
import path from 'path';
import { randomUUID } from 'crypto';
import { Client as MinioClient } from 'minio';
import { env } from '../../config/env';
import { uploadService } from '../personal-education/upload.service';

export type StoredFile = {
  bucketKey: string;
  fileUrl: string;
  fileName: string;
  mimeType: string;
  sizeBytes: number;
};

function minioConfigured() {
  return Boolean(env.MINIO_ENDPOINT && env.MINIO_ACCESS_KEY && env.MINIO_SECRET_KEY);
}

function getMinio() {
  return new MinioClient({
    endPoint: env.MINIO_ENDPOINT!,
    port: env.MINIO_PORT,
    useSSL: env.MINIO_USE_SSL,
    accessKey: env.MINIO_ACCESS_KEY!,
    secretKey: env.MINIO_SECRET_KEY!,
  });
}

async function ensureBucket() {
  const minio = getMinio();
      const exists = await minio.bucketExists(env.MINIO_BUCKET);
  if (!exists) {
    await minio.makeBucket(env.MINIO_BUCKET, 'us-east-1');
  }
  return minio;
}

function publicMinioUrl(objectKey: string) {
  const base =
    env.MINIO_PUBLIC_URL ||
    `${env.MINIO_USE_SSL ? 'https' : 'http'}://${env.MINIO_ENDPOINT}:${env.MINIO_PORT}`;
  return `${base.replace(/\/$/, '')}/${env.MINIO_BUCKET}/${objectKey}`;
}

/** Presigned URLs must be reachable from the browser, not Docker-internal `minio`. */
function rewritePublicMinioUrl(url: string) {
  if (!env.MINIO_PUBLIC_URL) return url;
  try {
    const signed = new URL(url);
    const pub = new URL(env.MINIO_PUBLIC_URL);
    signed.protocol = pub.protocol;
    signed.host = pub.host;
    return signed.toString();
  } catch {
    return url;
  }
}

const localDir = path.join(process.cwd(), 'uploads', 'collab');

async function saveLocal(buffer: Buffer, fileName: string, mimeType: string): Promise<StoredFile> {
  await fs.mkdir(localDir, { recursive: true });
  const safe = fileName.replace(/[^\w.\-]+/g, '_');
  const bucketKey = `${Date.now()}-${randomUUID()}-${safe}`;
  await fs.writeFile(path.join(localDir, bucketKey), buffer);
  return {
    bucketKey,
    fileUrl: `/uploads/collab/${bucketKey}`,
    fileName,
    mimeType,
    sizeBytes: buffer.length,
  };
}

export const collabStorage = {
  isMinioConfigured: minioConfigured,

  async uploadBuffer(opts: {
    buffer: Buffer;
    fileName: string;
    mimeType: string;
  }): Promise<StoredFile> {
    const { buffer, fileName, mimeType } = opts;
    if (minioConfigured()) {
      const minio = await ensureBucket();
      const safe = fileName.replace(/[^\w.\-]+/g, '_');
      const objectKey = `collab/${Date.now()}-${randomUUID()}-${safe}`;
      await minio.putObject(env.MINIO_BUCKET, objectKey, buffer, buffer.length, {
        'Content-Type': mimeType,
      });
      const fileUrl = await minio.presignedGetObject(env.MINIO_BUCKET, objectKey, 60 * 60 * 24 * 7);
      return {
        bucketKey: objectKey,
        fileUrl,
        fileName,
        mimeType,
        sizeBytes: buffer.length,
      };
    }

    try {
      const fake = {
        buffer,
        originalname: fileName,
        mimetype: mimeType,
      } as Express.Multer.File;
      const url = await uploadService.uploadToCloudinary(fake, 'collab');
      return {
        bucketKey: url,
        fileUrl: url,
        fileName,
        mimeType,
        sizeBytes: buffer.length,
      };
    } catch {
      return saveLocal(buffer, fileName, mimeType);
    }
  },

  async presignPut(fileName: string, mimeType: string) {
    if (!minioConfigured()) {
      throw new Error('MinIO is not configured; use multipart upload instead');
    }
    const minio = await ensureBucket();
    const safe = fileName.replace(/[^\w.\-]+/g, '_');
    const objectKey = `collab/${Date.now()}-${randomUUID()}-${safe}`;
    const uploadUrl = await minio.presignedPutObject(env.MINIO_BUCKET, objectKey, 300);
    return { uploadUrl, objectKey, mimeType };
  },

  async presignGet(objectKey: string) {
    if (!minioConfigured()) return objectKey;
    const minio = getMinio();
    const signed = await minio.presignedGetObject(env.MINIO_BUCKET, objectKey, 60 * 60 * 12);
    return rewritePublicMinioUrl(signed);
  },

  async readableUrl(objectKey: string, fallback?: string | null) {
    if (!objectKey && fallback) return fallback;
    if (objectKey.startsWith('http://') || objectKey.startsWith('https://')) return objectKey;
    if (!minioConfigured()) {
      if (fallback?.startsWith('http') || fallback?.startsWith('/')) return fallback;
      return `/uploads/collab/${objectKey.replace(/^collab\//, '')}`;
    }
    try {
      return await this.presignGet(objectKey);
    } catch {
      return fallback || objectKey;
    }
  },

  async objectExists(objectKey: string) {
    return (await this.objectStat(objectKey)) != null;
  },

  async objectStat(objectKey: string) {
    if (!minioConfigured()) return null;
    try {
      const stat = await getMinio().statObject(env.MINIO_BUCKET, objectKey);
      return { size: Number(stat.size) || 0 };
    } catch {
      return null;
    }
  },

  async removeObject(objectKey: string) {
    if (!minioConfigured() || !objectKey) return;
    try {
      await getMinio().removeObject(env.MINIO_BUCKET, objectKey);
    } catch (err) {
      console.warn('MinIO recording delete skipped:', err);
    }
  },

  async downloadToFile(objectKey: string, destPath: string) {
    if (!minioConfigured()) throw new Error('MinIO is not configured');
    await getMinio().fGetObject(env.MINIO_BUCKET, objectKey, destPath);
  },

  async listObjectKeys(prefix: string) {
    if (!minioConfigured()) return [] as string[];
    const minio = getMinio();
    const keys: string[] = [];
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('MinIO list timed out')), 4000);
      const stream = minio.listObjects(env.MINIO_BUCKET, prefix, true);
      stream.on('data', (obj) => {
        if (obj.name) keys.push(obj.name);
      });
      stream.on('error', (err) => {
        clearTimeout(timer);
        reject(err);
      });
      stream.on('end', () => {
        clearTimeout(timer);
        resolve();
      });
    });
    return keys;
  },

  async allowPublicGetCors() {
    if (!minioConfigured()) return;
    try {
      const minio = await ensureBucket();
      await minio.setBucketCors(env.MINIO_BUCKET, {
        corsRules: [
          {
            allowedOrigin: ['*'],
            allowedMethod: ['GET', 'HEAD'],
            allowedHeader: ['*'],
            exposeHeader: ['ETag', 'Content-Type', 'Content-Length'],
            maxAgeSeconds: 3600,
          },
        ],
      } as never);
    } catch (err) {
      console.warn('MinIO CORS update skipped:', err);
    }
  },
};
