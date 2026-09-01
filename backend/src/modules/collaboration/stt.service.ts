import { env } from '../../config/env';
import { isBhashiniConfigured, transcribeWithBhashini } from './bhashini.service';

export { formatConversationNotes, formatMeetClock, normalizeTranscriptLanguage } from './bhashini.service';

export type SttSource = 'WHISPER' | 'BHASHINI';

function whisperBaseUrl() {
  const raw = (env.WHISPER_URL || '').trim().replace(/\/$/, '');
  if (raw) return raw;
  return process.env.DOCKER === 'true' ? 'http://whisper:9000' : 'http://127.0.0.1:8095';
}

export function isWhisperEnabled() {
  return env.WHISPER_ENABLED !== false;
}

export function isSttConfigured() {
  return isWhisperEnabled() || isBhashiniConfigured();
}

type WhisperProbe = { at: number; online: boolean };
let whisperProbe: WhisperProbe | null = null;
const WHISPER_PROBE_TTL_MS = 8000;

export async function probeWhisperOnline(): Promise<boolean> {
  if (!isWhisperEnabled()) return false;
  const now = Date.now();
  if (whisperProbe && now - whisperProbe.at < WHISPER_PROBE_TTL_MS) {
    return whisperProbe.online;
  }
  const base = whisperBaseUrl();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 2500);
  try {
    const res = await fetch(`${base}/health`, { signal: controller.signal });
    const online = res.ok;
    whisperProbe = { at: now, online };
    return online;
  } catch {
    whisperProbe = { at: now, online: false };
    return false;
  } finally {
    clearTimeout(timer);
  }
}

export async function getSttHealth() {
  const enabled = isSttConfigured();
  const whisperEnabled = isWhisperEnabled();
  const online = whisperEnabled ? await probeWhisperOnline() : false;
  return {
    enabled,
    online,
    whisperEnabled,
    source: whisperEnabled ? ('WHISPER' as const) : isBhashiniConfigured() ? ('BHASHINI' as const) : ('OFF' as const),
  };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' ? (value as Record<string, unknown>) : null;
}

async function transcribeWithWhisperHttp(opts: {
  audioBase64: string;
  audioFormat?: string;
  language?: string;
}): Promise<string> {
  const base = whisperBaseUrl();
  const format = (opts.audioFormat || 'wav').replace(/^\./, '').toLowerCase();
  const bytes = Buffer.from(opts.audioBase64.replace(/^data:[^;]+;base64,/, ''), 'base64');
  if (bytes.length < 80) return '';
  const form = new FormData();
  form.append(
    'file',
    new Blob([new Uint8Array(bytes)], { type: `audio/${format}` }),
    `chunk.${format}`,
  );
  if (opts.language && opts.language !== 'auto') form.append('language', opts.language);
  form.append('model', env.WHISPER_MODEL || 'base');

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 28000);
  try {
    const res = await fetch(`${base}/v1/audio/transcriptions`, {
      method: 'POST',
      body: form,
      signal: controller.signal,
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) {
      const detail = String(asRecord(json)?.detail || asRecord(json)?.error || res.statusText);
      throw new Error(`Whisper failed (${res.status}): ${detail}`);
    }
    const text = String(asRecord(json)?.text || '').replace(/\s+/g, ' ').trim();
    return text;
  } finally {
    clearTimeout(timer);
  }
}

export async function transcribeSpeech(opts: {
  audioBase64: string;
  audioFormat?: string;
  samplingRate?: number;
  language?: string;
}): Promise<{ text: string; source: SttSource }> {
  if (isWhisperEnabled()) {
    try {
      const text = await transcribeWithWhisperHttp(opts);
      if (text) return { text, source: 'WHISPER' };
    } catch (err) {
      console.warn('Self-hosted Whisper STT failed:', err);
    }
  }
  if (isBhashiniConfigured()) {
    const text = (await transcribeWithBhashini(opts)).replace(/\s+/g, ' ').trim();
    return { text, source: 'BHASHINI' };
  }
  return { text: '', source: 'WHISPER' };
}
