import { prisma } from '../../config/prisma';

export type OrgGrouping = 'DEPARTMENT_LEAD' | 'REPORTING_CHAIN';

export type OrgTreeNode = {
  id: string;
  kind: 'organization' | 'department' | 'lead' | 'group' | 'employee';
  title: string;
  subtitle?: string | null;
  employeeId?: number | null;
  role?: string | null;
  designation?: string | null;
  department?: string | null;
  photoUrl?: string | null;
  children: OrgTreeNode[];
};

type EmpRow = {
  id: number;
  photoUrl: string | null;
  status: string;
  fullName: string;
  department: string;
  designation: string;
  role: string | null;
  firstReportingId: number | null;
};

const LEAD_RE =
  /\b(head|lead|leader|manager|director|supervisor|vp|vice[\s-]?president|ceo|cto|cfo|coo|team[\s-]?lead|hod|hoi)\b/i;

function isLeadTitle(designation: string, role: string | null): boolean {
  return LEAD_RE.test(`${designation} ${role ?? ''}`);
}

function personNode(emp: EmpRow, kind: OrgTreeNode['kind'] = 'employee'): OrgTreeNode {
  return {
    id: `emp:${emp.id}`,
    kind,
    title: emp.fullName,
    subtitle: [emp.designation, emp.role].filter(Boolean).join(' · ') || null,
    employeeId: emp.id,
    role: emp.role,
    designation: emp.designation,
    department: emp.department,
    photoUrl: emp.photoUrl,
    children: [],
  };
}

async function loadEmployees(): Promise<EmpRow[]> {
  const rows = await prisma.employee.findMany({
    where: { status: 'ACTIVE' },
    select: {
      id: true,
      photoUrl: true,
      status: true,
      generalInfo: {
        select: {
          fullName: true,
          department: true,
          designation: true,
          firstReportingId: true,
        },
      },
      user: { select: { role: { select: { name: true } } } },
    },
    orderBy: { id: 'asc' },
  });

  return rows
    .filter((e) => e.generalInfo)
    .map((e) => ({
      id: e.id,
      photoUrl: e.photoUrl,
      status: e.status,
      fullName: e.generalInfo!.fullName,
      department: (e.generalInfo!.department || 'Unassigned').trim() || 'Unassigned',
      designation: e.generalInfo!.designation || '',
      role: e.user?.role?.name ?? null,
      firstReportingId: e.generalInfo!.firstReportingId,
    }));
}

async function departmentHodIds(): Promise<Map<string, number>> {
  const rows = await prisma.departmentApprover.findMany({
    where: { isActive: true },
    select: { department: true, hodEmployeeId: true },
  });
  const map = new Map<string, number>();
  for (const r of rows) {
    map.set(r.department.trim().toLowerCase(), r.hodEmployeeId);
  }
  return map;
}

export function buildDepartmentLeadTree(employees: EmpRow[], hodByDept: Map<string, number>): OrgTreeNode {
  const byId = new Map(employees.map((e) => [e.id, e]));
  const reporteesOf = new Map<number, EmpRow[]>();
  for (const e of employees) {
    const mgr = e.firstReportingId;
    if (mgr != null && byId.has(mgr)) {
      const list = reporteesOf.get(mgr) ?? [];
      list.push(e);
      reporteesOf.set(mgr, list);
    }
  }

  const deptNames = [...new Set(employees.map((e) => e.department))].sort((a, b) =>
    a.localeCompare(b),
  );

  const deptNodes: OrgTreeNode[] = [];
  for (const dept of deptNames) {
    const members = employees.filter((e) => e.department === dept);
    const hodId = hodByDept.get(dept.toLowerCase());
    const leadIds = new Set<number>();
    for (const e of members) {
      if (hodId === e.id) leadIds.add(e.id);
      if (isLeadTitle(e.designation, e.role)) leadIds.add(e.id);
      if ((reporteesOf.get(e.id) ?? []).some((r) => r.department === dept)) leadIds.add(e.id);
    }

    const assigned = new Set<number>();
    const leadNodes: OrgTreeNode[] = [];
    const leads = members.filter((e) => leadIds.has(e.id));
    leads.sort((a, b) => a.fullName.localeCompare(b.fullName));

    for (const lead of leads) {
      assigned.add(lead.id);
      const node = personNode(lead, 'lead');
      const kids = (reporteesOf.get(lead.id) ?? [])
        .filter((r) => r.department === dept && r.id !== lead.id)
        .sort((a, b) => a.fullName.localeCompare(b.fullName));
      for (const kid of kids) {
        assigned.add(kid.id);
        node.children.push(personNode(kid, 'employee'));
      }
      leadNodes.push(node);
    }

    const leftover = members
      .filter((e) => !assigned.has(e.id))
      .sort((a, b) => a.fullName.localeCompare(b.fullName))
      .map((e) => personNode(e, 'employee'));

    deptNodes.push({
      id: `dept:${dept}`,
      kind: 'department',
      title: dept,
      subtitle: `${members.length} ${members.length === 1 ? 'person' : 'people'}`,
      department: dept,
      children: [...leadNodes, ...leftover],
    });
  }

  return {
    id: 'org:root',
    kind: 'organization',
    title: 'Organization',
    subtitle: `${employees.length} people · ${deptNames.length} departments`,
    children: deptNodes,
  };
}

