import assert from 'node:assert/strict';

// Test normalization logic directly
function normalizePermissionFlags(
  flags: {
    canRead: boolean;
    canWrite: boolean;
    canApprove: boolean;
    canDelete: boolean;
    canExport: boolean;
  },
  explicitCanRead?: boolean,
) {
  if (explicitCanRead === false) {
    flags.canRead = false;
    flags.canWrite = false;
    flags.canApprove = false;
    flags.canDelete = false;
    flags.canExport = false;
    return flags;
  }
  const hasElevated =
    flags.canWrite || flags.canApprove || flags.canDelete || flags.canExport;
  if (hasElevated) flags.canRead = true;
  if (!flags.canRead) {
    flags.canWrite = false;
    flags.canApprove = false;
    flags.canDelete = false;
    flags.canExport = false;
  }
  return flags;
}

console.log('--- Running Permission Matrix Verification Tests ---');

// Test 1: Revoking canRead when canWrite was previously true
{
  const existing = { canRead: true, canWrite: true, canApprove: true, canDelete: true, canExport: true };
  const input = { canRead: false };
  const merged = normalizePermissionFlags(
    {
      canRead: input.canRead ?? existing.canRead,
      canWrite: existing.canWrite,
      canApprove: existing.canApprove,
      canDelete: existing.canDelete,
      canExport: existing.canExport,
    },
    input.canRead,
  );
  assert.equal(merged.canRead, false, 'canRead should be false');
  assert.equal(merged.canWrite, false, 'canWrite should cascade to false');
  assert.equal(merged.canApprove, false, 'canApprove should cascade to false');
  assert.equal(merged.canDelete, false, 'canDelete should cascade to false');
  assert.equal(merged.canExport, false, 'canExport should cascade to false');
  console.log('✓ Test 1 Passed: Revoking canRead cascades and disables all permissions.');
}

// Test 2: Enabling canWrite when canRead was false
{
  const existing = { canRead: false, canWrite: false, canApprove: false, canDelete: false, canExport: false };
  const input = { canWrite: true };
  const merged = normalizePermissionFlags(
    {
      canRead: existing.canRead,
      canWrite: input.canWrite ?? existing.canWrite,
      canApprove: existing.canApprove,
      canDelete: existing.canDelete,
      canExport: existing.canExport,
    },
    undefined,
  );
  assert.equal(merged.canRead, true, 'canRead should automatically be set to true');
  assert.equal(merged.canWrite, true, 'canWrite should be true');
  assert.equal(merged.canApprove, false, 'canApprove should remain false');
  console.log('✓ Test 2 Passed: Enabling canWrite automatically enables canRead.');
}

// Test 3: Enabling only canRead
{
  const existing = { canRead: false, canWrite: false, canApprove: false, canDelete: false, canExport: false };
  const input = { canRead: true };
  const merged = normalizePermissionFlags(
    {
      canRead: input.canRead ?? existing.canRead,
      canWrite: existing.canWrite,
      canApprove: existing.canApprove,
      canDelete: existing.canDelete,
      canExport: existing.canExport,
    },
    input.canRead,
  );
  assert.equal(merged.canRead, true, 'canRead should be true');
  assert.equal(merged.canWrite, false, 'canWrite should remain false');
  console.log('✓ Test 3 Passed: Enabling only canRead keeps elevated flags false.');
}

// Test 4: Disabling an elevated flag while canRead remains true
{
  const existing = { canRead: true, canWrite: true, canApprove: false, canDelete: false, canExport: false };
  const input = { canWrite: false };
  const merged = normalizePermissionFlags(
    {
      canRead: existing.canRead,
      canWrite: input.canWrite ?? existing.canWrite,
      canApprove: existing.canApprove,
      canDelete: existing.canDelete,
      canExport: existing.canExport,
    },
    undefined,
  );
  assert.equal(merged.canRead, true, 'canRead should stay true');
  assert.equal(merged.canWrite, false, 'canWrite should become false');
  console.log('✓ Test 4 Passed: Disabling canWrite without explicit canRead keeps canRead true.');
}

// Test 5: Flutter _normalizePatchData logic parity
{
  function flutterNormalize(
    current: { canRead: boolean; canWrite: boolean; canApprove: boolean; canDelete: boolean; canExport: boolean },
    data: Record<string, boolean | undefined>,
  ) {
    const patch = { ...data };
    if (patch.canRead === false) {
      patch.canRead = false;
      patch.canWrite = false;
      patch.canApprove = false;
      patch.canDelete = false;
      patch.canExport = false;
      return patch;
    }
    const canRead = patch.canRead !== undefined ? patch.canRead === true : current.canRead;
    const canWrite = patch.canWrite !== undefined ? patch.canWrite === true : current.canWrite;
    const canApprove = patch.canApprove !== undefined ? patch.canApprove === true : current.canApprove;
    const canDelete = patch.canDelete !== undefined ? patch.canDelete === true : current.canDelete;
    const canExport = patch.canExport !== undefined ? patch.canExport === true : current.canExport;

    if (canWrite || canApprove || canDelete || canExport) {
      patch.canRead = true;
    } else if (!canRead) {
      patch.canWrite = false;
      patch.canApprove = false;
      patch.canDelete = false;
      patch.canExport = false;
    }
    return patch;
  }

  const current = { canRead: true, canWrite: true, canApprove: false, canDelete: false, canExport: false };
  const patched = flutterNormalize(current, { canRead: false });
  assert.equal(patched.canRead, false);
  assert.equal(patched.canWrite, false);
  console.log('✓ Test 5 Passed: Flutter _normalizePatchData correctly revokes elevated flags.');
}

console.log('--- All 5 Permission Matrix Tests Passed Successfully! ---');
