import { env } from '../../config/env';

const DHRUVA_URL = 'https://dhruva-api.bhashini.gov.in/services/inference/pipeline';
const ULCA_PIPELINE_URL =
  'https://meity-auth.ulcacontrib.org/ulca/apis/v0/model/getModelsPipeline';

const DEFAULT_ASR_SERVICE: Record<string, string> = {
  as: 'ai4bharat/conformer-multilingual-indo_aryan-gpu--t4',
  bn: 'ai4bharat/conformer-bn-gpu--t4',
  en: 'ai4bharat/whisper-medium-en--gpu--t4',
  gu: 'ai4bharat/conformer-gu-gpu--t4',
  hi: 'ai4bharat/conformer-hi-gpu--t4',
  kn: 'ai4bharat/conformer-kn-gpu--t4',
  ml: 'ai4bharat/conformer-ml-gpu--t4',
  mr: 'ai4bharat/conformer-mr-gpu--t4',
  or: 'ai4bharat/conformer-multilingual-indo_aryan-gpu--t4',
  pa: 'ai4bharat/conformer-pa-gpu--t4',
  ta: 'ai4bharat/conformer-ta-gpu--t4',
  te: 'ai4bharat/conformer-te-gpu--t4',
  ur: 'ai4bharat/conformer-ur-gpu--t4',
};

type PipelineCache = {
  url: string;
  authName: string;
  authValue: string;
  serviceId?: string;
  fetchedAt: number;
};

const pipelineCache = new Map<string, PipelineCache>();
const CACHE_MS = 60 * 60 * 1000;

export const BHASHINI_LANGUAGES = [
  'en',
  'hi',
  'gu',
  'mr',
  'bn',
  'ta',
  'te',
  'kn',
  'ml',
  'pa',
  'or',
  'as',
  'ur',
] as const;

export type BhashiniLang = (typeof BHASHINI_LANGUAGES)[number];

export function isBhashiniConfigured() {
  return Boolean(
    env.BHASHINI_API_KEY || (env.BHASHINI_USER_ID && env.BHASHINI_ULCA_API_KEY),
  );
}

export function normalizeTranscriptLanguage(raw?: string | null): BhashiniLang {
  const code = (raw || env.BHASHINI_DEFAULT_LANGUAGE || 'en').trim().toLowerCase();
  return (BHASHINI_LANGUAGES as readonly string[]).includes(code)
    ? (code as BhashiniLang)
    : 'en';
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' ? (value as Record<string, unknown>) : null;
}

async function resolvePipeline(language: string): Promise<PipelineCache> {
  const cached = pipelineCache.get(language);
  if (cached && Date.now() - cached.fetchedAt < CACHE_MS) return cached;

  if (env.BHASHINI_USER_ID && env.BHASHINI_ULCA_API_KEY) {
    try {
      const res = await fetch(ULCA_PIPELINE_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          userID: env.BHASHINI_USER_ID,
          ulcaApiKey: env.BHASHINI_ULCA_API_KEY,
        },
        body: JSON.stringify({
          pipelineTasks: [
            {
              taskType: 'asr',
              config: { language: { sourceLanguage: language } },
            },
          ],
          pipelineRequestConfig: {
            pipelineId: env.BHASHINI_PIPELINE_ID || '64392f96daac500b55c543cd',
          },
        }),
      });
      if (res.ok) {
        const json = (await res.json()) as Record<string, unknown>;
        const endpoint = asRecord(json.pipelineInferenceAPIEndPoint);
        const key = asRecord(endpoint?.inferenceApiKey);
        const callbackUrl = String(endpoint?.callbackUrl || '').trim();
        const authValue = String(key?.value || '').trim();
        const configs = Array.isArray(json.pipelineResponseConfig)
          ? json.pipelineResponseConfig
          : [];
        const asr = configs.find((row) => asRecord(row)?.taskType === 'asr');
        const configList = Array.isArray(asRecord(asr)?.config) ? (asRecord(asr)?.config as unknown[]) : [];
        const serviceId = String(asRecord(configList[0])?.serviceId || '').trim() || undefined;
        if (callbackUrl && authValue) {
          const next: PipelineCache = {
            url: callbackUrl,
            authName: String(key?.name || 'Authorization'),
            authValue,
            serviceId,
            fetchedAt: Date.now(),
          };
          pipelineCache.set(language, next);
          return next;
        }
      }
    } catch (err) {
      console.warn('Bhashini pipeline config failed:', err);
    }
  }

  const fallback: PipelineCache = {
    url: env.BHASHINI_ASR_URL || DHRUVA_URL,
    authName: 'Authorization',
    authValue: env.BHASHINI_API_KEY || '',
    serviceId: env.BHASHINI_ASR_SERVICE_ID || DEFAULT_ASR_SERVICE[language],
    fetchedAt: Date.now(),
  };
  pipelineCache.set(language, fallback);
  return fallback;
}

function extractAsrText(payload: unknown): string {
  const root = asRecord(payload);
  const pipeline = Array.isArray(root?.pipelineResponse) ? root?.pipelineResponse : [];
  for (const task of pipeline) {
    const row = asRecord(task);
    if (row?.taskType && row.taskType !== 'asr') continue;
    const output = Array.isArray(row?.output) ? row.output : [];
    for (const item of output) {
      const source = String(asRecord(item)?.source || '').trim();
      if (source) return source;
    }
  }
  return '';
}

export async function transcribeWithBhashini(opts: {
  audioBase64: string;
  audioFormat?: string;
  samplingRate?: number;
  language?: string;
}): Promise<string> {
  if (!isBhashiniConfigured()) {
    throw new Error('Bhashini is not configured');
  }
  const language = normalizeTranscriptLanguage(opts.language);
  const pipeline = await resolvePipeline(language);
  if (!pipeline.authValue) {
    throw new Error('Bhashini API key is missing');
  }

  const format = (opts.audioFormat || 'wav').replace(/^\./, '').toLowerCase();
  const config: Record<string, unknown> = {
    language: { sourceLanguage: language },
    audioFormat: format === 'x-wav' ? 'wav' : format,
    samplingRate: opts.samplingRate || 16000,
  };
  if (pipeline.serviceId) config.serviceId = pipeline.serviceId;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 28000);
  try {
    const res = await fetch(pipeline.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        [pipeline.authName]: pipeline.authValue,
      },
      body: JSON.stringify({
        pipelineTasks: [{ taskType: 'asr', config }],
        inputData: {
          audio: [{ audioContent: opts.audioBase64.replace(/^data:[^;]+;base64,/, '') }],
        },
      }),
      signal: controller.signal,
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) {
      const detail = String(asRecord(json)?.message || asRecord(json)?.error || res.statusText);
      throw new Error(`Bhashini ASR failed (${res.status}): ${detail}`);
    }
    return extractAsrText(json);
  } finally {
    clearTimeout(timer);
  }
}

export function formatMeetClock(at: Date) {
  return new Intl.DateTimeFormat('en-IN', {
    timeZone: 'Asia/Kolkata',
    hour: 'numeric',
    minute: '2-digit',
    second: '2-digit',
    hour12: true,
  }).format(at);
}

export function formatConversationNotes(
  rows: { speakerName: string; spokenAt: Date; text: string }[],
) {
  return rows
    .map((row) => `[${formatMeetClock(row.spokenAt)}] ${row.speakerName}: ${row.text}`)
    .join('\n');
}
