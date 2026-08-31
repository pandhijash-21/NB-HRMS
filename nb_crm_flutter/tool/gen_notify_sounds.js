const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'assets', 'sounds');
fs.mkdirSync(dir, { recursive: true });

const fr = 22050;

function tone(freq, dur, amp = 0.36) {
  const n = Math.floor(fr * dur);
  const samples = [];
  for (let i = 0; i < n; i++) {
    const env = Math.min(1, i / 140) * Math.min(1, (n - i) / 280);
    const v = amp * env * Math.sin(2 * Math.PI * freq * (i / fr));
    samples.push(Math.max(-1, Math.min(1, v)));
  }
  return samples;
}

function silence(dur) {
  return Array(Math.floor(fr * dur)).fill(0);
}

function writeWav(name, samples) {
  const dataSize = samples.length * 2;
  const buf = Buffer.alloc(44 + dataSize);
  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + dataSize, 4);
  buf.write('WAVE', 8);
  buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(fr, 24);
  buf.writeUInt32LE(fr * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write('data', 36);
  buf.writeUInt32LE(dataSize, 40);
  for (let i = 0; i < samples.length; i++) {
    buf.writeInt16LE(Math.round(samples[i] * 32767), 44 + i * 2);
  }
  const out = path.join(dir, name);
  fs.writeFileSync(out, buf);
  console.log('wrote', out, samples.length, 'samples');
}

writeWav('notify.wav', [
  ...tone(880, 0.08, 0.28),
  ...silence(0.04),
  ...tone(1320, 0.14, 0.32),
]);

writeWav('ringtone.wav', [
  ...tone(440, 0.38, 0.42),
  ...silence(0.08),
  ...tone(554, 0.38, 0.42),
  ...silence(0.85),
]);
