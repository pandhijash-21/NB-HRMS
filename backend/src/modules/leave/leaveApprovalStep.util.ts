import { prisma } from '../../config/prisma';

export const APPROVER_ROLE_LABELS: Record<string, string> = {
  FIRST_REPORTING: '1st Reporting',
  SECOND_REPORTING: '2nd Reporting',
  THIRD_REPORTING: '3rd Reporting',
  HOD: 'HOD',
  HOI: 'HOI',
  VC: 'VC',
  REGISTRAR: 'Registrar',
};

type StepLike = {
  approverUserId: string | null;
  [key: string]: unknown;
};

export async function approverNameMap(userIds: string[]): Promise<Record<string, string>> {
  const ids = [...new Set(userIds.filter(Boolean))];
  if (ids.length === 0) return {};

  const out: Record<string, string> = {};
  const users = await prisma.user.findMany({
    where: { id: { in: ids } },
    select: {
      id: true,
      username: true,
      employee: {
        select: {
          generalInfo: { select: { fullName: true, employeeCode: true } },
        },
      },
      positionSlot: {
        select: { name: true, code: true },
      },
    },
  });

  for (const u of users) {
    const empName = u.employee?.generalInfo?.fullName?.trim();
    const empCode = u.employee?.generalInfo?.employeeCode?.trim();
    if (empName) {
      out[u.id] = empCode ? `${empName} (${empCode})` : empName;
      continue;
    }
    const slot = u.positionSlot;
    if (slot?.name || slot?.code) {
      const label = slot.name || slot.code;
      out[u.id] = slot.code ? `${label} (${slot.code})` : label;
      continue;
    }
    if (u.username) {
      out[u.id] = u.username;
      continue;
    }
    out[u.id] = u.id;
  }

  return out;
}

export async function enrichApprovalSteps<T extends StepLike>(steps: T[]) {
  const names = await approverNameMap(
    steps.map((s) => s.approverUserId).filter((id): id is string => Boolean(id)),
  );
  return steps.map((s) => ({
    ...s,
    approverName: s.approverUserId ? names[s.approverUserId] ?? null : null,
  }));
}

export async function enrichApplicationsWithApproverNames<
  T extends { approvalSteps?: StepLike[] },
>(apps: T[]) {
  const allIds = apps.flatMap((a) =>
    (a.approvalSteps ?? []).map((s) => s.approverUserId).filter((id): id is string => Boolean(id)),
  );
  const names = await approverNameMap(allIds);
  return apps.map((app) => ({
    ...app,
    approvalSteps: (app.approvalSteps ?? []).map((s) => ({
      ...s,
      approverName: s.approverUserId ? names[s.approverUserId] ?? null : null,
    })),
  }));
}

export function approvalPipelineSummary(
  steps: Array<{
    approverRole: string;
    action: string | null;
    isSuperseded: boolean;
    approverName?: string | null;
  }>,
): string | null {
  const active = steps.filter((s) => !s.isSuperseded);
  if (active.length === 0) return null;

  const done = active.filter((s) => s.action === 'RECOMMENDED' || s.action === 'APPROVED');
  const pending = active.find((s) => !s.action);
  if (done.length === 0 && pending) {
    const who = pending.approverName ?? APPROVER_ROLE_LABELS[pending.approverRole] ?? 'Approver';
    return `Awaiting ${who}`;
  }
  if (pending) {
    const last = done[done.length - 1];
    const lastWho = last?.approverName ?? APPROVER_ROLE_LABELS[last?.approverRole ?? ''] ?? 'Previous approver';
    const nextWho = pending.approverName ?? APPROVER_ROLE_LABELS[pending.approverRole] ?? 'Approver';
    return `${lastWho} approved · ${nextWho} pending`;
  }
  return 'All approvers completed';
}
