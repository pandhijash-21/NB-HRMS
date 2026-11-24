"use client";

import { useState, useEffect, useCallback } from "react";
import api from "@/lib/axios";

export interface TargetEmployeeSummary {
  id: number;
  fullName: string;
  employeeCode: string | null;
  designation: string | null;
  department: string | null;
  avatarUrl?: string | null;
}

export interface AuditLogEntry {
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

export interface AuditEmployeeSummary {
  employeeId: number;
  fullName: string;
  employeeCode: string | null;
  designation: string | null;
  department: string | null;
  avatarUrl: string | null;
  totalChanges: number;
  lastChangedAt: string | null;
}

export interface SuperadminAdmin {
  id: string;
  username: string;
  fullName: string;
  roleName: string;
  designation: string | null;
  lastLoginAt: string | null;
}

export interface SuperadminTenantHierarchy {
  organizationId: string;
  organizationName: string;
  organizationCode: string;
  admins: SuperadminAdmin[];
  totalEmployees: number;
  totalLogs: number;
  lastActivityAt: string | null;
}

export interface AuditStats {
  totalLogs: number;
  todayLogs: number;
  activeEmployeesWithLogs: number;
  topTables: { tableName: string; label: string; count: number }[];
  topChangers: { userId: string; name: string; count: number }[];
}

export interface PaginationMeta {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface AuditFilterParams {
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

/**
 * Hook to fetch audit logs for tenant admin.
 */
export function useAuditLogs(filters: AuditFilterParams) {
  const [logs, setLogs] = useState<AuditLogEntry[]>([]);
  const [pagination, setPagination] = useState<PaginationMeta>({
    total: 0,
    page: 1,
    limit: 50,
    totalPages: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchLogs = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const params = new URLSearchParams();
      if (filters.employeeId) params.append("employeeId", String(filters.employeeId));
      if (filters.actorId) params.append("actorId", filters.actorId);
      if (filters.tableName) params.append("tableName", filters.tableName);
      if (filters.category && filters.category !== "ALL") params.append("category", filters.category);
      if (filters.search) params.append("search", filters.search);
      if (filters.startDate) params.append("startDate", filters.startDate);
      if (filters.endDate) params.append("endDate", filters.endDate);
      if (filters.page) params.append("page", String(filters.page));
      if (filters.limit) params.append("limit", String(filters.limit));

      const res = await api.get(`/api/admin/audit-logs?${params.toString()}`);
      if (res.data?.success) {
        setLogs(res.data.data.logs || []);
        setPagination(res.data.data.pagination || { total: 0, page: 1, limit: 50, totalPages: 0 });
      } else {
        setError(res.data?.error || "Failed to load audit logs");
      }
    } catch (err: any) {
      setError(err?.response?.data?.message || err?.message || "Failed to load audit logs");
    } finally {
      setLoading(false);
    }
  }, [
    filters.employeeId,
    filters.actorId,
    filters.tableName,
    filters.category,
    filters.search,
    filters.startDate,
    filters.endDate,
    filters.page,
    filters.limit,
  ]);

  useEffect(() => {
    fetchLogs();
  }, [fetchLogs]);

  return { logs, pagination, loading, error, refetch: fetchLogs };
}

/**
 * Hook to fetch list of tenant employees with audit activity.
 */
export function useAuditEmployees(search?: string) {
  const [employees, setEmployees] = useState<AuditEmployeeSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchEmployees = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const q = search ? `?search=${encodeURIComponent(search)}` : "";
      const res = await api.get(`/api/admin/audit-logs/employees${q}`);
      if (res.data?.success) {
        setEmployees(res.data.data || []);
      }
    } catch (err: any) {
      setError(err?.response?.data?.message || err?.message || "Failed to load employees");
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => {
    fetchEmployees();
  }, [fetchEmployees]);

