import { prisma } from '../../config/prisma';

export const LOOKUP_CATEGORIES = [
  { key: 'ORGANIZATION', label: 'Organization', description: 'Employer organizations (e.g. Gandhinagar University)' },
  { key: 'BLOOD_GROUP', label: 'Blood Group', description: 'Blood groups on personal info' },
  { key: 'GENDER', label: 'Gender', description: 'Gender options' },
  { key: 'MARITAL_STATUS', label: 'Marital Status', description: 'Marital status options' },
  { key: 'NATIONALITY', label: 'Nationality', description: 'Nationality options' },
  { key: 'MOTHER_TONGUE', label: 'Mother Tongue', description: 'Mother tongue options' },
  { key: 'CASTE_CATEGORY', label: 'Caste Category', description: 'Cast / category options' },
  { key: 'EMPLOYEE_CATEGORY', label: 'Employee Category', description: 'Teaching / Non-teaching / …' },
  { key: 'APPOINTMENT_TYPE', label: 'Appointment Type', description: 'Full-time, contract, …' },
  { key: 'SHIFT', label: 'Shift', description: 'Work shifts' },
  { key: 'FAMILY_RELATION', label: 'Family Relation', description: 'Family member relations' },
  { key: 'DEGREE_TYPE', label: 'Degree Type', description: 'SSC, HSC, Bachelor, …' },
  { key: 'ACADEMIC_MEDIUM', label: 'Academic Medium', description: 'Medium of instruction' },
  { key: 'HSC_STREAM', label: 'HSC Stream', description: 'Science, Commerce, Arts' },
  { key: 'EXPERIENCE_TYPE', label: 'Experience Type', description: 'Teaching, Industry, …' },
  { key: 'BANK_NAME', label: 'Bank Name', description: 'Banks for salary accounts' },
  { key: 'RELIGION', label: 'Religion', description: 'Religion options' },
  { key: 'INTERVIEW_TYPE', label: 'Interview Type', description: 'HR Screen, Technical, Director, …' },
  { key: 'INTERVIEW_STATUS', label: 'Interview Status', description: 'Scheduled, Selected, Rejected, …' },
  { key: 'CANDIDATE_SOURCE', label: 'Candidate Source', description: 'Referral, Naukri, Walk-in, …' },
  { key: 'PROJECT_CATEGORY', label: 'Project Category', description: 'ERP project category' },
  { key: 'PROJECT_SUB_CATEGORY', label: 'Project Sub Category', description: 'ERP project sub category' },
  { key: 'PROJECT_STRUCTURE', label: 'Project Structure', description: 'ERP project structure' },
  { key: 'PROJECT_SEGMENT', label: 'Project Segment', description: 'ERP project segment' },
  { key: 'PROJECT_STATUS', label: 'Project Status', description: 'Active, On Hold, Completed, …' },
  { key: 'PROJECT_AREA_UNIT', label: 'Area Unit', description: 'Sq Ft, Sq M, Acre — used for project & plot area' },
  { key: 'PROJECT_COUNTRY', label: 'Country', description: 'Project location country' },
  { key: 'PROJECT_STATE', label: 'State', description: 'Project location state' },
  { key: 'PROJECT_CITY', label: 'City', description: 'Project location city' },
  { key: 'PROJECT_LOCATION_AREA', label: 'Location Area', description: 'Locality / area within the city' },
  { key: 'PROJECT_AMENITY', label: 'Amenities', description: 'Project amenities' },
  { key: 'PROJECT_LIVABILITY', label: 'Livability', description: 'Livability rating / category' },
  { key: 'PROJECT_BANK_TIE_UP', label: 'Bank Tie-Ups', description: 'Banks tied up for customer loans' },
  { key: 'PROJECT_DEV_AUTHORITY', label: 'Development Authority', description: 'Development authority' },
  { key: 'PROJECT_ELEC_PROVIDER', label: 'Electricity Provider', description: 'Electricity provider' },
  { key: 'PROJECT_DOCUMENT_TYPE', label: 'Project Document Type', description: 'Brochure, layout, approval, …' },
  { key: 'PROJECT_TOWER_STATUS', label: 'Tower Status', description: 'Active / On Hold / Completed for towers' },
  { key: 'PROJECT_UNIT_TYPE', label: 'Unit Type', description: '2BHK, 3BHK, Studio, Shop, …' },
  { key: 'PROJECT_UNIT_STATUS', label: 'Unit Status', description: 'Available, Booked, Sold, …' },
  { key: 'PROJECT_UNIT_FACING', label: 'Unit Facing', description: 'North, South, East, West, …' },
  { key: 'PROJECT_UNIT_CATEGORY', label: 'Unit Category', description: 'Standard, Corner, Premium, …' },
] as const;

