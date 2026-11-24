import { prisma } from '../../config/prisma';

export interface ActivityLogInput {
  tableName: string; // 'USER_CLICK', 'PAGE_VIEW', 'SYSTEM_ACTION', 'AUTH', etc.
  recordId: string;  // Route path, screen name, or entity ID
  employeeId?: number | null;
  fieldName: string; // Target button / action / screen label
  oldValue?: string | null; // Screen / context / previous value
  newValue?: string | null; // Action result / coordinates / metadata
  changedBy: string; // User ID
  changeReason?: string | null;
  ipAddress?: string | null;
  userAgent?: string | null;
  changedAt?: Date;
}

class ActivityTrackerService {
  private buffer: ActivityLogInput[] = [];
  private flushTimer: NodeJS.Timeout | null = null;
  private readonly BATCH_SIZE = 100;
  private readonly FLUSH_INTERVAL_MS = 1500;

  constructor() {
    this.startFlushTimer();
  }

  private startFlushTimer() {
    if (this.flushTimer) return;
    this.flushTimer = setInterval(() => {
      void this.flush();
    }, this.FLUSH_INTERVAL_MS);
    // Don't keep Node process alive just for the timer
    if (this.flushTimer.unref) {
      this.flushTimer.unref();
    }
  }

  /**
   * Enqueue a single activity or click event.
   */
  enqueue(entry: ActivityLogInput) {
    if (!entry.changedBy) return;
    this.buffer.push({
      ...entry,
      changedAt: entry.changedAt || new Date(),
    });

    if (this.buffer.length >= this.BATCH_SIZE) {
      void this.flush();
    }
  }

  /**
   * Enqueue multiple events at once (e.g. from client-side batched click tracking).
   */
  enqueueBatch(entries: ActivityLogInput[]) {
    const valid = entries.filter((e) => Boolean(e.changedBy));
    if (!valid.length) return;

    for (const entry of valid) {
      this.buffer.push({
        ...entry,
        changedAt: entry.changedAt || new Date(),
      });
    }

    if (this.buffer.length >= this.BATCH_SIZE) {
      void this.flush();
    }
  }

  /**
   * Flush pending entries to PostgreSQL.
   */
  async flush(): Promise<number> {
    if (this.buffer.length === 0) return 0;

    const toInsert = this.buffer.splice(0, this.BATCH_SIZE);
    try {
      await prisma.auditLog.createMany({
        data: toInsert.map((item) => ({
          tableName: item.tableName,
          recordId: item.recordId ? String(item.recordId).slice(0, 255) : 'unknown',
          employeeId: typeof item.employeeId === 'number' ? item.employeeId : null,
          fieldName: item.fieldName ? String(item.fieldName).slice(0, 255) : 'action',
          oldValue: item.oldValue ? String(item.oldValue).slice(0, 500) : null,
          newValue: item.newValue ? String(item.newValue).slice(0, 500) : null,
          changedBy: item.changedBy,
          changeReason: item.changeReason ? String(item.changeReason).slice(0, 500) : null,
          ipAddress: item.ipAddress ? String(item.ipAddress).slice(0, 64) : null,
          userAgent: item.userAgent ? String(item.userAgent).slice(0, 255) : null,
          changedAt: item.changedAt || new Date(),
        })),
        skipDuplicates: true,
      });
      return toInsert.length;
    } catch (err) {
      console.warn('[ActivityTrackerService.flush notice]:', err instanceof Error ? err.message : err);
      // In case of error, re-queue up to 50 items to avoid loss, drop rest to prevent memory leak
      if (toInsert.length > 0 && this.buffer.length < 500) {
        this.buffer.unshift(...toInsert.slice(0, 50));
      }
      return 0;
    }
  }
}

export const activityTracker = new ActivityTrackerService();
