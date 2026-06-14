"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/axios";

export type Designation = {
  id: string;
  name: string;
  slug: string;
  isAlias: boolean;
  linkedRoleId: string | null;
  isActive: boolean;
  sortOrder: number;
  linkedRole?: { id: string; name: string } | null;
};

export type PositionSlot = {
  id: string;
  code: string;
  name: string;
  designationId: string;
  linkedRoleId: string;
  subOrganization: string | null;
  userId: string | null;
  isActive: boolean;
  designation: Designation;
  linkedRole: { id: string; name: string };
  institute?: { id: string; code: string; name: string } | null;
  user?: {
    id: string;
    username: string;
    isActive: boolean;
    isFirstLogin?: boolean;
    lastLoginAt?: string | null;
  } | null;
  assignments?: Array<{
    holderEmployee: { id: number; generalInfo?: { fullName: string } | null };
  }>;
};

export type PositionSummary = {
  id: string;
  name: string;
  linkedRoleId: string;
  linkedRoleName: string;
};

export function usePositions() {
  return useQuery({
    queryKey: ["positions"],
    queryFn: async () => {
      const { data } = await api.get("admin/positions");
      return data.data as PositionSummary[];
    },
    staleTime: 60_000,
  });
}

export function useDesignations(isAlias?: boolean, options?: { includeInactive?: boolean }) {
  return useQuery({
    queryKey: ["designations", isAlias, options?.includeInactive],
    queryFn: async () => {
      const params: Record<string, string> = {};
      if (isAlias !== undefined) params.isAlias = String(isAlias);
      if (options?.includeInactive) params.includeInactive = "true";
      const { data } = await api.get("admin/designations", { params });
      return data.data as Designation[];
    },
  });
}

export function useCreatePosition() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: { displayName: string; roleName: string; description?: string }) => {
      const { data } = await api.post("admin/positions", body);
      return data.data as {
        role: { id: string; name: string };
        designation: Designation;
      };
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["designations"] });
      qc.invalidateQueries({ queryKey: ["positions"] });
      qc.invalidateQueries({ queryKey: ["roles-list"] });
    },
  });
}

export function useCreateDesignation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: { name: string; isAlias?: boolean; linkedRoleId?: string }) => {
      const { data } = await api.post("admin/designations", body);
      return data.data as Designation;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["designations"] }),
  });
}

export function useUpdateDesignation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: { id: string; name?: string; isActive?: boolean; linkedRoleId?: string | null }) => {
      const { data } = await api.patch(`admin/designations/${id}`, body);
      return data.data as Designation;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["designations"] }),
  });
}

export function usePositionSlots() {
  return useQuery({
    queryKey: ["position-slots"],
    queryFn: async () => {
      const { data } = await api.get("admin/position-slots");
      return data.data as PositionSlot[];
    },
  });
}

export function useCreatePositionSlot() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: {
      code: string;
      name: string;
      designationId: string;
      linkedRoleId?: string;
      instituteId?: string;
      subOrganization?: string;
      password: string;
      grantUniversityAccess?: boolean;
    }) => {
      const { data } = await api.post("admin/position-slots", body);
      return data.data as PositionSlot & {
        credentials?: { loginId: string; password: string; readyToLogin: boolean; message: string };
      };
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["position-slots"] });
      qc.invalidateQueries({ queryKey: ["employees", "names"] });
    },
  });
}

export function useAssignPositionHolder() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      slotId,
      holderEmployeeId,
      effectiveFrom,
    }: {
      slotId: string;
      holderEmployeeId: number;
      effectiveFrom: string;
    }) => {
      const { data } = await api.post(`admin/position-slots/${slotId}/assign`, {
        holderEmployeeId,
        effectiveFrom,
      });
      return data.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["position-slots"] }),
  });
}
