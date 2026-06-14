"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/axios";

export type Institute = {
  id: string;
  code: string;
  name: string;
  isActive: boolean;
  sortOrder: number;
};

export type InstituteMembers = {
  institute: Institute;
  employees: Array<{
    id: number;
    status: string;
    generalInfo: {
      fullName: string | null;
      employeeCode: string | null;
      designation: string | null;
      department: string | null;
      subOrganization: string | null;
    } | null;
  }>;
  aliases: Array<{
    id: string;
    code: string;
    name: string;
    subOrganization: string | null;
    designation: { name: string };
    linkedRole: { name: string };
    user: { id: string; username: string; isActive: boolean } | null;
  }>;
};

export function useInstitutes(options?: { activeOnly?: boolean; admin?: boolean }) {
  const activeOnly = options?.activeOnly !== false;
  const admin = options?.admin === true;

  return useQuery({
    queryKey: ["institutes", { activeOnly, admin }],
    queryFn: async () => {
      const path = admin ? "admin/institutes" : "institutes";
      const params = admin || !activeOnly ? { includeInactive: "true" } : undefined;
      const { data } = await api.get(path, { params });
      const rows = data.data as Institute[];
      return activeOnly && !admin ? rows.filter((i) => i.isActive) : rows;
    },
    staleTime: 60_000,
  });
}

export function useInstituteMembers(id: string) {
  return useQuery({
    queryKey: ["institutes", id, "members"],
    queryFn: async () => {
      try {
        const { data } = await api.get(`admin/institutes/${id}/members`);
        return data.data as InstituteMembers;
      } catch (err: unknown) {
        const ax = err as { response?: { data?: { error?: string; message?: string } } };
        throw new Error(ax.response?.data?.error || ax.response?.data?.message || "Failed to load institute");
      }
    },
    enabled: !!id,
  });
}

export function useInstituteMutations() {
  const qc = useQueryClient();

  const create = useMutation({
    mutationFn: async (body: { code: string; name: string; sortOrder?: number }) => {
      const { data } = await api.post("admin/institutes", body);
      return data.data as Institute;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["institutes"] }),
  });

  const update = useMutation({
    mutationFn: async ({ id, ...body }: { id: string; code?: string; name?: string; isActive?: boolean; sortOrder?: number }) => {
      const { data } = await api.patch(`admin/institutes/${id}`, body);
      return data.data as Institute;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["institutes"] }),
  });

  return { create, update };
}
