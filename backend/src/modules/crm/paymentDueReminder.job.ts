import { prisma } from '../../config/prisma';
import { emitPushNotify } from '../collaboration/socket';
import { sseService } from '../events/sse.service';

const IST_OFFSET_MS = 330 * 60 * 1000;
const REMINDER_START_MINUTES = 7 * 60;

let running = false;

function istParts(now = new Date()) {
  const shifted = new Date(now.getTime() + IST_OFFSET_MS);
  const year = shifted.getUTCFullYear();
  const month = shifted.getUTCMonth();
  const day = shifted.getUTCDate();
  const minutes = shifted.getUTCHours() * 60 + shifted.getUTCMinutes();
  const ymd = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  const tomorrow = new Date(Date.UTC(year, month, day) + 24 * 60 * 60 * 1000);
  const tomorrowYmd = `${tomorrow.getUTCFullYear()}-${String(tomorrow.getUTCMonth() + 1).padStart(2, '0')}-${String(
    tomorrow.getUTCDate(),
  ).padStart(2, '0')}`;
  return { minutes, ymd, tomorrowYmd };
}

function asCustom(raw: unknown): Record<string, any> {
  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    return { ...(raw as Record<string, any>) };
  }
  return {};
}

function ensureDueDate(row: any, bookingIso?: string): string | null {
  if (row?.dueDate) return String(row.dueDate).slice(0, 10);
  const months = Number(row?.months) || 0;
  const base = bookingIso ? new Date(bookingIso) : new Date();
  if (Number.isNaN(base.getTime())) return null;
  const due = new Date(base.getFullYear(), base.getMonth() + months, base.getDate());
  return `${due.getFullYear()}-${String(due.getMonth() + 1).padStart(2, '0')}-${String(due.getDate()).padStart(2, '0')}`;
}

async function notifyAssignee(userId: string, title: string, body: string, leadId: string) {
  await prisma.userNotification.create({
    data: {
      userId,
      title,
      body,
      kind: 'payment_due_reminder',
      path: `/crm/post-sales?leadId=${leadId}`,
    },
  });
  const payload = {
    kind: 'payment_due_reminder',
    title,
    body,
    path: `/crm/post-sales?leadId=${leadId}`,
  };
  emitPushNotify([userId], payload);
  try {
    sseService.toUser(userId, 'push_notify', payload);
  } catch (_) {}
}

/**
 * Remind post-sales assignees one day before and on the installment due date (IST).
 */
export async function runPaymentDueReminders() {
  if (running) return;
  running = true;
  try {
    const { minutes, ymd, tomorrowYmd } = istParts();
    if (minutes < REMINDER_START_MINUTES) return;

    const leads = await prisma.crmLead.findMany({
      where: {
        isDeleted: false,
        status: 'BOOKING_CONFIRMED',
      },
      include: {
        assignedTo: { include: { user: { select: { id: true } }, generalInfo: { select: { fullName: true } } } },
      },
      take: 500,
    });

    for (const lead of leads) {
      const custom = asCustom(lead.customFields);
      const schedule: any[] = Array.isArray(custom.paymentSchedule) ? custom.paymentSchedule : [];
      if (!schedule.length) continue;

      const bookingIso = custom.bookingConfirmedAt || custom.postSalesHandoffAt;
      const reminderMap: Record<string, any> =
        custom.paymentDueReminders && typeof custom.paymentDueReminders === 'object'
          ? { ...custom.paymentDueReminders }
          : {};

      let assigneeEmpId =
        Number(custom.postSalesAssigneeId) || lead.assignedToId || null;
      let userId: string | null = lead.assignedTo?.user?.id || null;

      if (assigneeEmpId && (!userId || assigneeEmpId !== lead.assignedToId)) {
        const emp = await prisma.employee.findUnique({
          where: { id: assigneeEmpId },
          select: { user: { select: { id: true } } },
        });
        userId = emp?.user?.id || userId;
      }
      if (!userId) continue;

      let changed = false;
      for (const row of schedule) {
        const status = String(row.status || 'PENDING').toUpperCase();
        if (status === 'PAID') continue;
        const due = ensureDueDate(row, bookingIso);
        if (!due) continue;
        const seq = String(row.seq ?? '');
        const name = String(row.name || `Installment ${seq}`);
        const amount = Number(row.amount) || 0;

        const kinds: Array<{ key: string; when: string; label: string }> = [];
        if (due === tomorrowYmd) kinds.push({ key: `${seq}:day_before`, when: 'tomorrow', label: 'tomorrow' });
        if (due === ymd) kinds.push({ key: `${seq}:due_day`, when: 'today', label: 'today' });

        for (const k of kinds) {
          if (reminderMap[k.key]) continue;
          const title =
            k.when === 'today'
              ? `Payment due today — ${lead.name || 'Client'}`
              : `Payment due tomorrow — ${lead.name || 'Client'}`;
          const body = `${name} (₹ ${amount.toLocaleString('en-IN')}) for ${
            lead.name || 'client'
          } / ${lead.phone} is due ${k.label}. Please call and follow up.`;
          try {
            await notifyAssignee(userId, title, body, lead.id);
            reminderMap[k.key] = new Date().toISOString();
            changed = true;
          } catch (err) {
            console.warn(`[PaymentDueReminder] notify failed lead=${lead.id} seq=${seq}`, err);
          }
        }
      }

      if (changed) {
        await prisma.crmLead.update({
          where: { id: lead.id },
          data: {
            customFields: {
              ...custom,
              paymentDueReminders: reminderMap,
            },
          },
        });
      }
    }
  } catch (err) {
    console.error('[PaymentDueReminder] worker error:', err);
  } finally {
    running = false;
  }
}
