import { prisma } from '../../config/prisma';

function str(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length ? s : null;
}

export const contractorService = {
  async list(opts?: { includeInactive?: boolean }) {
    const includeInactive = opts?.includeInactive === true;
    return prisma.erpContractor.findMany({
      where: includeInactive ? undefined : { isActive: true },
      orderBy: { name: 'asc' },
    });
  },

  async getById(id: string) {
    const row = await prisma.erpContractor.findUnique({ where: { id } });
    if (!row) throw new Error('Contractor not found');
    return row;
  },

  async create(body: Record<string, unknown>) {
    const name = str(body.name);
    if (!name) throw new Error('Contractor name is required');
    return prisma.erpContractor.create({
      data: {
        name,
        contactPerson: str(body.contactPerson),
        phone: str(body.phone),
        email: str(body.email),
        isActive: body.isActive !== false,
      },
    });
  },

  async update(id: string, body: Record<string, unknown>) {
    await this.getById(id);
    return prisma.erpContractor.update({
      where: { id },
      data: {
        ...(body.name != null ? { name: str(body.name) ?? undefined } : {}),
        ...(body.contactPerson != null ? { contactPerson: str(body.contactPerson) } : {}),
        ...(body.phone != null ? { phone: str(body.phone) } : {}),
        ...(body.email != null ? { email: str(body.email) } : {}),
        ...(body.isActive != null ? { isActive: Boolean(body.isActive) } : {}),
      },
    });
  },

  async toggleActive(id: string) {
    const row = await this.getById(id);
    return prisma.erpContractor.update({
      where: { id },
      data: { isActive: !row.isActive },
    });
  },

  async remove(id: string) {
    await this.getById(id);
    await prisma.erpContractor.delete({ where: { id } });
    return { ok: true };
  },
};
