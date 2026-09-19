/**
 * Upload splash_mr_nb.mp4 to Cloudinary and store the delivery URL in platform_branding.
 *
 * Usage (from backend/):
 *   npx tsx scripts/upload-splash-video.ts
 *
 * Loads .env before any app modules so Zod env validation succeeds.
 */
import path from 'path';
import fs from 'fs';
import { config as loadEnv } from 'dotenv';

loadEnv({ path: path.resolve(__dirname, '../.env'), override: true });

async function main() {
  const { cloudinary, configureCloudinary, getCloudinaryCredentials } = await import(
    '../src/config/cloudinary'
  );
  const { prisma } = await import('../src/config/prisma');
  const { brandingService, SPLASH_VIDEO_KEY } = await import(
    '../src/modules/platform/branding.service'
  );

  try {
    configureCloudinary();
    if (!getCloudinaryCredentials()) {
      throw new Error('Cloudinary is not configured in backend/.env');
    }

    const videoPath = path.resolve(
      __dirname,
      '../../nb_crm_flutter/assets/clips/processed/splash_mr_nb.mp4',
    );
    if (!fs.existsSync(videoPath)) {
      throw new Error(`Missing splash video at ${videoPath}`);
    }

    console.log('[upload-splash] Uploading', videoPath, `(${(fs.statSync(videoPath).size / (1024 * 1024)).toFixed(1)} MB)`);

    const result = await new Promise<Record<string, any>>((resolve, reject) => {
      cloudinary.uploader.upload_large(
        videoPath,
        {
          resource_type: 'video',
          folder: 'nb-hrms/branding',
          public_id: 'splash_mr_nb',
          overwrite: true,
          invalidate: true,
          chunk_size: 6_000_000,
        },
        (err, res) => {
          if (err) reject(err);
          else resolve((res ?? {}) as Record<string, any>);
        },
      );
    });

    console.log('[upload-splash] Cloudinary ok', {
      publicId: result.public_id,
      bytes: result.bytes,
      duration: result.duration,
      secureUrl: result.secure_url,
    });

    if (!result.secure_url) {
      throw new Error(`Cloudinary upload returned no secure_url: ${JSON.stringify(result).slice(0, 500)}`);
    }

    // Faster startup: limit width + auto quality on delivery URL.
    const deliveryUrl = String(result.secure_url).includes('/upload/')
      ? String(result.secure_url).replace(
          '/upload/',
          '/upload/w_1280,c_limit,q_auto:good,f_mp4/',
        )
      : String(result.secure_url);

    const stored = await brandingService.upsert(
      SPLASH_VIDEO_KEY,
      deliveryUrl,
      'upload-script',
      JSON.stringify({
        publicId: result.public_id,
        bytes: result.bytes,
        duration: result.duration,
        originalUrl: result.secure_url,
      }),
    );

    console.log('[upload-splash] Saved', stored.key, '→', stored.url);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  console.error('[upload-splash] Failed:', err);
  process.exitCode = 1;
});
