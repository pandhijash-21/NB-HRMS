import type { AuditEntryInput } from '../../middleware/audit';

declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;                          // User.id (UUID)
        employeeId: number;
        roleId: string;
        roleName: string;
        role: string;                        // alias for roleName — backward compat
        permissions: Record<string, string[]>; // { "PERSONAL_INFO": ["READ","WRITE"], ... }
      };
      auditEntries?: AuditEntryInput[];
    }
  }
}
