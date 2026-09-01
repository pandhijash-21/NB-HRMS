import os
import tempfile

from fastapi import FastAPI, File, Form, UploadFile
from faster_whisper import WhisperModel

MODEL_NAME = os.getenv("WHISPER_MODEL", "base")
DEVICE = os.getenv("WHISPER_DEVICE", "cpu")
COMPUTE = os.getenv("WHISPER_COMPUTE", "int8")

whisper_model = WhisperModel(MODEL_NAME, device=DEVICE, compute_type=COMPUTE)
app = FastAPI(title="NB CRM Whisper STT")


@app.get("/health")
def health():
    return {"ok": True, "model": MODEL_NAME}


@app.post("/v1/audio/transcriptions")
async def transcribe(
    file: UploadFile = File(...),
    language: str | None = Form(None),
    model: str | None = Form(None),
):
    _ = model
    suffix = os.path.splitext(file.filename or "audio.wav")[1] or ".wav"
    raw = await file.read()
    tmp = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    try:
        tmp.write(raw)
        tmp.close()
        lang = (language or "").strip().lower() or None
        if lang in {"auto", "und"}:
            lang = None
        segments, _info = whisper_model.transcribe(
            tmp.name,
            language=lang,
            vad_filter=True,
            beam_size=1,
        )
        text = " ".join(part.text.strip() for part in segments).strip()
        return {"text": text}
    finally:
        try:
            os.unlink(tmp.name)
        except OSError:
            pass
