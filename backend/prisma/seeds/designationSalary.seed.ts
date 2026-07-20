import { PrismaClient, SalaryColumnCategory } from '@prisma/client';

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
  { name: 'Staff', roleName: 'EMPLOYEE' },
  { name: 'Head of Institute', roleName: 'HOI' },
  { name: 'Vice Chancellor', roleName: 'VC' },
  { name: 'Registrar', roleName: 'REGISTRAR' },
  { name: 'HR Manager', roleName: 'HR_MANAGER' },
  { name: 'HR Staff', roleName: 'HR' },
  { name: 'Head of Department', roleName: 'HOD' },
  { name: 'Finance Officer', roleName: 'FINANCE' },
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
  { columnIdentifier: 'reimbursement', displayName: 'Reimbursement', category: 'EARNING', evaluationOrder: 105 },
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

export async function seedSalaryCatalog(prisma: PrismaClient) {
  console.log('⏳  Seeding pay commissions…');
  const fifth = await prisma.payCommission.upsert({
    where: { code: 'FIFTH' },
    update: { name: '5th Pay Commission', sortOrder: 10 },
    create: {
      code: 'FIFTH',
      name: '5th Pay Commission',
      description: 'Fifth pay commission salary structure',
      sortOrder: 10,
      ruleEditorEnabled: true,
    },
  });
  const sixth = await prisma.payCommission.upsert({
    where: { code: 'SIXTH' },
    update: { name: '6th Pay Commission', sortOrder: 20 },
    create: {
      code: 'SIXTH',
      name: '6th Pay Commission',
      description: 'Sixth pay commission salary structure',
      sortOrder: 20,
      ruleEditorEnabled: true,
    },
  });
  console.log('✅  Pay commissions seeded');

  console.log('⏳  Seeding salary column definitions…');
  await seedColumnDefinitions(prisma, fifth.id, FIFTH_PAY_COLUMNS);
  await seedColumnDefinitions(prisma, sixth.id, SIXTH_PAY_COLUMNS);
  console.log('✅  Salary column catalog seeded');
}

/** @deprecated Prefer seedSalaryCatalog — designations/positions are configured in-app. */
export async function seedDesignationsAndSalaryCatalog(
  prisma: PrismaClient,
  _roleIdMap: Record<string, string>,
) {
  await seedSalaryCatalog(prisma);
}