  return { employees, loading, error, refetch: fetchEmployees };
}

/**
 * Hook to fetch tenant audit stats / KPIs.
 */
export function useAuditStats() {
  const [stats, setStats] = useState<AuditStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchStats = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get("/api/admin/audit-logs/stats");
      if (res.data?.success) {
        setStats(res.data.data);
      }
    } catch (err: any) {
      setError(err?.response?.data?.message || err?.message || "Failed to load audit stats");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchStats();
  }, [fetchStats]);

  return { stats, loading, error, refetch: fetchStats };
}

/**
 * Superadmin Hook: Fetch all client companies with tenant admins and aggregate log stats.
 */
export function useSuperadminAuditHierarchy() {
  const [hierarchy, setHierarchy] = useState<SuperadminTenantHierarchy[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchHierarchy = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get("/api/platform/audit-logs/hierarchy");
      if (res.data?.success) {
        setHierarchy(res.data.data || []);
      }
    } catch (err: any) {
      setError(err?.response?.data?.message || err?.message || "Failed to load hierarchy");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchHierarchy();
  }, [fetchHierarchy]);

  return { hierarchy, loading, error, refetch: fetchHierarchy };
}

/**
 * Superadmin Hook: Fetch employees for a specific organization with audit stats.
 */
export function useSuperadminTenantEmployees(organizationId?: string, search?: string) {
  const [employees, setEmployees] = useState<AuditEmployeeSummary[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchTenantEmployees = useCallback(async () => {
    if (!organizationId) {
      setEmployees([]);
      return;
    }
    try {
      setLoading(true);
      setError(null);
      const q = search ? `?search=${encodeURIComponent(search)}` : "";
      const res = await api.get(`/api/platform/audit-logs/organizations/${organizationId}/employees${q}`);
      if (res.data?.success) {
        setEmployees(res.data.data || []);
      }
    } catch (err: any) {
      setError(err?.response?.data?.message || err?.message || "Failed to load tenant employees");
    } finally {
      setLoading(false);
    }
  }, [organizationId, search]);

  useEffect(() => {
    fetchTenantEmployees();
  }, [fetchTenantEmployees]);

  return { employees, loading, error, refetch: fetchTenantEmployees };
}

/**
 * Superadmin Hook: Fetch cross-tenant or tenant-filtered audit logs.
 */
export function useSuperadminAuditLogs(filters: AuditFilterParams) {
  const [logs, setLogs] = useState<AuditLogEntry[]>([]);
  const [pagination, setPagination] = useState<PaginationMeta>({
    total: 0,
    page: 1,
    limit: 50,
    totalPages: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchLogs = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const params = new URLSearchParams();
      if (filters.organizationId) params.append("organizationId", filters.organizationId);
      if (filters.employeeId) params.append("employeeId", String(filters.employeeId));
      if (filters.actorId) params.append("actorId", filters.actorId);
      if (filters.tableName) params.append("tableName", filters.tableName);
      if (filters.category && filters.category !== "ALL") params.append("category", filters.category);
      if (filters.search) params.append("search", filters.search);
      if (filters.startDate) params.append("startDate", filters.startDate);
      if (filters.endDate) params.append("endDate", filters.endDate);
      if (filters.page) params.append("page", String(filters.page));
      if (filters.limit) params.append("limit", String(filters.limit));

      const res = await api.get(`/api/platform/audit-logs?${params.toString()}`);
      if (res.data?.success) {
        setLogs(res.data.data.logs || []);
        setPagination(res.data.data.pagination || { total: 0, page: 1, limit: 50, totalPages: 0 });
      } else {
        setError(res.data?.error || "Failed to load superadmin audit logs");
      }
    } catch (err: any) {
      setError(err?.response?.data?.message || err?.message || "Failed to load audit logs");
    } finally {
      setLoading(false);
    }
  }, [
    filters.organizationId,
    filters.employeeId,
    filters.actorId,
    filters.tableName,
    filters.category,
    filters.search,
    filters.startDate,
    filters.endDate,
    filters.page,
    filters.limit,
  ]);

  useEffect(() => {
    fetchLogs();
  }, [fetchLogs]);

  return { logs, pagination, loading, error, refetch: fetchLogs };
}
