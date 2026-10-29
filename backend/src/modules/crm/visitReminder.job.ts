import { prisma } from '../../config/prisma';
import { whatsappService } from './whatsapp.service';

const IST_OFFSET_MS = 330 * 60 * 1000;
/** Start sending day-of reminders from 07:00 IST */
const REMINDER_START_MINUTES = 7 * 60;
/** Stop sending once visit time has passed by this many minutes */
const GRACE_AFTER_VISIT_MINUTES = 30;

let running = false;

function istParts(now = new Date()) {
  const shifted = new Date(now.getTime() + IST_OFFSET_MS);
  const year = shifted.getUTCFullYear();
  const month = shifted.getUTCMonth();
  const day = shifted.getUTCDate();
  const minutes = shifted.getUTCHours() * 60 + shifted.getUTCMinutes();
  const dayStartUtc = new Date(Date.UTC(year, month, day) - IST_OFFSET_MS);
  const dayEndUtc = new Date(dayStartUtc.getTime() + 24 * 60 * 60 * 1000);
  const ymd = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  return { minutes, dayStartUtc, dayEndUtc, ymd };
}

function asCustom(raw: unknown): Record<string, any> {
  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    return { ...(raw as Record<string, any>) };
  }
  return {};
}

/**
 * Auto-send BotBiz `visit_reminder` on the morning of a scheduled site visit.
 * Runs safely every few minutes; each lead+visit is reminded at most once.
 */
export async function runVisitReminders() {
  if (running) return;
  running = true;
  try {
    const now = new Date();
    const { minutes: nowMinutes, dayStartUtc, dayEndUtc, ymd } = istParts(now);

    // Too early in the day (IST) — wait until 7 AM
    if (nowMinutes < REMINDER_START_MINUTES) return;

    const leads = await prisma.crmLead.findMany({
      where: {
        isDeleted: false,
        status: 'SCHEDULED_VISIT',
        scheduledVisitAt: {
          gte: dayStartUtc,
          lt: dayEndUtc,
        },
        phone: { not: '' },
      },
      include: {
        campaign: { include: { project: true } },
        assignedTo: { include: { generalInfo: true } },
      },
      take: 200,
    });

    if (!leads.length) return;

    let sent = 0;
    let skipped = 0;

    for (const lead of leads) {
      const visitAt = lead.scheduledVisitAt;
      if (!visitAt) continue;

      const visitKey = visitAt.toISOString();
      const custom = asCustom(lead.customFields);

      // Already reminded for this exact visit slot
      if (
        custom.visitReminderFor === visitKey &&
        (custom.visitReminderSentAt || custom.visit_reminder_sent_at)
      ) {
        skipped++;
        continue;
      }

      // Visit already finished (with small grace)
      const visitEnd = visitAt.getTime() + GRACE_AFTER_VISIT_MINUTES * 60 * 1000;
      if (now.getTime() > visitEnd) {
        skipped++;
        continue;
      }

      const scope = lead.scope || 'NB_DEVELOPER';
      const projectName =
        lead.campaign?.project?.name ||
        (scope === 'NB_FINSERVE' ? 'NB Finserve' : 'Legacy Tower');

      try {
        const result = await whatsappService.triggerEvent(
          'SITE_VISIT_REMINDER',
          lead,
          {
            scope,
            projectName,
            visitDate: visitAt,
            agentName: lead.assignedTo?.generalInfo?.fullName,
          },
        );

        if (result.skipped) {
          skipped++;
          continue;
        }

        if (!result.success) {
          console.warn(
            `[Visit Reminder] Failed for lead ${lead.id}: ${result.error || 'unknown'}`,
          );
          continue;
        }

        const nextCustom = {
          ...custom,
          visitReminderFor: visitKey,
          visitReminderSentAt: now.toISOString(),
          visitReminderDay: ymd,
        };
        await prisma.crmLead.update({
          where: { id: lead.id },
          data: { customFields: nextCustom },
        });
        sent++;
        console.log(
          `[Visit Reminder] Sent visit_reminder to ${lead.phone} (lead ${lead.id}, visit ${visitKey})`,
        );
      } catch (err: any) {
        console.error(`[Visit Reminder] Error for lead ${lead.id}:`, err?.message || err);
      }
    }

    if (sent > 0 || skipped > 0) {
      console.log(
        `[Visit Reminder] ${ymd}: sent=${sent} skipped=${skipped} candidates=${leads.length}`,
      );
    }
  } finally {
    running = false;
  }
}
