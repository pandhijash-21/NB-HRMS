const fs = require('fs');
const path = require('path');

const out = path.join(__dirname, '..', 'assets', 'sounds', 'location_alert.wav');
fs.mkdirSync(path.dirname(out), { recursive: true });

const fr = 22050;

function tone(freq, dur, amp = 0.38) {
  const n = Math.floor(fr * dur);
  const samples = [];
  for (let i = 0; i < n; i++) {
    const env = Math.min(1, i / 180) * Math.min(1, (n - i) / 360);
    const v = amp * env * Math.sin(2 * Math.PI * freq * (i / fr));
    samples.push(Math.max(-1, Math.min(1, v)));
  }
  return samples;
}

const samples = [
  ...tone(880, 0.16),
  ...Array(Math.floor(fr * 0.07)).fill(0),
  ...tone(1175, 0.16),
  ...Array(Math.floor(fr * 0.07)).fill(0),
  ...tone(988, 0.24),
];

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
fs.writeFileSync(out, buf);
console.log('wrote', out, samples.length, 'samples');
