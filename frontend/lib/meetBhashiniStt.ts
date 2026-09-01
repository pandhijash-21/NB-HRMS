import type { Room } from "livekit-client";
import { Track } from "livekit-client";
import api from "@/lib/axios";

export const MEET_STT_LANGUAGES = [
  { code: "en", label: "English" },
  { code: "hi", label: "Hindi" },
  { code: "gu", label: "Gujarati" },
  { code: "mr", label: "Marathi" },
  { code: "bn", label: "Bengali" },
  { code: "ta", label: "Tamil" },
  { code: "te", label: "Telugu" },
  { code: "kn", label: "Kannada" },
  { code: "ml", label: "Malayalam" },
  { code: "pa", label: "Punjabi" },
  { code: "or", label: "Odia" },
  { code: "as", label: "Assamese" },
  { code: "ur", label: "Urdu" },
] as const;

function downsample(input: Float32Array, fromRate: number, toRate: number) {
  if (fromRate === toRate) return input;
  const ratio = fromRate / toRate;
  const out = new Float32Array(Math.max(1, Math.floor(input.length / ratio)));
  for (let i = 0; i < out.length; i += 1) {
    out[i] = input[Math.min(input.length - 1, Math.floor(i * ratio))] ?? 0;
  }
  return out;
}

function encodeWav(samples: Float32Array, sampleRate: number) {
  const bytes = new ArrayBuffer(44 + samples.length * 2);
  const view = new DataView(bytes);
  const write = (offset: number, text: string) => {
    for (let i = 0; i < text.length; i += 1) view.setUint8(offset + i, text.charCodeAt(i));
  };
  write(0, "RIFF");
  view.setUint32(4, 36 + samples.length * 2, true);
  write(8, "WAVE");
  write(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  write(36, "data");
  view.setUint32(40, samples.length * 2, true);
  let offset = 44;
  for (let i = 0; i < samples.length; i += 1, offset += 2) {
    const s = Math.max(-1, Math.min(1, samples[i] ?? 0));
    view.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7fff, true);
  }
  return new Blob([bytes], { type: "audio/wav" });
}

function rms(samples: Float32Array) {
  if (samples.length === 0) return 0;
  let sum = 0;
  for (let i = 0; i < samples.length; i += 1) sum += samples[i] * samples[i];
  return Math.sqrt(sum / samples.length);
}

export class MeetBhashiniStt {
  private ctx: AudioContext | null = null;
  private source: MediaStreamAudioSourceNode | null = null;
  private processor: ScriptProcessorNode | null = null;
  private mute: GainNode | null = null;
  private pending: Float32Array[] = [];
  private pendingSamples = 0;
  private chunkStartedAt: Date | null = null;
  private sending = false;
  private stopped = true;
  private micOn = true;
  private language = "en";
  private meetingId = "";
  private token?: string;
  private nativeRate = 48000;
  private room: Room | null = null;
  private boundTrackId: string | null = null;
  private retryTimer: number | null = null;

  start(opts: { room: Room; meetingId: string; language?: string; token?: string }) {
    this.teardownGraph();
    this.stopped = false;
    this.meetingId = opts.meetingId;
    this.language = opts.language || "en";
    this.token = opts.token;
    this.micOn = true;
    this.room = opts.room;
    this.attach(opts.room);
  }

  attach(room: Room) {
    this.room = room;
    if (this.stopped || !this.micOn) return;
    const pub = room.localParticipant.getTrackPublication(Track.Source.Microphone);
    const media = pub?.track?.mediaStreamTrack;
    if (!media || media.readyState === "ended" || pub.isMuted) {
      this.scheduleRetry();
      return;
    }
    if (this.boundTrackId === media.id && this.processor) return;
    this.bindGraph(media);
  }

  setLanguage(language: string) {
    this.language = language;
  }

  setMicEnabled(on: boolean) {
    this.micOn = on;
    if (!on) {
      void this.flush();
      return;
    }
    if (this.room) this.attach(this.room);
  }

  async stop() {
    this.stopped = true;
    if (this.retryTimer != null) {
      window.clearTimeout(this.retryTimer);
      this.retryTimer = null;
    }
    await this.flush();
    this.teardownGraph();
    this.pending = [];
    this.pendingSamples = 0;
    this.room = null;
  }

  private scheduleRetry() {
    if (this.stopped || this.retryTimer != null) return;
    this.retryTimer = window.setTimeout(() => {
      this.retryTimer = null;
      if (this.room && !this.stopped) this.attach(this.room);
    }, 700);
  }

  private bindGraph(media: MediaStreamTrack) {
    this.teardownGraph();
    const AudioCtx =
      window.AudioContext ||
      (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    this.ctx = ctx;
    this.nativeRate = ctx.sampleRate || 48000;
    const source = ctx.createMediaStreamSource(new MediaStream([media]));
    const processor = ctx.createScriptProcessor(4096, 1, 1);
    processor.onaudioprocess = (event) => {
      if (this.stopped || !this.micOn) return;
      const input = event.inputBuffer.getChannelData(0);
      const copy = new Float32Array(input.length);
      copy.set(input);
      this.pending.push(copy);
      this.pendingSamples += copy.length;
      this.chunkStartedAt ??= new Date();
      const seconds = this.pendingSamples / this.nativeRate;
      if (seconds >= 3.2) void this.flush();
    };
    const mute = ctx.createGain();
    mute.gain.value = 0;
    source.connect(processor);
    processor.connect(mute);
    mute.connect(ctx.destination);
    this.source = source;
    this.processor = processor;
    this.mute = mute;
    this.boundTrackId = media.id;
    if (ctx.state === "suspended") void ctx.resume();
  }

  private teardownGraph() {
    try {
      this.processor?.disconnect();
      this.source?.disconnect();
      this.mute?.disconnect();
    } catch {
      /* already closed */
    }
    this.processor = null;
    this.source = null;
    this.mute = null;
    this.boundTrackId = null;
    if (this.ctx) {
      void this.ctx.close().catch(() => undefined);
      this.ctx = null;
    }
  }

  private async flush() {
    if (this.sending) return;
    if (this.pendingSamples < this.nativeRate * 0.6) return;
    const chunks = this.pending;
    const startedAt = this.chunkStartedAt;
    this.pending = [];
    this.pendingSamples = 0;
    this.chunkStartedAt = null;
    if (chunks.length === 0 || !this.meetingId) return;
    const total = chunks.reduce((n, c) => n + c.length, 0);
    const merged = new Float32Array(total);
    let offset = 0;
    for (const chunk of chunks) {
      merged.set(chunk, offset);
      offset += chunk.length;
    }
    const pcm = downsample(merged, this.nativeRate, 16000);
    if (rms(pcm) < 0.01) return;
    this.sending = true;
    try {
      const wav = encodeWav(pcm, 16000);
      const form = new FormData();
      form.append("audio", wav, "chunk.wav");
      form.append("audioFormat", "wav");
      form.append("samplingRate", "16000");
      form.append("language", this.language);
      if (startedAt) form.append("startedAt", startedAt.toISOString());
      form.append("endedAt", new Date().toISOString());
      await api.post(
        `meetings/${this.meetingId}/transcript`,
        form,
        this.token ? { headers: { Authorization: `Bearer ${this.token}` } } : undefined,
      );
    } catch {
      /* keep the live call going even if a chunk fails */
    } finally {
      this.sending = false;
    }
  }
}
