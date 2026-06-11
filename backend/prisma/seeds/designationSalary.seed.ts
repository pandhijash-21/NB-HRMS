import { PrismaClient, PayCommissionType, SalaryColumnCategory } from '@prisma/client';

function slugify(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
}

const REGULAR_DESIGNATIONS = [
  'Principal/Director',
  'Professor',
  'Associate Professor',
  'Assistant Professor',
  'Lecturer',
  'Teaching Assistant',
  'Librarian',
  'Assistant Librarian',
  'Administrative Officer',
  'Office Superintendent',
  'Account Officer',
  'Head Clers',
  'Senior Clerk/Senior Assistant',
  'Junior Clerk/Junior Assistant',
  'Laboratory Technician',
  'Laboratory Assistant',
  'Laboratory Attendant',
  'Telecaller',
  'Electrician',
  'AC Technician',
  'Peon',
  'Sweeper',
  'Gardner',
] as const;

const ALIAS_DESIGNATIONS: { name: string; roleName: string }[] = [
  { name: 'Head of Institute', roleName: 'HOI' },
  { name: 'Vice Chancellor', roleName: 'VC' },
  { name: 'Registrar', roleName: 'REGISTRAR' },
  { name: 'HR Manager', roleName: 'HR_MANAGER' },
  { name: 'Head of Department', roleName: 'HOD' },
];

type ColDef = {
  columnIdentifier: string;
  displayName: string;
  category: SalaryColumnCategory;
  evaluationOrder: number;
  isRuleConfigurable?: boolean;
};

const FIFTH_PAY_COLUMNS: ColDef[] = [
  { columnIdentifier: 'basic', displayName: 'Basic', category: 'EARNING', evaluationOrder: 10 },
  { columnIdentifier: 'dearness_pay', displayName: 'Dearness Pay', category: 'EARNING', evaluationOrder: 20 },
  { columnIdentifier: 'new_basic', displayName: 'New Basic', category: 'EARNING', evaluationOrder: 30 },
  { columnIdentifier: 'dearness_allowance', displayName: 'Dearness Allowance', category: 'EARNING', evaluationOrder: 40 },
  { columnIdentifier: 'house_rent_allowance', displayName: 'House Rent Allowance', category: 'EARNING', evaluationOrder: 50 },
  { columnIdentifier: 'city_compensatory_allowance', displayName: 'City Compensatory Allowance', category: 'EARNING', evaluationOrder: 60 },
  { columnIdentifier: 'medical_allowance', displayName: 'Medical Allowance', category: 'EARNING', evaluationOrder: 70 },
  { columnIdentifier: 'travel_allowance', displayName: 'Travel Allowance', category: 'EARNING', evaluationOrder: 80 },
  { columnIdentifier: 'gratuity', displayName: 'Gratuity', category: 'EARNING', evaluationOrder: 90 },
  { columnIdentifier: 'provident_fund', displayName: 'Provident Fund', category: 'EARNING', evaluationOrder: 100 },
  { columnIdentifier: 'gross_pay', displayName: 'Gross Pay', category: 'EARNING', evaluationOrder: 110 },
  { columnIdentifier: 'provident_fund', displayName: 'Provident Fund', category: 'DEDUCTION', evaluationOrder: 200 },
  { columnIdentifier: 'professional_tax', displayName: 'Professional Tax', category: 'DEDUCTION', evaluationOrder: 210 },
  { columnIdentifier: 'gratuity', displayName: 'Gratuity', category: 'DEDUCTION', evaluationOrder: 220 },
  { columnIdentifier: 'tax_deducted_at_source', displayName: 'Tax Deducted at Source', category: 'DEDUCTION', evaluationOrder: 230 },
  { columnIdentifier: 'other_deductions', displayName: 'Other Deductions', category: 'DEDUCTION', evaluationOrder: 240 },
  { columnIdentifier: 'total_deductions', displayName: 'Total Deductions', category: 'DEDUCTION', evaluationOrder: 245 },
  { columnIdentifier: 'net_pay', displayName: 'Net Pay', category: 'DEDUCTION', evaluationOrder: 250 },
];

