import fs from 'fs/promises';
import path from 'path';
import { randomUUID } from 'crypto';
import { Client as MinioClient } from 'minio';
import { env } from '../../config/env';
import { uploadService } from '../personal-education/upload.service';
import { allowedCorsOriginList } from '../../utils/corsOrigins';

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

function isHttpUrl(value: string) {
  return /^https?:\/\//i.test(value);
}

function isCloudinaryUrl(value: string) {
  return /cloudinary\.com/i.test(value);
}

function isMinioLikeUrl(value: string) {
  try {
    const u = new URL(value);
    const host = u.hostname.toLowerCase();
    return (
      u.port === '9000' ||
      u.pathname.includes('/crm-files/') ||
      host === 'minio' ||
      host.includes('minio')
    );
  } catch {
    return false;
  }
}

function localObjectName(objectKey: string) {
  return objectKey.replace(/^collab\//, '');
}

async function readLocalFile(objectKey: string): Promise<Buffer | null> {
  if (!objectKey || isHttpUrl(objectKey)) return null;
  const names = [objectKey, localObjectName(objectKey)];
  for (const name of names) {
    try {
      return await fs.readFile(path.join(localDir, name));
    } catch {
      // try next candidate
    }
  }
  return null;
}

async function minioObjectBuffer(objectKey: string): Promise<Buffer | null> {
  if (!minioConfigured() || !objectKey || isHttpUrl(objectKey) || isCloudinaryUrl(objectKey)) {
    return null;
  }
  try {
    const stream = await getMinio().getObject(env.MINIO_BUCKET, objectKey);
    const chunks: Buffer[] = [];
    for await (const chunk of stream) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    const buffer = Buffer.concat(chunks);
    return buffer.length ? buffer : null;
  } catch {
    return null;
  }
}

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
    } catch (err) {
      console.warn('Cloudinary collab upload failed, saving locally:', err);
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
    const candidates = [objectKey, fallback].filter((v): v is string => Boolean(v && v.trim()));
    for (const candidate of candidates) {
      if (isCloudinaryUrl(candidate)) return candidate;
      if (isHttpUrl(candidate) && !isMinioLikeUrl(candidate)) return candidate;
      if (candidate.startsWith('/uploads/')) return candidate;
    }
    const key = objectKey || '';
    if (key && !isHttpUrl(key)) {
      const localName = localObjectName(key);
      try {
        await fs.access(path.join(localDir, localName));
        return `/uploads/collab/${localName}`;
      } catch {
        // not on disk — client should use the authenticated file proxy
      }
    }
    return '';
  },

  /** Server-side bytes for chat view/download. Never hands MinIO URLs to clients. */
  async fetchBytes(
    objectKey: string,
    fallback?: string | null,
    mimeType?: string | null,
  ): Promise<{ buffer: Buffer; contentType: string | null }> {
    const candidates = [objectKey, fallback].filter((v): v is string => Boolean(v && v.trim()));
    for (const candidate of candidates) {
      if (isCloudinaryUrl(candidate)) {
        try {
          return await uploadService.fetchDocumentBytes(candidate);
        } catch (err) {
          console.warn('Cloudinary collab fetch failed, trying direct URL:', err);
          try {
            const upstream = await fetch(candidate);
            if (upstream.ok) {
              const buffer = Buffer.from(await upstream.arrayBuffer());
              if (buffer.length) {
                return {
                  buffer,
                  contentType: upstream.headers.get('content-type') || mimeType || null,
                };
              }
            }
          } catch {
            // try next candidate
          }
        }
        continue;
      }
      if (isHttpUrl(candidate) && !isMinioLikeUrl(candidate)) {
        try {
          const upstream = await fetch(candidate);
          if (upstream.ok) {
            const buffer = Buffer.from(await upstream.arrayBuffer());
            if (buffer.length) {
              return {
                buffer,
                contentType: upstream.headers.get('content-type') || mimeType || null,
              };
            }
          }
        } catch {
          // try next candidate
        }
      }
    }

    const key = objectKey || candidates.find((c) => c && !isHttpUrl(c)) || '';
    const local = await readLocalFile(key);
    if (local?.length) return { buffer: local, contentType: mimeType || null };

    const fromMinio = await minioObjectBuffer(key);
    if (fromMinio?.length) return { buffer: fromMinio, contentType: mimeType || null };

    throw Object.assign(new Error('File is not available'), { status: 404 });
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

  async summarize(prefix = ''): Promise<{ objectCount: number; bytes: number; keys: string[] }> {
    if (minioConfigured()) {
      const minio = getMinio();
      const keys: string[] = [];
      let bytes = 0;
      await new Promise<void>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('MinIO list timed out')), 30_000);
        const stream = minio.listObjects(env.MINIO_BUCKET, prefix, true);
        stream.on('data', (obj) => {
          if (obj.name) {
            keys.push(obj.name);
            bytes += Number(obj.size) || 0;
          }
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
      return { objectCount: keys.length, bytes, keys };
    }

    try {
      const names = await fs.readdir(localDir);
      let bytes = 0;
      const keys: string[] = [];
      for (const name of names) {
        const full = path.join(localDir, name);
        try {
          const st = await fs.stat(full);
          bytes += st.size;
          keys.push(name);
        } catch {
          // skip unreadable entries
        }
      }
      return { objectCount: keys.length, bytes, keys };
    } catch {
      return { objectCount: 0, bytes: 0, keys: [] };
    }
  },

  async purgeStoredFiles(): Promise<{ objectsRemoved: number; localFilesRemoved: number }> {
    let objectsRemoved = 0;
    let localFilesRemoved = 0;
    try {
      const { keys } = await this.summarize('');
      if (minioConfigured()) {
        for (const key of keys) {
          await this.removeObject(key);
          objectsRemoved += 1;
        }
      } else {
        for (const name of keys) {
          await fs.rm(path.join(localDir, name), { force: true, recursive: true });
          localFilesRemoved += 1;
        }
        return { objectsRemoved, localFilesRemoved };
      }
    } catch (err) {
      console.warn('Collab object purge skipped:', err);
    }
    try {
      const names = await fs.readdir(localDir);
      for (const name of names) {
        await fs.rm(path.join(localDir, name), { force: true, recursive: true });
        localFilesRemoved += 1;
      }
    } catch {
      // local dir may not exist
    }
    return { objectsRemoved, localFilesRemoved };
  },

  async allowPublicGetCors() {
    if (!minioConfigured()) return;
    try {
      const minio = await ensureBucket();
      const client = minio as unknown as {
        setBucketCors?: (bucket: string, cfg: unknown) => Promise<void>;
      };
      if (typeof client.setBucketCors !== 'function') return;
      await client.setBucketCors(env.MINIO_BUCKET, {
        corsRules: [
          {
            allowedOrigin: allowedCorsOriginList(),
            allowedMethod: ['GET', 'HEAD'],
            allowedHeader: ['*'],
            exposeHeader: ['ETag', 'Content-Type', 'Content-Length'],
            maxAgeSeconds: 3600,
          },
        ],
      });
    } catch (err) {
      console.warn('MinIO CORS update skipped:', err);
    }
  },
};
