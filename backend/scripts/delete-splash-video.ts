import path from 'path';
import fs from 'fs';
import { config as loadEnv } from 'dotenv';

loadEnv({ path: path.resolve(__dirname, '../.env'), override: true });

async function main() {
  const { cloudinary, configureCloudinary, getCloudinaryCredentials } = await import(
    '../src/config/cloudinary'
  );
  const { prisma } = await import('../src/config/prisma');
  const { SPLASH_VIDEO_KEY } = await import(
    '../src/modules/platform/branding.service'
  );

  try {
    configureCloudinary();
    if (getCloudinaryCredentials()) {
      console.log('[delete-splash] Deleting video from Cloudinary...');
      try {
        const res1 = await cloudinary.uploader.destroy('nb-hrms/branding/splash_mr_nb', {
          resource_type: 'video',
          invalidate: true,
        });
        console.log('[delete-splash] Cloudinary destroy result (folder):', res1);
      } catch (e: any) {
        console.warn('[delete-splash] Folder delete warning:', e.message);
      }

      try {
        const res2 = await cloudinary.uploader.destroy('splash_mr_nb', {
          resource_type: 'video',
          invalidate: true,
        });
        console.log('[delete-splash] Cloudinary destroy result (root):', res2);
      } catch (e: any) {
        console.warn('[delete-splash] Root delete warning:', e.message);
      }
    } else {
      console.warn('[delete-splash] Cloudinary credentials not found, skipping cloud delete.');
    }

    // Clean up database platform_branding
    console.log('[delete-splash] Removing splash_video key from platform_branding...');
    const deletedRow = await prisma.platformBranding.deleteMany({
      where: { key: SPLASH_VIDEO_KEY },
    });
    console.log('[delete-splash] Database rows removed:', deletedRow.count);

    // Delete local video file
    const videoPath = path.resolve(
      __dirname,
      '../../nb_crm_flutter/assets/clips/processed/splash_mr_nb.mp4',
    );
    if (fs.existsSync(videoPath)) {
      console.log('[delete-splash] Deleting local video file:', videoPath);
      fs.unlinkSync(videoPath);
      console.log('[delete-splash] Local video file successfully deleted.');
    } else {
      console.log('[delete-splash] Local video file does not exist at:', videoPath);
    }

    console.log('[delete-splash] All splash video cleanup completed successfully!');
  } catch (err) {
    console.error('[delete-splash] Error during cleanup:', err);
  } finally {
    await prisma.$disconnect();
  }
}

main();
