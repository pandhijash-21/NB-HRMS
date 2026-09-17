import type { AuditEntryInput } from '../../middleware/audit';

declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        employeeId?: number | null;
        roleId: string;
        roleName: string;
        role: string;
        subOrganization?: string | null;
        organizationId?: string | null;
        employeeViewScope?: 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY';
        companyAdminGranted?: boolean;
        permissions: Record<string, string[]>;
      };
      auditEntries?: AuditEntryInput[];
    }
  }
}
