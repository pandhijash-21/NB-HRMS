import { prisma } from '../../config/prisma';

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

const includeDetail = {
  locations: { orderBy: [{ sortOrder: 'asc' as const }] },
  contacts: { orderBy: [{ sortOrder: 'asc' as const }] },
  documents: { orderBy: [{ sortOrder: 'asc' as const }] },
};

type LocInput = {
  locationName?: string | null;
  addressTypeCode?: string | null;
  countryCode?: string | null;
  stateCode?: string | null;
  cityCode?: string | null;
  address1?: string | null;
  address2?: string | null;
  postCode?: string | null;
  panNo?: string | null;
  gstNo?: string | null;
  sortOrder?: number;
};

type ContactInput = {
  name: string;
  email?: string | null;
  countryCode?: string | null;
  mobileNo?: string | null;
  altCountryCode?: string | null;
  alternateMobileNo?: string | null;
  designation?: string | null;
  locationName?: string | null;
  sortOrder?: number;
};

type DocInput = {
  typeCode?: string | null;
  name?: string | null;
  remarks?: string | null;
  fileUrl?: string | null;
  fileName?: string | null;
  mimeType?: string | null;
  fileSize?: number | null;
  sortOrder?: number;
};

function parseLocations(raw: unknown): LocInput[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((r, i) => {
    const row = (r ?? {}) as Record<string, unknown>;
    return {
      locationName: str(row.locationName),
      addressTypeCode: str(row.addressTypeCode),
      countryCode: str(row.countryCode),
      stateCode: str(row.stateCode),
      cityCode: str(row.cityCode),
      address1: str(row.address1),
      address2: str(row.address2),
      postCode: str(row.postCode),
      panNo: str(row.panNo),
      gstNo: str(row.gstNo),
      sortOrder: num(row.sortOrder) ?? i,
    };
  });
}

function parseContacts(raw: unknown): ContactInput[] {
  if (!Array.isArray(raw)) return [];
  const out: ContactInput[] = [];
  for (let i = 0; i < raw.length; i++) {
    const row = (raw[i] ?? {}) as Record<string, unknown>;
    const name = str(row.name);
    if (!name) continue;
    out.push({
      name,
      email: str(row.email),
      countryCode: str(row.countryCode) ?? '+91',
      mobileNo: str(row.mobileNo),
      altCountryCode: str(row.altCountryCode) ?? '+91',
      alternateMobileNo: str(row.alternateMobileNo),
      designation: str(row.designation),
      locationName: str(row.locationName),
      sortOrder: num(row.sortOrder) ?? i,
    });
  }
  return out;
}

function parseDocuments(raw: unknown): DocInput[] {
  if (!Array.isArray(raw)) return [];
  return raw.map((r, i) => {
    const row = (r ?? {}) as Record<string, unknown>;
    return {
      typeCode: str(row.typeCode),
      name: str(row.name),
      remarks: str(row.remarks),
      fileUrl: str(row.fileUrl),
      fileName: str(row.fileName),
      mimeType: str(row.mimeType),
      fileSize: num(row.fileSize),
      sortOrder: num(row.sortOrder) ?? i,
    };
  });
}

