import { prisma } from '../../config/prisma';
import { Prisma } from '@prisma/client';

function str(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length ? s : null;
}

function num(v: unknown): number | null {
  if (v == null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function dec(v: unknown): Prisma.Decimal | null {
  const n = num(v);
  return n == null ? null : new Prisma.Decimal(n);
}

function dateOnly(v: unknown): Date | null {
  const s = str(v);
  if (!s) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

type DocInput = {
  id?: string;
  typeCode?: string | null;
  name?: string;
  remarks?: string | null;
  fileUrl?: string;
  fileName?: string | null;
  mimeType?: string | null;
  fileSize?: number | null;
  sortOrder?: number;
};

function parseDocuments(raw: unknown): DocInput[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((row, i) => {
      const r = (row ?? {}) as Record<string, unknown>;
      const fileUrl = str(r.fileUrl);
      const name = str(r.name) ?? str(r.fileName) ?? 'Document';
      if (!fileUrl) return null;
      return {
        id: str(r.id) ?? undefined,
        typeCode: str(r.typeCode),
        name,
        remarks: str(r.remarks),
        fileUrl,
        fileName: str(r.fileName),
        mimeType: str(r.mimeType),
        fileSize: num(r.fileSize),
        sortOrder: num(r.sortOrder) ?? i,
      } satisfies DocInput;
    })
    .filter((d): d is DocInput => d != null);
}

function amenitiesCode(raw: unknown): string | null {
  if (Array.isArray(raw)) {
    const codes = raw.map((v) => str(v)).filter((v): v is string => Boolean(v));
    return codes.length ? codes.join(',') : null;
  }
  return str(raw);
}

function mapBody(body: Record<string, unknown>) {
  return {
    projectNo: num(body.projectNo),
    name: str(body.name),
    organizationId: str(body.organizationId),
    instituteId: str(body.instituteId),
    categoryCode: str(body.categoryCode),
    subCategoryCode: str(body.subCategoryCode),
    structureCode: str(body.structureCode),
    segmentCode: str(body.segmentCode),
    reraNo: str(body.reraNo),
    expectedCompletionDate: dateOnly(body.expectedCompletionDate),
    notes: str(body.notes),
    statusCode: str(body.statusCode) ?? 'ACTIVE',
    ownerEmployeeId: num(body.ownerEmployeeId),
    totalProjectArea: dec(body.totalProjectArea),
    areaUnitCode: str(body.areaUnitCode),
    estimatedCost: dec(body.estimatedCost),
    imageUrl: str(body.imageUrl),
    address: str(body.address),
    landmark: str(body.landmark),
    countryCode: str(body.countryCode),
    stateCode: str(body.stateCode),
    cityCode: str(body.cityCode),
    areaCode: str(body.areaCode),
    pincode: str(body.pincode),
    totalPlotArea: dec(body.totalPlotArea),
    amenitiesCode: amenitiesCode(body.amenitiesCodes ?? body.amenitiesCode),
    livabilityCode: str(body.livabilityCode),
    bankTieUpCode: str(body.bankTieUpCode),
    developmentAuthorityCode: str(body.developmentAuthorityCode),
    electricityProviderCode: str(body.electricityProviderCode),
    specNotes: str(body.specNotes),
  };
}

const include = {
  organization: { select: { id: true, code: true, name: true } },
  institute: { select: { id: true, code: true, name: true } },
  owner: {
    select: {
      id: true,
      generalInfo: { select: { fullName: true, designation: true } },
    },
  },
  documents: { orderBy: { sortOrder: 'asc' as const } },
  _count: { select: { towers: true, documents: true } },
};

export const projectService = {
  async nextNumber() {
    const agg = await prisma.erpProject.aggregate({ _max: { projectNo: true } });
    const next = (agg._max.projectNo ?? 0) + 1;
    return { projectNo: next, displayId: String(next).padStart(4, '0') };
  },

  async list(opts?: { includeInactive?: boolean }) {
    return prisma.erpProject.findMany({
      where: opts?.includeInactive ? undefined : { isActive: true },
      include,
      orderBy: { projectNo: 'desc' },
    });
  },

  async getById(id: string) {
    const row = await prisma.erpProject.findUnique({ where: { id }, include });
    if (!row) throw new Error('Project not found');
    return row;
  },

  async create(body: Record<string, unknown>, actorId: string) {
    const data = mapBody(body);
    if (!data.projectNo || data.projectNo < 1) throw new Error('Project ID is required');
    const existingNo = await prisma.erpProject.findUnique({
      where: { projectNo: data.projectNo },
    });
    if (existingNo) throw new Error('Project ID already exists');
    if (!data.name) throw new Error('Project name is required');
    if (!data.categoryCode) throw new Error('Project category is required');
    if (!data.subCategoryCode) throw new Error('Project sub category is required');
    if (!data.structureCode) throw new Error('Project structure is required');
    if (!data.reraNo) throw new Error('RERA No. is required');
    if (!data.expectedCompletionDate) throw new Error('Expected completion date is required');
    if (!data.statusCode) throw new Error('Status is required');
    if (!data.ownerEmployeeId) throw new Error('Project owner is required');
    if (!data.organizationId) throw new Error('Organization is required');
    if (!data.instituteId) throw new Error('Sub organization is required');
    if (!data.address) throw new Error('Address is required');
    if (!data.countryCode) throw new Error('Country is required');
    if (!data.stateCode) throw new Error('State is required');
    if (!data.cityCode) throw new Error('City is required');
    if (!data.areaCode) throw new Error('Area is required');
    if (!data.pincode) throw new Error('Pincode is required');
    if (!data.developmentAuthorityCode) throw new Error('Development authority is required');
    if (!data.electricityProviderCode) throw new Error('Electricity provider is required');

    const documents = parseDocuments(body.documents);

    return prisma.erpProject.create({
      data: {
        projectNo: data.projectNo,
        name: data.name,
        organizationId: data.organizationId,
        instituteId: data.instituteId,
        categoryCode: data.categoryCode,
        subCategoryCode: data.subCategoryCode,
        structureCode: data.structureCode,
        segmentCode: data.segmentCode,
        reraNo: data.reraNo,
        expectedCompletionDate: data.expectedCompletionDate,
        notes: data.notes,
        statusCode: data.statusCode,
        ownerEmployeeId: data.ownerEmployeeId,
        totalProjectArea: data.totalProjectArea,
        areaUnitCode: data.areaUnitCode,
        estimatedCost: data.estimatedCost,
        imageUrl: data.imageUrl,
        address: data.address,
        landmark: data.landmark,
        countryCode: data.countryCode,
        stateCode: data.stateCode,
        cityCode: data.cityCode,
        areaCode: data.areaCode,
        pincode: data.pincode,
        totalPlotArea: data.totalPlotArea,
        amenitiesCode: data.amenitiesCode,
        livabilityCode: data.livabilityCode,
        bankTieUpCode: data.bankTieUpCode,
        developmentAuthorityCode: data.developmentAuthorityCode,
        electricityProviderCode: data.electricityProviderCode,
        specNotes: data.specNotes,
        createdBy: actorId,
        updatedBy: actorId,
        documents: {
          create: documents.map((d, i) => ({
            typeCode: d.typeCode,
            name: d.name,
            remarks: d.remarks,
            fileUrl: d.fileUrl!,
            fileName: d.fileName,
            mimeType: d.mimeType,
            fileSize: d.fileSize,
            sortOrder: d.sortOrder ?? i,
          })),
        },
      },
      include,
    });
  },

  async update(id: string, body: Record<string, unknown>, actorId: string) {
    await this.getById(id);
    const data = mapBody(body);
    if (data.name === null) throw new Error('Project name is required');

    const documents = Array.isArray(body.documents) ? parseDocuments(body.documents) : null;

    return prisma.$transaction(async (tx) => {
      if (documents) {
        const keepIds = documents.map((d) => d.id).filter((x): x is string => Boolean(x));
        await tx.erpProjectDocument.deleteMany({
          where: {
            projectId: id,
            ...(keepIds.length ? { id: { notIn: keepIds } } : {}),
          },
        });
        for (const [i, d] of documents.entries()) {
          const payload = {
            typeCode: d.typeCode,
            name: d.name,
            remarks: d.remarks,
            fileUrl: d.fileUrl!,
            fileName: d.fileName,
            mimeType: d.mimeType,
            fileSize: d.fileSize,
            sortOrder: d.sortOrder ?? i,
          };
          if (d.id) {
            await tx.erpProjectDocument.update({
              where: { id: d.id },
              data: payload,
            });
          } else {
            await tx.erpProjectDocument.create({
              data: { ...payload, projectId: id },
            });
          }
        }
      }

      return tx.erpProject.update({
        where: { id },
        data: {
          ...(data.name != null ? { name: data.name } : {}),
          organizationId: data.organizationId,
          instituteId: data.instituteId,
          categoryCode: data.categoryCode,
          subCategoryCode: data.subCategoryCode,
          structureCode: data.structureCode,
          segmentCode: data.segmentCode,
          reraNo: data.reraNo,
          expectedCompletionDate: data.expectedCompletionDate,
          notes: data.notes,
          statusCode: data.statusCode,
          ownerEmployeeId: data.ownerEmployeeId,
          totalProjectArea: data.totalProjectArea,
          areaUnitCode: data.areaUnitCode,
          estimatedCost: data.estimatedCost,
          imageUrl: data.imageUrl,
          address: data.address,
          landmark: data.landmark,
          countryCode: data.countryCode,
          stateCode: data.stateCode,
          cityCode: data.cityCode,
          areaCode: data.areaCode,
          pincode: data.pincode,
          totalPlotArea: data.totalPlotArea,
          amenitiesCode: data.amenitiesCode,
          livabilityCode: data.livabilityCode,
          bankTieUpCode: data.bankTieUpCode,
          developmentAuthorityCode: data.developmentAuthorityCode,
          electricityProviderCode: data.electricityProviderCode,
          specNotes: data.specNotes,
          updatedBy: actorId,
        },
        include,
      });
    });
  },

  async remove(id: string) {
    await this.getById(id);
    await prisma.erpProject.delete({ where: { id } });
    return { id, deleted: true };
  },
};
