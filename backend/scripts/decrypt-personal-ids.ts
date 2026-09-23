/**
 * One-time: decrypt legacy AES aadhaar/pan values stored as hex:hex ciphertext.
 * Safe to re-run — plaintext values are left unchanged.
 */
import { PrismaClient } from '@prisma/client';
import { decrypt } from '../src/utils/crypto';

const p = new PrismaClient();

function looksEncrypted(value: string | null | undefined): boolean {
  return !!value && /^[0-9a-f]+:[0-9a-f]+$/i.test(value);
}

async function main() {
  const rows = await p.employeePersonalInfo.findMany({
    select: { id: true, aadhaarNo: true, panNo: true },
  });
  let updated = 0;
  for (const row of rows) {
    let aadhaarNo = row.aadhaarNo;
    let panNo = row.panNo;
    let dirty = false;
    if (looksEncrypted(aadhaarNo)) {
      try {
        aadhaarNo = decrypt(aadhaarNo!);
        dirty = true;
      } catch {
        /* leave as-is */
      }
    }
    if (looksEncrypted(panNo)) {
      try {
        panNo = decrypt(panNo!);
        dirty = true;
      } catch {
        /* leave as-is */
      }
    }
    if (!dirty) continue;
    await p.employeePersonalInfo.update({
      where: { id: row.id },
      data: { aadhaarNo, panNo },
    });
    updated += 1;
  }
  console.log(`Decrypted plaintext for ${updated} personal_info row(s)`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await p.$disconnect();
  });