async function replaceChildren(
  contractorId: string,
  locations: LocInput[],
  contacts: ContactInput[],
  documents: DocInput[],
) {
  await prisma.$transaction([
    prisma.erpContractorLocation.deleteMany({ where: { contractorId } }),
    prisma.erpContractorContact.deleteMany({ where: { contractorId } }),
    prisma.erpContractorDocument.deleteMany({ where: { contractorId } }),
  ]);

  if (locations.length) {
    await prisma.erpContractorLocation.createMany({
      data: locations.map((l, i) => ({
        contractorId,
        locationName: l.locationName,
        addressTypeCode: l.addressTypeCode,
        countryCode: l.countryCode,
        stateCode: l.stateCode,
        cityCode: l.cityCode,
        address1: l.address1,
        address2: l.address2,
        postCode: l.postCode,
        panNo: l.panNo,
        gstNo: l.gstNo,
        sortOrder: l.sortOrder ?? i,
      })),
    });
  }
  if (contacts.length) {
    await prisma.erpContractorContact.createMany({
      data: contacts.map((c, i) => ({
        contractorId,
        name: c.name,
        email: c.email,
        countryCode: c.countryCode,
        mobileNo: c.mobileNo,
        altCountryCode: c.altCountryCode,
        alternateMobileNo: c.alternateMobileNo,
        designation: c.designation,
        locationName: c.locationName,
        sortOrder: c.sortOrder ?? i,
      })),
    });
  }
  if (documents.length) {
    await prisma.erpContractorDocument.createMany({
      data: documents.map((d, i) => ({
        contractorId,
        typeCode: d.typeCode,
        name: d.name,
        remarks: d.remarks,
        fileUrl: d.fileUrl,
        fileName: d.fileName,
        mimeType: d.mimeType,
        fileSize: d.fileSize ?? undefined,
        sortOrder: d.sortOrder ?? i,
      })),
    });
  }
}

function headerFromBody(body: Record<string, unknown>) {
  const name = str(body.name) ?? str(body.companyName);
  if (!name) throw new Error('Company Name is required');
  const mobileNo = str(body.mobileNo) ?? str(body.phone);
  const email = str(body.email);
  if (!mobileNo) throw new Error('Mobile No is required');
  if (!email) throw new Error('Email is required');

  const contacts = parseContacts(body.contacts);
  const primaryContact = contacts[0];

  return {
    name,
    mobileNo,
    email,
    alternateMobileNo: str(body.alternateMobileNo),
    tdsCode: str(body.tdsCode),
    bankName: str(body.bankName),
    branchName: str(body.branchName),
    ifscCode: str(body.ifscCode),
    accountNo: str(body.accountNo),
    paymentTerms: str(body.paymentTerms),
    contractorTypeCode: str(body.contractorTypeCode),
    isActive: body.isActive !== false,
    // Legacy fields kept in sync for work-order lists
    phone: mobileNo,
    contactPerson: primaryContact?.name ?? str(body.contactPerson),
  };
}

export const contractorService = {
  async list(opts?: { includeInactive?: boolean }) {
    const includeInactive = opts?.includeInactive === true;
    return prisma.erpContractor.findMany({
      where: includeInactive ? undefined : { isActive: true },
      orderBy: { name: 'asc' },
      include: {
        _count: { select: { locations: true, contacts: true, documents: true } },
      },
    });
  },

  async getById(id: string) {
    const row = await prisma.erpContractor.findUnique({
      where: { id },
      include: includeDetail,
    });
    if (!row) throw new Error('Contractor not found');
    return row;
  },

  async create(body: Record<string, unknown>) {
    const header = headerFromBody(body);
    const locations = parseLocations(body.locations);
    const contacts = parseContacts(body.contacts);
    const documents = parseDocuments(body.documents);

    const created = await prisma.erpContractor.create({ data: header });
    await replaceChildren(created.id, locations, contacts, documents);
    return this.getById(created.id);
  },

  async update(id: string, body: Record<string, unknown>) {
    await this.getById(id);
    const header = headerFromBody(body);
    await prisma.erpContractor.update({ where: { id }, data: header });
    if (body.locations != null || body.contacts != null || body.documents != null) {
      await replaceChildren(
        id,
        parseLocations(body.locations),
        parseContacts(body.contacts),
        parseDocuments(body.documents),
      );
    }
    return this.getById(id);
  },

  async toggleActive(id: string) {
    const row = await this.getById(id);
    return prisma.erpContractor.update({
      where: { id },
      data: { isActive: !row.isActive },
      include: includeDetail,
    });
  },

  async remove(id: string) {
    await this.getById(id);
    await prisma.erpContractor.delete({ where: { id } });
    return { ok: true };
  },
};
