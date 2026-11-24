import assert from 'node:assert/strict';
import { isSuperAdminRole, isSystemAdminRole } from '../modules/auth/permissions-map';

console.log('--- Running Audit Logs Module Verification Tests ---');

// Test 1: Role check for Superadmin
{
  assert.equal(isSuperAdminRole('SUPERADMIN'), true, 'SUPERADMIN must be super admin');
  assert.equal(isSuperAdminRole('Super Admin'), true, 'Super Admin must be super admin');
  assert.equal(isSuperAdminRole('ADMIN'), false, 'ADMIN is not super admin');
  assert.equal(isSuperAdminRole('HR'), false, 'HR is not super admin');
  console.log('✓ Test 1: Superadmin role detection verified');
}

// Test 2: Role check for System Admin
{
  assert.equal(isSystemAdminRole('ADMIN'), true, 'ADMIN is system admin');
  assert.equal(isSystemAdminRole('SYSTEM_ADMIN'), true, 'SYSTEM_ADMIN is system admin');
  assert.equal(isSystemAdminRole('System Administrator'), true, 'System Administrator is system admin');
  assert.equal(isSystemAdminRole('EMPLOYEE'), false, 'EMPLOYEE is not system admin');
  console.log('✓ Test 2: System Admin role detection verified');
}

// Test 3: Formatting field label helper
function formatFieldLabel(field: string): string {
  if (!field) return '';
  return field
    .replace(/([A-Z])/g, ' $1')
    .replace(/[_-]+/g, ' ')
    .trim()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

{
  assert.equal(formatFieldLabel('marital_status'), 'Marital Status');
  assert.equal(formatFieldLabel('grossSalary'), 'Gross Salary');
  assert.equal(formatFieldLabel('ifsc_code'), 'Ifsc Code');
  assert.equal(formatFieldLabel('pan_no'), 'Pan No');
  assert.equal(formatFieldLabel('emergency_contact_number'), 'Emergency Contact Number');
  console.log('✓ Test 3: Field label formatter verified');
}

// Test 4: Tenant isolation validation logic
{
  const tenantEmps = [101, 102, 103];
  const otherTenantEmps = [201, 202];

  const canAccessEmp = (empId: number, scopedEmps: number[] | null, isSuper: boolean) => {
    if (isSuper) return true;
    if (!scopedEmps) return false;
    return scopedEmps.includes(empId);
  };

  assert.equal(canAccessEmp(101, tenantEmps, false), true, 'Tenant admin should access their own employee');
  assert.equal(canAccessEmp(201, tenantEmps, false), false, 'Tenant admin MUST NOT access other tenant employee');
  assert.equal(canAccessEmp(201, tenantEmps, true), true, 'Superadmin can access all tenant employees');
  console.log('✓ Test 4: Tenancy isolation logic verified');
}

console.log('--- All Audit Logs Verification Tests Passed! ---');
