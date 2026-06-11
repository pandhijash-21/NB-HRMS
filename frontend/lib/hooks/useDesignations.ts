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
  user?: { id: string; username: string; isActive: boolean } | null;
  assignments?: Array<{
    holderEmployee: { id: number; generalInfo?: { fullName: string } | null };
  }>;
};

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
      linkedRoleId: string;
      subOrganization?: string;
      password: string;
    }) => {
      const { data } = await api.post("admin/position-slots", body);
      return data.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["position-slots"] }),
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