const SIXTH_PAY_COLUMNS: ColDef[] = [
  { columnIdentifier: 'basic', displayName: 'Basic', category: 'EARNING', evaluationOrder: 10 },
  { columnIdentifier: 'academic_grade_pay', displayName: 'Academic Grade Pay', category: 'EARNING', evaluationOrder: 20 },
  { columnIdentifier: 'new_basic', displayName: 'New Basic', category: 'EARNING', evaluationOrder: 30 },
  { columnIdentifier: 'dearness_allowance', displayName: 'Dearness Allowance', category: 'EARNING', evaluationOrder: 40 },
  { columnIdentifier: 'house_rent_allowance', displayName: 'House Rent Allowance', category: 'EARNING', evaluationOrder: 50 },
  { columnIdentifier: 'city_compensatory_allowance', displayName: 'City Compensatory Allowance', category: 'EARNING', evaluationOrder: 60 },
  { columnIdentifier: 'medical_allowance', displayName: 'Medical Allowance', category: 'EARNING', evaluationOrder: 70 },
  { columnIdentifier: 'travel_allowance', displayName: 'Travel Allowance', category: 'EARNING', evaluationOrder: 80 },
  { columnIdentifier: 'special_allowance', displayName: 'Special Allowance', category: 'EARNING', evaluationOrder: 90 },
  { columnIdentifier: 'other_allowance', displayName: 'Other Allowance', category: 'EARNING', evaluationOrder: 100 },
  { columnIdentifier: 'gratuity', displayName: 'Gratuity', category: 'EARNING', evaluationOrder: 110 },
  { columnIdentifier: 'provident_fund', displayName: 'Provident Fund', category: 'EARNING', evaluationOrder: 120 },
  { columnIdentifier: 'gross_pay', displayName: 'Gross Pay', category: 'EARNING', evaluationOrder: 130 },
  { columnIdentifier: 'gratuity', displayName: 'Gratuity', category: 'DEDUCTION', evaluationOrder: 200 },
  { columnIdentifier: 'provident_fund', displayName: 'Provident Fund', category: 'DEDUCTION', evaluationOrder: 210 },
  { columnIdentifier: 'professional_tax', displayName: 'Professional Tax', category: 'DEDUCTION', evaluationOrder: 220 },
  { columnIdentifier: 'tax_deducted_at_source', displayName: 'Tax Deducted at Source', category: 'DEDUCTION', evaluationOrder: 230 },
  { columnIdentifier: 'tax_deducted_at_source_against_proof', displayName: 'Tax Deducted at Source Against Proof', category: 'DEDUCTION', evaluationOrder: 240 },
  { columnIdentifier: 'other_deductions', displayName: 'Other Deductions', category: 'DEDUCTION', evaluationOrder: 250 },
  { columnIdentifier: 'total_deductions', displayName: 'Total Deductions', category: 'DEDUCTION', evaluationOrder: 255 },
  { columnIdentifier: 'net_pay', displayName: 'Net Pay', category: 'DEDUCTION', evaluationOrder: 260 },
];

async function seedColumnDefinitions(
  prisma: PrismaClient,
  payCommissionId: string,
  columns: ColDef[],
) {
  for (const col of columns) {
    await prisma.salaryColumnDefinition.upsert({
      where: {
        payCommissionId_columnIdentifier_category: {
          payCommissionId,
          columnIdentifier: col.columnIdentifier,
          category: col.category,
        },
      },
      update: {
        displayName: col.displayName,
        evaluationOrder: col.evaluationOrder,
        isRuleConfigurable: col.isRuleConfigurable ?? true,
      },
      create: {
        payCommissionId,
        columnIdentifier: col.columnIdentifier,
        displayName: col.displayName,
        category: col.category,
        evaluationOrder: col.evaluationOrder,
        isRuleConfigurable: col.isRuleConfigurable ?? true,
      },
    });
  }
}

