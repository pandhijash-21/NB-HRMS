import type { AddressType } from '@prisma/client';

export function parseAddressType(type: string): AddressType {
  const t = type.toLowerCase();
  if (t === 'local') return 'LOCAL';
  if (t === 'permanent') return 'PERMANENT';
  throw new Error('Invalid address type');
}

