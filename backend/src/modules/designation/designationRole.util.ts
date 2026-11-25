import type { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { invalidateRolePermissionCache, invalidateUserRoleCache } from '../auth/permissions-map';
import { invalidateRoleSessions } from '../user-management/permission.service';

export function slugify(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
}

export function roleCodeFromName(name: string): string {
  return slugify(name).toUpperCase();
}

async function copyRolePermissionsFromTemplate(
  tx: Prisma.TransactionClient,
  templateRoleName: string,
  targetRoleId: string,
  updatedBy?: string,
) {
  const template = await tx.role.findUnique({ where: { name: templateRoleName } });
  if (!template) return;

  const perms = await tx.rolePermission.findMany({ where: { roleId: template.id } });
  if (!perms.length) return;

  await tx.rolePermission.createMany({
    data: perms.map((p) => ({
      roleId: targetRoleId,
      moduleKey: p.moduleKey,
      canRead: p.canRead,
      canWrite: p.canWrite,
      canApprove: p.canApprove,
      canDelete: p.canDelete,
      canExport: p.canExport,
      employeeViewScope: p.employeeViewScope,
      updatedBy,
    })),
    skipDuplicates: true,
  });
}

/**
 * Given a designation name or ID, finds or creates the matching master Designation
 * and its corresponding Role (e.g. Telecaller <-> TELECALLER / Telecallers).
 */
export async function resolveOrCreateRoleForDesignation(
  tx: Prisma.TransactionClient,
  designationNameOrId: string,
  creatorId?: string,
): Promise<{
  role: { id: string; name: string };
  designation: { id: string; name: string; linkedRoleId: string | null };
}> {
  const raw = designationNameOrId.trim();
  if (!raw) {
    const defaultRole = await tx.role.findFirst({ where: { name: 'EMPLOYEE' } });
    if (!defaultRole) throw new Error('EMPLOYEE role not found');
    return {
      role: defaultRole,
      designation: { id: '', name: '', linkedRoleId: defaultRole.id },
    };
  }

  // 1. Try finding Designation by ID or Name
  let designation = await tx.designation.findFirst({
    where: {
      OR: [
        { id: raw },
        { name: { equals: raw, mode: 'insensitive' } },
        { slug: slugify(raw) },
      ],
      isActive: true,
    },
    include: { linkedRole: { select: { id: true, name: true, isActive: true } } },
  });

  // If designation already has a linked role, use it (reactivate if needed)
  if (designation?.linkedRole) {
    if (!designation.linkedRole.isActive) {
      await tx.role.update({
        where: { id: designation.linkedRole.id },
        data: { isActive: true },
      });
    }
    return {
      role: { id: designation.linkedRole.id, name: designation.linkedRole.name },
      designation: {
        id: designation.id,
        name: designation.name,
        linkedRoleId: designation.linkedRoleId,
      },
    };
  }

  // 2. Search for matching existing Role (include inactive — unique name still blocks recreate)
  const desigName = designation?.name ?? raw;
  const code = roleCodeFromName(desigName);
  const normalized = desigName.trim().toUpperCase().replace(/[\s-]+/g, '_');

  const candidates = [
    code,
    normalized,
    desigName.trim(),
    `${code}S`,
    `${normalized}S`,
    `${desigName.trim()}s`,
    `${desigName.trim()}S`,
  ];
  if (code.endsWith('S')) candidates.push(code.slice(0, -1));
  if (normalized.endsWith('S')) candidates.push(normalized.slice(0, -1));
  if (desigName.toLowerCase().endsWith('s')) candidates.push(desigName.slice(0, -1));

  const uniqueCandidates = [...new Set(candidates.filter(Boolean))];

  // Prefer equals+insensitive over `in`+mode (Prisma `in` does not reliably honor mode)
  let matchingRole =
    (await tx.role.findFirst({
      where: {
        OR: uniqueCandidates.map((name) => ({
          name: { equals: name, mode: 'insensitive' as const },
        })),
      },
      orderBy: { isActive: 'desc' },
    })) ?? null;

  // If still not found, slug-match without trailing 's'
  if (!matchingRole) {
    const allRoles = await tx.role.findMany();
    const targetSlug = slugify(desigName).replace(/s$/, '');
    matchingRole =
      allRoles.find((r) => {
        const rSlug = slugify(r.name).replace(/s$/, '');
        return rSlug === targetSlug && r.name.toUpperCase() !== 'ADMIN';
      }) ?? null;
  }

  // 3. If no matching role exists at all, create one (handle unique race / leftover name)
  if (!matchingRole) {
    const newRoleName = code || normalized || 'EMPLOYEE';
    const sanitizedName = /^[A-Z][A-Z0-9_]*$/.test(newRoleName)
      ? newRoleName
      : `ROLE_${normalized}`;

    try {
      matchingRole = await tx.role.create({
        data: {
          name: sanitizedName,
          description: `Permissions for ${desigName}`,
          isSystem: false,
          createdBy: creatorId ?? null,
        },
      });
      await copyRolePermissionsFromTemplate(tx, 'EMPLOYEE', matchingRole.id, creatorId);
    } catch (err: unknown) {
      const codeName =
        err && typeof err === 'object' && 'code' in err
          ? String((err as { code?: string }).code)
          : '';
      if (codeName !== 'P2002') throw err;
      matchingRole = await tx.role.findFirst({
        where: { name: { equals: sanitizedName, mode: 'insensitive' } },
      });
      if (!matchingRole) throw err;
    }
  }

  if (!matchingRole.isActive) {
    matchingRole = await tx.role.update({
      where: { id: matchingRole.id },
      data: { isActive: true },
    });
  }

  // 4. Ensure master Designation exists and has linkedRoleId set
  if (designation) {
    if (designation.linkedRoleId !== matchingRole.id) {
      designation = await tx.designation.update({
        where: { id: designation.id },
        data: { linkedRoleId: matchingRole.id },
        include: { linkedRole: { select: { id: true, name: true, isActive: true } } },
      });
    }
  } else {
    // Create master designation
    const slug = slugify(desigName);
    const existingSlug = await tx.designation.findUnique({ where: { slug } });
    const finalSlug = existingSlug ? `${slug}_${Date.now().toString(36)}` : slug;

    designation = await tx.designation.create({
      data: {
        name: desigName,
        slug: finalSlug,
        isAlias: false,
        linkedRoleId: matchingRole.id,
      },
      include: { linkedRole: { select: { id: true, name: true, isActive: true } } },
    });
  }

  return {
    role: matchingRole,
    designation: {
      id: designation.id,
      name: designation.name,
      linkedRoleId: designation.linkedRoleId,
    },
  };
}

/**
 * Synchronize an employee's user account role to match their designation.
 * Automatically updates `user.roleId`, `employeeGeneralInfo.designationId`,
 * and immediately broadcasts real-time invalidation.
 */
export async function syncEmployeeRoleFromDesignation(
  employeeId: number,
  designationNameOrId: string,
  updaterId?: string,
): Promise<{
  updated: boolean;
  roleId: string;
  roleName: string;
  designationId: string | null;
} | null> {
  const emp = await prisma.employee.findUnique({
    where: { id: employeeId },
    include: {
      user: { include: { role: true } },
      generalInfo: true,
    },
  });

  if (!emp) return null;

  // If employee has no user, we can still link designationId in generalInfo
  const { role, designation } = await prisma.$transaction(async (tx) => {
    return resolveOrCreateRoleForDesignation(tx, designationNameOrId, updaterId);
  });

  // Ensure generalInfo has designationId linked
  if (emp.generalInfo && emp.generalInfo.designationId !== designation.id) {
    await prisma.employeeGeneralInfo.update({
      where: { employeeId },
      data: { designationId: designation.id },
    });
  }

  if (!emp.user) {
    return {
      updated: false,
      roleId: role.id,
      roleName: role.name,
      designationId: designation.id,
    };
  }

  // Preserve dedicated Admin accounts if not intended to be changed
  if (emp.user.role?.name === 'ADMIN' && role.name !== 'ADMIN') {
    // Only skip if the employee is the core System Admin
    if (emp.user.username === 'admin' || emp.id === 1) {
      return {
        updated: false,
        roleId: emp.user.roleId,
        roleName: emp.user.role.name,
        designationId: designation.id,
      };
    }
  }

  const oldRoleId = emp.user.roleId;
  const needsUpdate = emp.user.roleId !== role.id;

  if (needsUpdate) {
    await prisma.user.update({
      where: { id: emp.user.id },
      data: {
        roleId: role.id,
        updatedBy: updaterId,
      },
    });

    invalidateUserRoleCache(emp.user.id);
    invalidateRolePermissionCache(role.id);
    if (oldRoleId) invalidateRolePermissionCache(oldRoleId);

    await invalidateRoleSessions(role.id);
    if (oldRoleId) await invalidateRoleSessions(oldRoleId);
  }

  return {
    updated: needsUpdate,
    roleId: role.id,
    roleName: role.name,
    designationId: designation.id,
  };
}

/**
 * Startup bootstrap reconciliation:
 * Scans all employees with active user accounts and ensures their role matches
 * their current designation. Fixes legacy or out-of-sync roles immediately.
 */
export async function syncAllEmployeeRolesWithDesignations(): Promise<{ synced: number }> {
  try {
    const employees = await prisma.employee.findMany({
      where: {
        status: 'ACTIVE',
        user: { isNot: null },
        generalInfo: { isNot: null },
      },
      include: {
        user: { select: { id: true, roleId: true, role: { select: { name: true } } } },
        generalInfo: { select: { designation: true, designationId: true } },
      },
    });

    let count = 0;
    for (const emp of employees) {
      const desig = emp.generalInfo?.designation?.trim();
      if (!desig) continue;

      // Skip system admin account
      if (emp.user?.role?.name === 'ADMIN' && emp.id === 1) continue;

      const result = await syncEmployeeRoleFromDesignation(emp.id, desig, 'system-startup');
      if (result?.updated) {
        count++;
        console.log(
          `[DesignationRoleSync] Synced Emp #${emp.id} ("${desig}") -> Role "${result.roleName}"`,
        );
      }
    }

    if (count > 0) {
      console.log(`[DesignationRoleSync] Successfully reconciled ${count} employee role(s).`);
    }

    return { synced: count };
  } catch (err) {
    console.warn('[DesignationRoleSync] Startup sync error:', err);
    return { synced: 0 };
  }
}