export type LookupCategoryKey = (typeof LOOKUP_CATEGORIES)[number]['key'];

function normalizeCode(code: string): string {
  return code.trim().toUpperCase().replace(/\s+/g, '_').replace(/[^A-Z0-9_+-]/g, '');
}

export const lookupService = {
  listCategories() {
    return LOOKUP_CATEGORIES.map((c) => ({ ...c }));
  },

  async list(category?: string, opts?: { activeOnly?: boolean }) {
    return prisma.systemLookup.findMany({
      where: {
        ...(category ? { category: category.toUpperCase() } : {}),
        ...(opts?.activeOnly ? { isActive: true } : {}),
      },
      orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }, { label: 'asc' }],
    });
  },

  async listGrouped(opts?: { activeOnly?: boolean }) {
    const rows = await this.list(undefined, opts);
    const byCat: Record<string, typeof rows> = {};
    for (const row of rows) {
      (byCat[row.category] ??= []).push(row);
    }
    return LOOKUP_CATEGORIES.map((c) => ({
      ...c,
      options: byCat[c.key] ?? [],
    }));
  },

  async create(data: { category: string; code: string; label: string; sortOrder?: number }) {
    const category = data.category.trim().toUpperCase();
    if (!LOOKUP_CATEGORIES.some((c) => c.key === category)) {
      throw new Error(`Unknown lookup category: ${category}`);
    }
    const code = normalizeCode(data.code);
    const label = data.label.trim();
    if (!code || !label) throw new Error('Code and label are required');

    const clash = await prisma.systemLookup.findUnique({
      where: { category_code: { category, code } },
    });
    if (clash) throw new Error('An option with this code already exists in this category');

    return prisma.systemLookup.create({
      data: {
        category,
        code,
        label,
        sortOrder: data.sortOrder ?? 0,
      },
    });
  },

  async update(
    id: string,
    data: { code?: string; label?: string; isActive?: boolean; sortOrder?: number },
  ) {
    const current = await prisma.systemLookup.findUnique({ where: { id } });
    if (!current) throw new Error('Lookup option not found');

    const code = data.code !== undefined ? normalizeCode(data.code) : undefined;
    const label = data.label !== undefined ? data.label.trim() : undefined;
    if (code !== undefined && !code) throw new Error('Code cannot be empty');
    if (label !== undefined && !label) throw new Error('Label cannot be empty');

    if (code && code !== current.code) {
      const clash = await prisma.systemLookup.findUnique({
        where: { category_code: { category: current.category, code } },
      });
      if (clash) throw new Error('An option with this code already exists in this category');
    }

    return prisma.systemLookup.update({
      where: { id },
      data: {
        ...(code !== undefined ? { code } : {}),
        ...(label !== undefined ? { label } : {}),
        ...(data.isActive !== undefined ? { isActive: data.isActive } : {}),
        ...(data.sortOrder !== undefined ? { sortOrder: data.sortOrder } : {}),
      },
    });
  },

  async remove(id: string) {
    const current = await prisma.systemLookup.findUnique({ where: { id } });
    if (!current) throw new Error('Lookup option not found');
    await prisma.systemLookup.delete({ where: { id } });
    return { deleted: true, id };
  },
};
