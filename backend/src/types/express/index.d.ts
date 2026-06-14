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
        employeeViewScope?: 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY';
        permissions: Record<string, string[]>;
      };
      auditEntries?: AuditEntryInput[];
    }
  }
}
