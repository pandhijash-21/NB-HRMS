export interface AuditLogFilterInput {
  employeeId?: number;
  actorId?: string;
  tableName?: string;
  category?: 'ALL' | 'CLICKS' | 'VIEWS' | 'ACTIONS' | 'DIFFS';
  search?: string;
  startDate?: string;
  endDate?: string;
  page?: number;
  limit?: number;
  organizationId?: string;
}

export interface TargetEmployeeSummary {
  id: number;
  fullName: string;
  employeeCode: string | null;
  designation: string | null;
  department: string | null;
  avatarUrl?: string | null;
}

export interface ChangedByUserSummary {
  id: string;
  username: string;
  fullName: string;
  roleName: string | null;
  isSelfChange: boolean;
}

export interface AuditLogEntryDTO {
  id: string;
  tableName: string;
  tableLabel: string;
  category: 'CLICK' | 'VIEW' | 'ACTION' | 'DIFF';
  recordId: string;
  employeeId: number | null;
  targetEmployee: TargetEmployeeSummary | null;
  fieldName: string;
  fieldLabel: string;
  oldValue: string | null;
  newValue: string | null;
  changedBy: string;
  changedByName: string;
  changedByRole: string | null;
  isSelfChange: boolean;
  changedAt: string;
  changeReason: string | null;
  ipAddress: string | null;
  userAgent: string | null;
}

export interface AuditEmployeeSummaryDTO {
  employeeId: number;
  fullName: string;
  employeeCode: string | null;
  designation: string | null;
  department: string | null;
  avatarUrl: string | null;
  totalChanges: number;
  lastChangedAt: string | null;
  lastChangedBy?: string | null;
}

export interface SuperadminAdminDTO {
  id: string;
  username: string;
  fullName: string;
  roleName: string;
  designation: string | null;
  lastLoginAt: string | null;
}

export interface SuperadminTenantHierarchyDTO {
  organizationId: string;
  organizationName: string;
  organizationCode: string;
  admins: SuperadminAdminDTO[];
  totalEmployees: number;
  totalLogs: number;
  lastActivityAt: string | null;
}

export interface AuditStatsDTO {
  totalLogs: number;
  todayLogs: number;
  activeEmployeesWithLogs: number;
  topTables: { tableName: string; label: string; count: number }[];
  topChangers: { userId: string; name: string; count: number }[];
}
