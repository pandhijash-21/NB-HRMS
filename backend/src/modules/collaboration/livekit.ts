import {
  AccessToken,
  EgressClient,
  EncodedFileOutput,
  EncodedFileType,
  EncodingOptionsPreset,
  RoomServiceClient,
  S3Upload,
} from 'livekit-server-sdk';
import { env } from '../../config/env';

export function livekitPublicUrl() {
  if (env.LIVEKIT_PUBLIC_URL) return env.LIVEKIT_PUBLIC_URL;
  return env.LIVEKIT_URL.replace(/^http/, 'ws');
}

function roomService() {
  return new RoomServiceClient(env.LIVEKIT_URL.replace(/\/$/, ''), env.LIVEKIT_API_KEY, env.LIVEKIT_API_SECRET);
}

/** Drop a leftover LiveKit session so refresh + rejoin is not blocked by the same identity. */
export async function removeLiveKitParticipant(roomName: string, identity: string) {
  try {
    await roomService().removeParticipant(roomName, identity);
  } catch {
    // Room or participant may not exist yet.
  }
}

export async function issueLiveKitToken(opts: {
  roomName: string;
  identity: string;
  name: string;
  metadata?: Record<string, unknown>;
}) {
  const token = new AccessToken(env.LIVEKIT_API_KEY, env.LIVEKIT_API_SECRET, {
    identity: opts.identity,
    name: opts.name,
    metadata: opts.metadata ? JSON.stringify(opts.metadata) : undefined,
    ttl: '6h',
  });
  token.addGrant({
    roomJoin: true,
    room: opts.roomName,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  });
  return token.toJwt();
}

export async function deleteLiveKitRoom(roomName: string) {
  try {
    await roomService().deleteRoom(roomName);
  } catch {
    // Room may already be empty or never created.
  }
}

function egressClient() {
  return new EgressClient(
    env.LIVEKIT_URL.replace(/\/$/, ''),
    env.LIVEKIT_API_KEY,
    env.LIVEKIT_API_SECRET,
  );
}

function minioEgressEndpoint() {
  const minioHost = env.MINIO_ENDPOINT || '127.0.0.1';
  return (
    env.MINIO_EGRESS_ENDPOINT ||
    (minioHost === '127.0.0.1' || minioHost === 'localhost'
      ? `http://minio:${env.MINIO_PORT}`
      : `${env.MINIO_USE_SSL ? 'https' : 'http'}://${minioHost}:${env.MINIO_PORT}`)
  ).replace(/\/$/, '');
}

export async function startRoomRecording(roomName: string, filePrefix: string) {
  if (!env.MINIO_ENDPOINT || !env.MINIO_ACCESS_KEY || !env.MINIO_SECRET_KEY) {
    throw new Error('Recording requires MinIO (S3) to be configured');
  }
  const filepath = `meetings/${filePrefix}.mp4`;
  const output = new EncodedFileOutput({
    fileType: EncodedFileType.MP4,
    filepath,
    output: {
      case: 's3',
      value: new S3Upload({
        accessKey: env.MINIO_ACCESS_KEY,
        secret: env.MINIO_SECRET_KEY,
        region: 'us-east-1',
        endpoint: minioEgressEndpoint(),
        bucket: env.MINIO_BUCKET,
        forcePathStyle: true,
      }),
    },
  });
  const info = await egressClient().startRoomCompositeEgress(roomName, output, {
    layout: 'grid',
    encodingOptions: EncodingOptionsPreset.H264_720P_30,
  });
  if (info.error) {
    throw new Error(info.error);
  }
  if (!info.egressId) {
    throw new Error('LiveKit did not return a recording id');
  }
  return { egressId: info.egressId, filepath };
}

export async function stopRoomRecording(egressId: string) {
  await Promise.race([
    egressClient().stopEgress(egressId),
    new Promise<never>((_, reject) => {
      setTimeout(
        () => reject(new Error('Stop recording timed out. The file may still appear in Past meetings shortly.')),
        45000,
      );
    }),
  ]);
}
