import { prisma } from '../../config/prisma';

function str(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length ? s : null;
}

function sortIdx(v: unknown, fallback: number): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

export const activityService = {
  async list(opts?: { includeInactive?: boolean }) {
    const includeInactive = opts?.includeInactive === true;
    return prisma.erpActivity.findMany({
      where: includeInactive ? undefined : { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      include: {
        subtasks: {
          where: includeInactive ? undefined : { isActive: true },
          orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
        },
      },
    });
  },

  async adminList() {
    return prisma.erpActivity.findMany({
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      include: {
        subtasks: { orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }] },
      },
    });
  },

  async getById(id: string) {
    const row = await prisma.erpActivity.findUnique({
      where: { id },
      include: {
        subtasks: { orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }] },
      },
    });
    if (!row) throw new Error('Activity not found');
    return row;
  },

  async create(body: Record<string, unknown>) {
    const name = str(body.name);
    if (!name) throw new Error('Activity name is required');
    const subtasks = Array.isArray(body.subtasks) ? body.subtasks : [];
    return prisma.erpActivity.create({
      data: {
        name,
        isActive: body.isActive !== false,
        sortOrder: Number(body.sortOrder) || 0,
        subtasks: {
          create: subtasks
            .map((s, i) => {
              const r = (s ?? {}) as Record<string, unknown>;
              const n = str(r.name);
              if (!n) return null;
              return {
                name: n,
                description: str(r.description),
                isActive: r.isActive !== false,
                sortOrder: sortIdx(r.sortOrder, i),
              };
            })
            .filter(Boolean) as { name: string; description: string | null; isActive: boolean; sortOrder: number }[],
        },
      },
      include: { subtasks: true },
    });
  },

  async update(id: string, body: Record<string, unknown>) {
    await this.getById(id);
    const data: Record<string, unknown> = {};
    if (body.name != null) data.name = str(body.name);
    if (body.isActive != null) data.isActive = Boolean(body.isActive);
    if (body.sortOrder != null) data.sortOrder = Number(body.sortOrder) || 0;

    if (Array.isArray(body.subtasks)) {
      await prisma.erpActivitySubtask.deleteMany({ where: { activityId: id } });
      await prisma.erpActivitySubtask.createMany({
        data: body.subtasks
          .map((s, i) => {
            const r = (s ?? {}) as Record<string, unknown>;
            const n = str(r.name);
            if (!n) return null;
            return {
              activityId: id,
              name: n,
              description: str(r.description),
              isActive: r.isActive !== false,
              sortOrder: sortIdx(r.sortOrder, i),
            };
          })
          .filter(Boolean) as {
          activityId: string;
          name: string;
          description: string | null;
          isActive: boolean;
          sortOrder: number;
        }[],
      });
    }

    return prisma.erpActivity.update({
      where: { id },
      data,
      include: { subtasks: { orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }] } },
    });
  },

  async toggleActive(id: string) {
    const row = await this.getById(id);
    return prisma.erpActivity.update({
      where: { id },
      data: { isActive: !row.isActive },
      include: { subtasks: true },
    });
  },

  async remove(id: string) {
    await this.getById(id);
    await prisma.erpActivity.delete({ where: { id } });
    return { ok: true };
  },
};
