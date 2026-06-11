"use client";

import { useState, useEffect, useCallback } from "react";
import api from "@/lib/axios";

export interface User {
  id: string; // The user ID
  employeeId: number | null;
  username?: string | null;
  isActive: boolean;
  roleId: string;
  role: {
    id: string;
    name: string;
  };
  employee?: {
    employeeCode: string;
    fullName: string;
    photoUrl: string | null;
    designation: string;
    department: string;
  } | null;
  lastLoginAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export function useUsersList(params?: { search?: string; status?: string; roleId?: string }) {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchUsers = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      // Pass params as query string
      const q = new URLSearchParams();
      if (params?.search) q.append("search", params.search);
      if (params?.status) q.append("status", params.status);
      if (params?.roleId) q.append("roleId", params.roleId);

      const res = await api.get(`/admin/users?${q.toString()}`);
      setUsers(res.data.data ?? []);
    } catch (err: any) {
      setError(err);
    } finally {
      setLoading(false);
    }
  }, [params?.search, params?.status, params?.roleId]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  return { users, loading, error, refetch: fetchUsers };
}

export function useUserMgmtActions() {
  const createUser = async (data: { employeeId?: number; username?: string; password?: string; subOrganization?: string; roleId: string }) => {
    const res = await api.post("/admin/users", data);
    return res.data;
  };

  const updateUser = async (id: string, data: { isActive?: boolean; roleId?: string }) => {
    const res = await api.patch(`/admin/users/${id}`, data);
    return res.data;
  };

  const deleteUser = async (id: string) => {
    const res = await api.delete(`/admin/users/${id}`);
    return res.data;
  };

  return { createUser, updateUser, deleteUser };
}