export function buildReportingChainTree(employees: EmpRow[]): OrgTreeNode {
  const byId = new Map(employees.map((e) => [e.id, e]));
  const childrenOf = new Map<number, EmpRow[]>();
  const roots: EmpRow[] = [];

  for (const e of employees) {
    const mgr = e.firstReportingId;
    if (mgr != null && byId.has(mgr) && mgr !== e.id) {
      const list = childrenOf.get(mgr) ?? [];
      list.push(e);
      childrenOf.set(mgr, list);
    } else {
      roots.push(e);
    }
  }

  const visiting = new Set<number>();
  function walk(emp: EmpRow): OrgTreeNode {
    if (visiting.has(emp.id)) return personNode(emp, 'employee');
    visiting.add(emp.id);
    const kids = (childrenOf.get(emp.id) ?? []).sort((a, b) => a.fullName.localeCompare(b.fullName));
    const isLead = kids.length > 0 || isLeadTitle(emp.designation, emp.role);
    const node = personNode(emp, isLead ? 'lead' : 'employee');
    node.children = kids.map(walk);
    visiting.delete(emp.id);
    return node;
  }

  roots.sort((a, b) => a.fullName.localeCompare(b.fullName));
  return {
    id: 'org:root',
    kind: 'organization',
    title: 'Reporting chain',
    subtitle: `${employees.length} people`,
    children: roots.map(walk),
  };
}

export async function generateSnapshot(grouping: OrgGrouping) {
  const [employees, hodByDept] = await Promise.all([loadEmployees(), departmentHodIds()]);
  const root =
    grouping === 'REPORTING_CHAIN'
      ? buildReportingChainTree(employees)
      : buildDepartmentLeadTree(employees, hodByDept);

  const count = (node: OrgTreeNode): { employees: number; leads: number; departments: number } => {
    const selfEmp = node.kind === 'employee' || node.kind === 'lead' ? 1 : 0;
    const selfLead = node.kind === 'lead' ? 1 : 0;
    const selfDept = node.kind === 'department' ? 1 : 0;
    return node.children.reduce(
      (acc, c) => {
        const n = count(c);
        return {
          employees: acc.employees + n.employees,
          leads: acc.leads + n.leads,
          departments: acc.departments + n.departments,
        };
      },
      { employees: selfEmp, leads: selfLead, departments: selfDept },
    );
  };

  const stats = count(root);
  return {
    grouping,
    generatedAt: new Date().toISOString(),
    stats: { ...stats, people: employees.length },
    root,
  };
}

/** Drop legacy "Other" buckets so people sit under their department. */
function flattenOtherGroups(node: OrgTreeNode): OrgTreeNode {
  const children = node.children.flatMap((child) => {
    const next = flattenOtherGroups(child);
    if (next.kind === 'group' && (next.title === 'Other' || next.id.includes(':other'))) {
      return next.children;
    }
    return [next];
  });
  return { ...node, children };
}

function overlayLivePhotos(node: OrgTreeNode, photos: Map<number, string | null>): OrgTreeNode {
  const live = node.employeeId != null ? photos.get(node.employeeId) : undefined;
  return {
    ...node,
    photoUrl: live !== undefined ? live : node.photoUrl,
    children: (node.children ?? []).map((child) => overlayLivePhotos(child, photos)),
  };
}

function normalizeSnapshot(snapshot: unknown): unknown {
  if (!snapshot || typeof snapshot !== 'object') return snapshot;
  const snap = snapshot as { root?: OrgTreeNode };
  if (!snap.root) return snapshot;
  return { ...snap, root: flattenOtherGroups(snap.root) };
}

async function withLivePhotos(snapshot: unknown): Promise<unknown> {
  const normalized = normalizeSnapshot(snapshot);
  if (!normalized || typeof normalized !== 'object') return normalized;
  const snap = normalized as { root?: OrgTreeNode };
  if (!snap.root) return normalized;
  const rows = await prisma.employee.findMany({ select: { id: true, photoUrl: true } });
  const photos = new Map(rows.map((e) => [e.id, e.photoUrl]));
  return { ...snap, root: overlayLivePhotos(snap.root, photos) };
}

