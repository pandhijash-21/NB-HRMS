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

/** Seed company roles and designations */
export async function seedCompanyRolesAndDesignations(prisma: PrismaClient) {
  console.log('⏳  Seeding company roles…');
  const roleMap = new Map<string, string>();
  for (const name of COMPANY_ROLES) {
    const role = await prisma.role.upsert({
      where: { name },
      update: { isActive: true },
      create: {
        name,
        description: `${name} company role`,
        isSystem: false,
        isActive: true,
      },
    });
    roleMap.set(name, role.id);
  }
  console.log(`✅  ${COMPANY_ROLES.length} company roles seeded`);

  console.log('⏳  Seeding designations…');
  let sort = 1;
  for (const d of COMPANY_DESIGNATIONS) {
    const linkedRoleId = roleMap.get(d.linkedRole) || null;
    await prisma.designation.upsert({
      where: { name: d.name },
      update: {
        slug: d.slug,
        linkedRoleId,
        isActive: true,
        sortOrder: sort++,
      },
      create: {
        name: d.name,
        slug: d.slug,
        linkedRoleId,
        isActive: true,
        sortOrder: sort++,
      },
    });
  }
  console.log(`✅  ${COMPANY_DESIGNATIONS.length} designations seeded`);
}

export const COMPANY_ROLES = [
  'Accountant',
  'Admin Sales',
  'BDM',
  'CEO',
  'Closing Manager',
  'Data Analytics',
  'Digital Marketing',
  'Director',
  'Driver',
  'HR & Admin',
  'Housekeeping',
  'IT Intern',
  'Land Co-ordinator',
  'Legal Co-ordinator',
  'Loan Executive',
  'Loan Manager',
  'Marketing & Operation',
  'Marketing Consultant',
  'Marketing Manager',
  'PA to Chairman',
  'Pantry',
  'Pantry & Field',
  'Project Co-ordinator',
  'Purchase',
  'Reception',
  'Rental Executive',
  'Sales Associate',
  'Sales Co-ordinator',
  'Sales Executive',
  'Sales Manager',
  'Sales Operations',
  'Site Supervision',
  'Social Media Marketing Executive',
  'Store',
  'Tax & Finance Executive',
  'Telecalling',
];

export const COMPANY_DESIGNATIONS = [
  { name: 'Accountant', slug: 'accountant', linkedRole: 'Accountant' },
  { name: 'Admin Executive', slug: 'admin_executive', linkedRole: 'Admin Sales' },
  { name: 'Asst. Purchase Manager', slug: 'asst_purchase_manager', linkedRole: 'Purchase' },
  { name: 'Billing Engineer', slug: 'billing_engineer', linkedRole: 'Project Co-ordinator' },
  { name: 'CEO', slug: 'ceo', linkedRole: 'CEO' },
  { name: 'Closing Manager', slug: 'closing_manager', linkedRole: 'Closing Manager' },
  { name: 'Data Analytics', slug: 'data_analytics', linkedRole: 'Data Analytics' },
  { name: 'Digital Marketing Executive', slug: 'digital_marketing_executive', linkedRole: 'Digital Marketing' },
  { name: 'Director', slug: 'director', linkedRole: 'Director' },
  { name: 'Driver', slug: 'driver', linkedRole: 'Driver' },
  { name: 'Field Executive', slug: 'field_executive', linkedRole: 'Pantry & Field' },
  { name: 'HK Boy', slug: 'hk_boy', linkedRole: 'Housekeeping' },
  { name: 'HOD - BDM', slug: 'hod_bdm', linkedRole: 'BDM' },
  { name: 'HR Head', slug: 'hr_head', linkedRole: 'HR & Admin' },
  { name: 'IT Intern', slug: 'it_intern', linkedRole: 'IT Intern' },
  { name: 'Legal Co-ordinator', slug: 'legal_coordinator', linkedRole: 'Legal Co-ordinator' },
  { name: 'Loan Executive', slug: 'loan_executive', linkedRole: 'Loan Executive' },
  { name: 'Loan Manager', slug: 'loan_manager', linkedRole: 'Loan Manager' },
  { name: 'Marketing & Operation Head', slug: 'marketing_operation_head', linkedRole: 'Marketing & Operation' },
  { name: 'Marketing Consultant', slug: 'marketing_consultant', linkedRole: 'Marketing Consultant' },
  { name: 'Marketing Manager', slug: 'marketing_manager', linkedRole: 'Marketing Manager' },
  { name: 'PA to Chairman', slug: 'pa_to_chairman', linkedRole: 'PA to Chairman' },
  { name: 'Pantry Boy', slug: 'pantry_boy', linkedRole: 'Pantry' },
  { name: 'Project Head', slug: 'project_head', linkedRole: 'Sales Operations' },
  { name: 'Receptionist', slug: 'receptionist', linkedRole: 'Reception' },
  { name: 'Rental Executive', slug: 'rental_executive', linkedRole: 'Rental Executive' },
  { name: 'Sales Associate', slug: 'sales_associate', linkedRole: 'Sales Associate' },
  { name: 'Sales Executive', slug: 'sales_executive', linkedRole: 'Sales Executive' },
  { name: 'Site Engineer', slug: 'site_engineer', linkedRole: 'Site Supervision' },
  { name: 'Social Media Marketing Executive', slug: 'social_media_marketing_executive', linkedRole: 'Social Media Marketing Executive' },
  { name: 'Store Executive', slug: 'store_executive', linkedRole: 'Store' },
  { name: 'Tax & Finance Executive', slug: 'tax_finance_executive', linkedRole: 'Tax & Finance Executive' },
  { name: 'Telecaller', slug: 'telecaller', linkedRole: 'Telecalling' },
];

/** @deprecated Prefer seedSalaryCatalog — designations/positions are configured in-app. */
export async function seedDesignationsAndSalaryCatalog(
  prisma: PrismaClient,
  _roleIdMap: Record<string, string>,
) {
  await seedSalaryCatalog(prisma);
  await seedCompanyRolesAndDesignations(prisma);
}
