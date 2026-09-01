import type { Participant, Room } from "livekit-client";

function pickMime() {
  const types = [
    "video/webm;codecs=vp9,opus",
    "video/webm;codecs=vp8,opus",
    "video/webm",
    "video/mp4",
  ];
  if (typeof MediaRecorder === "undefined") return "";
  return types.find((t) => MediaRecorder.isTypeSupported(t)) || "";
}

function stamp() {
  const d = new Date();
  const two = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${two(d.getMonth() + 1)}${two(d.getDate())}-${two(d.getHours())}${two(d.getMinutes())}`;
}

function collectAudioTracks(room: Room) {
  const tracks: MediaStreamTrack[] = [];
  const add = (track?: MediaStreamTrack | null) => {
    if (track && track.kind === "audio" && track.readyState !== "ended") tracks.push(track);
  };
  const fromParticipant = (p: Participant) => {
    p.audioTrackPublications.forEach((pub) => add(pub.track?.mediaStreamTrack));
  };
  fromParticipant(room.localParticipant);
  room.remoteParticipants.forEach(fromParticipant);
  return tracks;
}

export class MeetLocalRecorder {
  private recorder: MediaRecorder | null = null;
  private chunks: Blob[] = [];
  private audioCtx: AudioContext | null = null;
  private mixDest: MediaStreamAudioDestinationNode | null = null;
  private knownAudio = new Set<string>();
  private drawTimer: number | null = null;
  private canvas: HTMLCanvasElement | null = null;
  private code = "meet";
  private stopping = false;

  get active() {
    return Boolean(this.recorder && this.recorder.state !== "inactive");
  }

  syncAudioFromRoom(room: Room) {
    if (!this.audioCtx || !this.mixDest) return;
    for (const track of collectAudioTracks(room)) {
      if (this.knownAudio.has(track.id)) continue;
      this.knownAudio.add(track.id);
      try {
        const cloned = track.clone();
        const src = this.audioCtx.createMediaStreamSource(new MediaStream([cloned]));
        src.connect(this.mixDest);
      } catch {
        /* track may not be graph-compatible */
      }
    }
  }

  async start(opts: { room: Room; stage: HTMLElement | null; code: string }) {
    if (this.active) return;
    if (typeof MediaRecorder === "undefined") {
      throw new Error("This browser cannot record locally. Use Chrome or Edge.");
    }
    this.code = opts.code || "meet";
    this.chunks = [];
    this.knownAudio = new Set();
    this.stopping = false;

    const canvas = document.createElement("canvas");
    canvas.width = 1280;
    canvas.height = 720;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Could not start local recording");
    this.canvas = canvas;

    const AudioCtx = window.AudioContext || (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AudioCtx) throw new Error("This browser cannot record meeting audio");
    const audioCtx = new AudioCtx();
    if (audioCtx.state === "suspended") await audioCtx.resume();
    const mixDest = audioCtx.createMediaStreamDestination();
    this.audioCtx = audioCtx;
    this.mixDest = mixDest;
    this.syncAudioFromRoom(opts.room);

    const draw = () => {
      const videos = [...(opts.stage?.querySelectorAll("video") ?? [])].filter(
        (v): v is HTMLVideoElement => v instanceof HTMLVideoElement && v.videoWidth > 0,
      );
      ctx.fillStyle = "#0b0f19";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      if (videos.length === 0) {
        ctx.fillStyle = "#e5e7eb";
        ctx.font = "28px sans-serif";
        ctx.fillText("Meeting recording", 48, canvas.height / 2);
      } else {
        const cols = Math.ceil(Math.sqrt(videos.length));
        const rows = Math.ceil(videos.length / cols);
        const cellW = canvas.width / cols;
        const cellH = canvas.height / rows;
        videos.forEach((video, i) => {
          const col = i % cols;
          const row = Math.floor(i / cols);
          const vw = video.videoWidth;
          const vh = video.videoHeight;
          const scale = Math.min(cellW / vw, cellH / vh);
          const w = vw * scale;
          const h = vh * scale;
          const x = col * cellW + (cellW - w) / 2;
          const y = row * cellH + (cellH - h) / 2;
          try {
            ctx.drawImage(video, x, y, w, h);
          } catch {
            /* frame skipped */
          }
        });
      }
    };
    draw();
    this.drawTimer = window.setInterval(draw, 1000 / 15);

    const canvasStream = canvas.captureStream(15);
    const mixed = new MediaStream([
      ...canvasStream.getVideoTracks(),
      ...mixDest.stream.getAudioTracks(),
    ]);
    const mime = pickMime();
    const recorder = mime ? new MediaRecorder(mixed, { mimeType: mime }) : new MediaRecorder(mixed);
    recorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) this.chunks.push(e.data);
    };
    recorder.start(1000);
    this.recorder = recorder;
  }

  async stop(opts?: { download?: boolean }) {
    if (this.stopping || !this.recorder) return;
    this.stopping = true;
    const recorder = this.recorder;
    const done = new Promise<void>((resolve) => {
      if (recorder.state === "inactive") {
        resolve();
        return;
      }
      recorder.addEventListener("stop", () => resolve(), { once: true });
      try {
        recorder.stop();
      } catch {
        resolve();
      }
    });
    await done;
    if (this.drawTimer != null) window.clearInterval(this.drawTimer);
    this.drawTimer = null;
    this.canvas = null;
    try {
      await this.audioCtx?.close();
    } catch {
      /* ignore */
    }
    this.audioCtx = null;
    this.mixDest = null;
    this.recorder = null;
    const blob = new Blob(this.chunks, { type: this.chunks[0]?.type || "video/webm" });
    this.chunks = [];
    this.stopping = false;
    if (opts?.download !== false && blob.size > 0) {
      const ext = blob.type.includes("mp4") ? "mp4" : "webm";
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = `meeting-${this.code}-${stamp()}.${ext}`;
      a.click();
      window.setTimeout(() => URL.revokeObjectURL(a.href), 30_000);
    }
  }
}
