/** Upstash requires TLS. Render often stores redis:// — upgrade to rediss://. */
export function redisUrlWithTls(raw: string): string {
  const url = String(raw || '').trim();
  if (!url) return url;
  const isUpstash = /upstash\.io/i.test(url);
  if (url.startsWith('rediss://')) return url;
  if (url.startsWith('redis://') && isUpstash) {
    return `rediss://${url.slice('redis://'.length)}`;
  }
  return url;
}

export function redisUsesTls(url: string): boolean {
  return url.startsWith('rediss://') || /upstash\.io/i.test(url);
}
