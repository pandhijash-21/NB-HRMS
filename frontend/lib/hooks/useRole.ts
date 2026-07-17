"use client";

import { useState, useEffect, useCallback } from "react";
import api from "@/lib/axios";

export interface Role {
  id: string;
  name: string;
  description: string | null;
  positionName?: string | null;
  userCount?: number;
  _count?: {
    users: number;
  };
  createdAt: string;
  updatedAt: string;
}

export interface SystemModule {
  key: string;
  name: string;
  description: string | null;
}

export type EmployeeViewScope = "NONE" | "SELF" | "INSTITUTE" | "UNIVERSITY";

export interface Permission {
  id: string;
  moduleKey: string;
  canRead: boolean;
  canWrite: boolean;
  canApprove: boolean;
  canDelete: boolean;
  canExport: boolean;
  employeeViewScope?: EmployeeViewScope;
  module: SystemModule;
}

export function useRolesList(options?: { positionsOnly?: boolean }) {
  const positionsOnly = options?.positionsOnly ?? false;
  const [roles, setRoles] = useState<Role[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchRoles = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get("/admin/roles", {
        params: positionsOnly ? { positionsOnly: "true" } : undefined,
      });
      setRoles(res.data.data ?? []);
    } catch (err: any) {
      setError(err);
    } finally {
      setLoading(false);
    }
  }, [positionsOnly]);

  useEffect(() => {
    fetchRoles();
  }, [fetchRoles]);

  return { roles, loading, error, refetch: fetchRoles };
}

export function useRoleMgmtActions() {
  const createRole = async (data: { name: string; description?: string }) => {
    const res = await api.post("/admin/roles", data);
    return res.data;
  };

  const updateRole = async (id: string, data: { name?: string; description?: string }) => {
    const res = await api.patch(`/admin/roles/${id}`, data);
    return res.data;
  };

  const deleteRole = async (id: string) => {
    const res = await api.delete(`/admin/roles/${id}`);
    return res.data;
  };

  const updatePermissions = async (roleId: string, moduleKey: string, data: {
    canRead?: boolean;
    canWrite?: boolean;
    canApprove?: boolean;
    canDelete?: boolean;
    canExport?: boolean;
    employeeViewScope?: EmployeeViewScope;
  }) => {
    const res = await api.patch(`/admin/roles/${roleId}/permissions/${moduleKey}`, data);
    return res.data;
  };

  return { createRole, updateRole, deleteRole, updatePermissions };
}

export function useSystemModules() {
  const [modules, setModules] = useState<SystemModule[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchModules = async () => {
      try {
        setLoading(true);
        const res = await api.get("/admin/modules");
        setModules(res.data.data ?? []);
      } catch (err: any) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    fetchModules();
  }, []);

  return { modules, loading };
}

export function useRolePermissions(roleId: string) {
  const [permissions, setPermissions] = useState<Permission[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchPermissions = useCallback(async (opts?: { silent?: boolean }) => {
    if (!roleId) return;
    try {
      if (!opts?.silent) setLoading(true);
      const res = await api.get(`/admin/roles/${roleId}/permissions`);
      setPermissions(res.data.data ?? []);
    } catch (err: any) {
      console.error(err);
    } finally {
      if (!opts?.silent) setLoading(false);
    }
  }, [roleId]);

  useEffect(() => {
    fetchPermissions();
  }, [fetchPermissions]);

  const applyOptimistic = useCallback(
    (moduleKey: string, patch: Partial<Permission>) => {
      setPermissions((prev) =>
        prev.map((p) =>
          p.moduleKey === moduleKey ? ({ ...p, ...patch } as Permission) : p,
        ),
      );
    },
    [],
  );

  return {
    permissions,
    loading,
    refetch: fetchPermissions,
    applyOptimistic,
    setPermissions,
  };
}

export function useRoleDetails(roleId: string) {
  const [role, setRole] = useState<Role | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchRole = useCallback(async () => {
    if (!roleId) return;
    try {
      setLoading(true);
      const res = await api.get(`/admin/roles/${roleId}`);
      setRole(res.data.data ?? null);
    } catch (err: any) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [roleId]);

  useEffect(() => {
    fetchRole();
  }, [fetchRole]);

  return { role, loading, refetch: fetchRole };
}