async function serializeTree(tree: {
  id: string;
  name: string;
  description: string | null;
  grouping: string;
  isActive: boolean;
  snapshot: unknown;
  createdById: string;
  createdAt: Date;
  updatedAt: Date;
  createdBy?: { id: string; employee?: { generalInfo?: { fullName: string } | null } | null };
  contacts: Array<{
    id: string;
    moduleKey: string;
    moduleName: string;
    employeeId: number | null;
    note: string | null;
    sortOrder: number;
    employee?: {
      id: number;
      photoUrl: string | null;
      generalInfo?: { fullName: string; designation: string; department: string } | null;
    } | null;
  }>;
}) {
  return {
    id: tree.id,
    name: tree.name,
    description: tree.description,
    grouping: tree.grouping,
    isActive: tree.isActive,
    snapshot: await withLivePhotos(tree.snapshot),
    createdById: tree.createdById,
    createdByName: tree.createdBy?.employee?.generalInfo?.fullName ?? null,
    createdAt: tree.createdAt,
    updatedAt: tree.updatedAt,
    contacts: tree.contacts
      .slice()
      .sort((a, b) => a.sortOrder - b.sortOrder || a.moduleName.localeCompare(b.moduleName))
      .map((c) => ({
        id: c.id,
        moduleKey: c.moduleKey,
        moduleName: c.moduleName,
        employeeId: c.employeeId,
        note: c.note,
        sortOrder: c.sortOrder,
        employeeName: c.employee?.generalInfo?.fullName ?? null,
        designation: c.employee?.generalInfo?.designation ?? null,
        department: c.employee?.generalInfo?.department ?? null,
        photoUrl: c.employee?.photoUrl ?? null,
      })),
  };
}

const includeTree = {
  createdBy: { select: { id: true, employee: { select: { generalInfo: { select: { fullName: true } } } } } },
  contacts: {
    include: {
      employee: {
        select: {
          id: true,
          photoUrl: true,
          generalInfo: { select: { fullName: true, designation: true, department: true } },
        },
      },
    },
  },
} as const;

export const orgTreeService = {
  async list() {
    const trees = await prisma.orgTree.findMany({
      include: includeTree,
      orderBy: [{ isActive: 'desc' }, { updatedAt: 'desc' }],
    });
    return Promise.all(trees.map((tree) => serializeTree(tree)));
  },

  async getById(id: string) {
    const tree = await prisma.orgTree.findUnique({ where: { id }, include: includeTree });
    if (!tree) throw new Error('Org tree not found');
    return serializeTree(tree);
  },

  async getActive() {
    const tree = await prisma.orgTree.findFirst({
      where: { isActive: true },
      include: includeTree,
      orderBy: { updatedAt: 'desc' },
    });
    return tree ? serializeTree(tree) : null;
  },

  async preview(grouping: OrgGrouping) {
    return generateSnapshot(grouping);
  },

  async create(input: {
    name: string;
    description?: string | null;
    grouping: OrgGrouping;
    publish?: boolean;
    createdById: string;
  }) {
    const snapshot = await generateSnapshot(input.grouping);
    if (input.publish) {
      await prisma.orgTree.updateMany({ data: { isActive: false } });
    }
    const tree = await prisma.orgTree.create({
      data: {
        name: input.name.trim(),
        description: input.description?.trim() || null,
        grouping: input.grouping,
        isActive: Boolean(input.publish),
        snapshot,
        createdById: input.createdById,
      },
      include: includeTree,
    });
    return serializeTree(tree);
  },

  async regenerate(id: string, grouping?: OrgGrouping) {
    const existing = await prisma.orgTree.findUnique({ where: { id } });
    if (!existing) throw new Error('Org tree not found');
    const nextGrouping = grouping ?? (existing.grouping as OrgGrouping);
    const snapshot = await generateSnapshot(nextGrouping);
    const tree = await prisma.orgTree.update({
      where: { id },
      data: { grouping: nextGrouping, snapshot },
      include: includeTree,
    });
    return serializeTree(tree);
  },

  async update(
    id: string,
    input: { name?: string; description?: string | null; isActive?: boolean },
  ) {
    const existing = await prisma.orgTree.findUnique({ where: { id } });
    if (!existing) throw new Error('Org tree not found');
    if (input.isActive === true) {
      await prisma.orgTree.updateMany({ data: { isActive: false } });
    }
    const tree = await prisma.orgTree.update({
      where: { id },
      data: {
        ...(input.name != null ? { name: input.name.trim() } : {}),
        ...(input.description !== undefined ? { description: input.description?.trim() || null } : {}),
        ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
      },
      include: includeTree,
    });
    return serializeTree(tree);
  },

  async remove(id: string) {
    const existing = await prisma.orgTree.findUnique({ where: { id } });
    if (!existing) throw new Error('Org tree not found');
    await prisma.orgTree.delete({ where: { id } });
    return { id };
  },

  async setContacts(
    id: string,
    contacts: Array<{ moduleKey: string; moduleName: string; employeeId?: number | null; note?: string | null }>,
  ) {
    const existing = await prisma.orgTree.findUnique({ where: { id } });
    if (!existing) throw new Error('Org tree not found');

    await prisma.$transaction(async (tx) => {
      await tx.orgTreeContact.deleteMany({ where: { treeId: id } });
      if (contacts.length === 0) return;
      await tx.orgTreeContact.createMany({
        data: contacts.map((c, i) => ({
          treeId: id,
          moduleKey: c.moduleKey.trim(),
          moduleName: c.moduleName.trim(),
          employeeId: c.employeeId ?? null,
          note: c.note?.trim() || null,
          sortOrder: i,
        })),
      });
    });

    return this.getById(id);
  },
};
