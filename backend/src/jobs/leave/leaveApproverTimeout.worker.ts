import { Worker } from 'bullmq';
import { getBullmqConnection } from '../../config/bullmq';
import { prisma } from '../../config/prisma';
import { leaveAdminService } from '../../modules/leave/leaveAdmin.service';
import { LEAVE_QUEUE_NAMES } from './leave.queues';

function isPendingStep(s: { action: unknown; isSuperseded: boolean }) {
  return !s.isSuperseded && (s.action === null || typeof s.action === 'undefined');
}

async function processExpiredApproverWindows() {
  const setting = await prisma.leaveSetting.findUnique({
    where: { key: 'approver_timeout_action' },
  });
  const timeoutAction = (setting?.value ?? 'escalate').toLowerCase();
  const rejectOnTimeout = timeoutAction === 'reject';

  const now = new Date();
  const expired = await prisma.leaveApprovalStep.findMany({
    where: {
      action: null,
      isSuperseded: false,
      windowExpiresAt: { lte: now },
      application: { status: 'PENDING' },
    },
    select: {
      id: true,
      applicationId: true,
      stepNumber: true,
      approverUserId: true,
    },
    take: 100,
  });

  let processed = 0;
  for (const step of expired) {
    const steps = await prisma.leaveApprovalStep.findMany({
      where: { applicationId: step.applicationId },
    });
    const pending = steps.filter(isPendingStep);
    if (pending.length === 0) continue;
    const minTier = Math.min(...pending.map((s) => s.stepNumber));
    // Only act on the current tier — later tiers must wait their turn
    if (step.stepNumber !== minTier) continue;

    try {
      if (rejectOnTimeout) {
        await leaveAdminService.rejectStep(
          step.applicationId,
          step.approverUserId ?? 'system',
          'system',
          'Auto-rejected: approver window expired',
          { allowAdminOverride: true },
        );
      } else {
        // escalate = auto-approve this layer and move to next reporting manager
        await leaveAdminService.approveStep(
          step.applicationId,
          step.approverUserId ?? 'system',
          'system',
          'Auto-escalated: approver window expired',
          { allowAdminOverride: true },
        );
      }
      processed += 1;
    } catch (err) {
      console.warn('[leave.approver_timeout] failed for', step.applicationId, err);
    }
  }

  return { processed, action: rejectOnTimeout ? 'reject' : 'escalate' };
}

export function startLeaveApproverTimeoutWorker() {
  const connection = getBullmqConnection();

  return new Worker(
    LEAVE_QUEUE_NAMES.APPROVER_TIMEOUT,
    async (job) => {
      if (job.name !== 'scan') return;
      return processExpiredApproverWindows();
    },
    { connection },
  );
}