export async function seedDesignationsAndSalaryCatalog(
  prisma: PrismaClient,
  roleIdMap: Record<string, string>,
) {
  console.log('⏳  Seeding designations…');
  let sortOrder = 0;
  const designationByName = new Map<string, string>();

  for (const name of REGULAR_DESIGNATIONS) {
    const d = await prisma.designation.upsert({
      where: { name },
      update: { sortOrder: sortOrder++, isAlias: false },
      create: {
        name,
        slug: slugify(name),
        isAlias: false,
        sortOrder: sortOrder++,
      },
    });
    designationByName.set(name, d.id);
  }

  for (const alias of ALIAS_DESIGNATIONS) {
    const d = await prisma.designation.upsert({
      where: { name: alias.name },
      update: {
        isAlias: true,
        linkedRoleId: roleIdMap[alias.roleName],
      },
      create: {
        name: alias.name,
        slug: slugify(alias.name),
        isAlias: true,
        linkedRoleId: roleIdMap[alias.roleName],
        sortOrder: sortOrder++,
      },
    });
    designationByName.set(alias.name, d.id);
  }
  console.log(`✅  ${designationByName.size} designations seeded`);

  console.log('⏳  Backfilling designation_id on employees…');
  const generalInfos = await prisma.employeeGeneralInfo.findMany({
    select: { id: true, designation: true, designationId: true },
  });
  for (const info of generalInfos) {
    if (info.designationId) continue;
    const exact = designationByName.get(info.designation);
    if (exact) {
      await prisma.employeeGeneralInfo.update({
        where: { id: info.id },
        data: { designationId: exact },
      });
      continue;
    }
    const fuzzy = await prisma.designation.findFirst({
      where: { name: { contains: info.designation, mode: 'insensitive' }, isAlias: false },
    });
    if (fuzzy) {
      await prisma.employeeGeneralInfo.update({
        where: { id: info.id },
        data: { designationId: fuzzy.id },
      });
    }
  }

  const assignments = await prisma.employeeAssignment.findMany({
    select: { id: true, designation: true, designationId: true },
  });
  for (const a of assignments) {
    if (a.designationId) continue;
    const exact = designationByName.get(a.designation);
    const designationId = exact ?? (await prisma.designation.findFirst({
      where: { name: { contains: a.designation, mode: 'insensitive' }, isAlias: false },
    }))?.id;
    if (designationId) {
      await prisma.employeeAssignment.update({
        where: { id: a.id },
        data: { designationId },
      });
    }
  }
  console.log('✅  designation_id backfill complete');

  console.log('⏳  Seeding pay commissions…');
  const fifth = await prisma.payCommission.upsert({
    where: { commissionType: PayCommissionType.FIFTH },
    update: { name: '5th Pay Commission' },
    create: { commissionType: PayCommissionType.FIFTH, name: '5th Pay Commission' },
  });
  const sixth = await prisma.payCommission.upsert({
    where: { commissionType: PayCommissionType.SIXTH },
    update: { name: '6th Pay Commission' },
    create: { commissionType: PayCommissionType.SIXTH, name: '6th Pay Commission' },
  });
  console.log('✅  Pay commissions seeded');

  console.log('⏳  Seeding salary column definitions…');
  await seedColumnDefinitions(prisma, fifth.id, FIFTH_PAY_COLUMNS);
  await seedColumnDefinitions(prisma, sixth.id, SIXTH_PAY_COLUMNS);
  console.log('✅  Salary column catalog seeded');

  const salaryInfos = await prisma.employeeSalaryInfo.findMany();
  for (const s of salaryInfos) {
    const updates: { payCommissionType?: PayCommissionType; designationId?: string } = {};
    if (!s.payCommissionType && s.payCommission) {
      const pc = s.payCommission.toLowerCase();
      if (pc.includes('6')) updates.payCommissionType = PayCommissionType.SIXTH;
      else if (pc.includes('5')) updates.payCommissionType = PayCommissionType.FIFTH;
    }
    if (!s.designationId) {
      const emp = await prisma.employeeGeneralInfo.findUnique({
        where: { employeeId: s.employeeId },
        select: { designationId: true },
      });
      if (emp?.designationId) updates.designationId = emp.designationId;
    }
    if (Object.keys(updates).length > 0) {
      await prisma.employeeSalaryInfo.update({ where: { id: s.id }, data: updates });
    }
  }
}
