"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/axios";
import { toast } from "sonner";

const BASE = "leave";

// ─── Types ───────────────────────────────────────────────────────────────────

export interface LeaveBalance {
  id: string;
  leaveTypeId: string;
  year: number;
  totalCredited: number;
  carryForward: number;
  used: number;
  pending: number;
  available: number;
  leaveType: { name: string; code: string; allowHalfDay: boolean };
}

export interface LeaveApplication {
  id: string;
  applicationNo: string;
  leaveTypeId: string;
  fromDate: string;
  toDate: string;
  isHalfDay: boolean;
  halfDaySession?: string | null;
  totalDays: number;
  reason: string;
  documentUrl?: string | null;
  status: "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED";
  appliedAt: string;
  isAppliedByAdmin: boolean;
  leaveType: { name: string; code: string };
  approvalSteps: LeaveApprovalStep[];
  employee?: {
    id: number;
    generalInfo?: {
      fullName?: string;
      employeeCode?: string;
      designation?: string;
      department?: string;
    };
  };
}

export interface LeaveApprovalStep {
  id: string;
  stepNumber: number;
  approverRole: string;
  approverId?: number | null;
  action?: string | null;
  remarks?: string | null;
  actionAt?: string | null;
  isSuperseded: boolean;
}

export interface LeaveType {
  id: string;
  code: string;
  name: string;
  applicableTo: "TEACHING" | "NON_TEACHING" | "BOTH";
  defaultDaysPerYear?: number | null;
  allowHalfDay: boolean;
  skipPublicHolidays: boolean;
  skipWeekends: boolean;
  requiresDocument: boolean;
  requiresReason: boolean;
  isCarryForward: boolean;
  isActive: boolean;
  employeeCanApply: boolean;
  creditSchedule?: unknown;
}

export interface LeaveSetting {
  id: string;
  key: string;
  value: string;
  description: string;
}

export interface PublicHoliday {
  id: string;
  name: string;
  date: string;
  year: number;
  isOptional: boolean;
}

// ─── Employee hooks ───────────────────────────────────────────────────────────

export function useMyLeaveBalances(year?: number) {
  return useQuery({
    queryKey: ["leave", "my-balances", year],
    queryFn: async () => {
      const { data } = await api.get(`${BASE}/my/balances`, { params: year ? { year } : {} });
      return data.data as LeaveBalance[];
    },
  });
}

export function useMyLeaveApplications(params?: {
  status?: string;
  year?: number;
  page?: number;
  limit?: number;
}) {
  return useQuery({
    queryKey: ["leave", "my-applications", params],
    queryFn: async () => {
      const { data } = await api.get(`${BASE}/my/applications`, { params });
      return data.data as { items: LeaveApplication[]; total: number };
    },
  });
}

export function useApplyLeave() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (payload: {
      leaveTypeId: string;
      fromDate: string;
      toDate: string;
      isHalfDay?: boolean;
      halfDaySession?: string | null;
      reason: string;
      documentUrl?: string | null;
    }) => {
      const { data } = await api.post(`${BASE}/apply`, payload);
      return data.data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["leave"] });
      toast.success("Leave application submitted successfully");
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Failed to submit"),
  });
}

export function useCancelLeave() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.post(`${BASE}/applications/${id}/cancel`);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["leave"] });
      toast.success("Leave application cancelled");
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Failed to cancel"),
  });
}

// ─── Approver hooks ───────────────────────────────────────────────────────────

export function usePendingApprovals() {
  return useQuery({
    queryKey: ["leave", "pending-approvals"],
    queryFn: async () => {
      const { data } = await api.get(`${BASE}/my/pending-approvals`);
      return data.data as LeaveApplication[];
    },
  });
}

export function useApproveLeave() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, remarks }: { id: string; remarks?: string }) => {
      const { data } = await api.post(`${BASE}/applications/${id}/approve`, { remarks });
      return data.data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["leave"] });
      toast.success("Application approved");
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Failed to approve"),
  });
}

export function useRejectLeave() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, remarks }: { id: string; remarks?: string }) => {
      const { data } = await api.post(`${BASE}/applications/${id}/reject`, { remarks });
      return data.data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["leave"] });
      toast.success("Application rejected");
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Failed to reject"),
  });
}

export function useAdminApplyLeave() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (payload: {
      employeeId: number;
      leaveTypeId: string;
      fromDate: string;
      toDate: string;
      isHalfDay?: boolean;
      halfDaySession?: string | null;
      reason: string;
      documentUrl?: string | null;
    }) => {
      const { data } = await api.post(`${BASE}/admin/apply`, payload);
      return data.data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["leave"] });
      toast.success("Leave applied on behalf of employee");
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Failed to apply leave"),
  });
}

export function useMyApprovalHistory(params?: { status?: string; page?: number; limit?: number }) {
  return useQuery({
    queryKey: ["leave", "my-approval-history", params],
    queryFn: async () => {
      const { data } = await api.get(`${BASE}/admin/applications`, {
        params: { ...params, limit: params?.limit ?? 50 },
      });
      return data.data as { items: LeaveApplication[]; total: number };
    },
    retry: false,
  });
}

// ─── Admin hooks ─────────────────────────────────────────────────────────────

export function useAdminLeaveApplications(params?: {
  employeeId?: number;
  status?: string;
  year?: number;
  page?: number;
  limit?: number;
}) {
  return useQuery({
    queryKey: ["leave", "admin-applications", params],
    queryFn: async () => {
      const { data } = await api.get(`${BASE}/admin/applications`, { params });
      return data.data as { items: LeaveApplication[]; total: number };
    },
  });
}

export function useLeaveTypes() {
  return useQuery({
    queryKey: ["leave", "types"],
    queryFn: async () => {
      const { data } = await api.get(`${BASE}/types`);
      return data.data as LeaveType[];
    },
  });
}

export function useUpsertLeaveType() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (payload: {
      code: string;
      name: string;
      applicableTo: "TEACHING" | "NON_TEACHING" | "BOTH";
      defaultDaysPerYear?: number | null;
      isCarryForward?: boolean;
      allowHalfDay?: boolean;
      skipPublicHolidays?: boolean;
      skipWeekends?: boolean;
      requiresDocument?: boolean;
      requiresReason?: boolean;
      creditSchedule?: unknown;
      isActive?: boolean;
      employeeCanApply?: boolean;
    }) => {
      const { data } = await api.post(`${BASE}/admin/types`, payload);
      return data.data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["leave", "admin-types"] });
      qc.invalidateQueries({ queryKey: ["leave", "types"] });
      toast.success("Leave type updated");
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Failed to update leave type"),
  });
}

export function useDeleteLeaveType() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (code: string) => {
      const { data } = await api.delete(`${BASE}/admin/types/${code}`);
      return data.data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["leave", "admin-types"] });
      qc.invalidateQueries({ queryKey: ["leave", "types"] });
      toast.success("Leave type removed");
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Failed to remove leave type"),
  });
}

export function useAdminLeaveTypes() {
  return useQuery({
    queryKey: ["leave", "admin-types"],
    queryFn: async () => {
      const { data } = await api.get(`${BASE}/admin/types`);
      return data.data as LeaveType[];
    },
  });
}

export function useLeaveSettings() {
  return useQuery({
    queryKey: ["leave", "settings"],
    queryFn: async () => {
      const { data } = await api.get(`${BASE}/admin/settings`);
      return data.data as LeaveSetting[];
    },
  });
}

export function useUpdateLeaveSetting() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ key, value }: { key: string; value: string }) => {
      const { data } = await api.patch(`${BASE}/admin/settings/${key}`, { value });
      return data.data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["leave", "settings"] });
      toast.success("Setting updated");
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Failed to update setting"),
  });
}

export function usePublicHolidays(year?: number) {
  const y = year ?? new Date().getFullYear();
  return useQuery({
    queryKey: ["leave", "holidays", y],
    queryFn: async () => {
      const { data } = await api.get(`${BASE}/admin/holidays`, { params: { year: y } });
      return data.data as PublicHoliday[];
    },
  });
}

export function useAddHoliday() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { name: string; date: string; year: number; isOptional?: boolean }) => {
      const { data } = await api.post(`${BASE}/admin/holidays`, payload);
      return data.data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["leave", "holidays"] });
      toast.success("Holiday added");
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Failed to add holiday"),
  });
}

export function useDeleteHoliday() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`${BASE}/admin/holidays/${id}`);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["leave", "holidays"] });
      toast.success("Holiday deleted");
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Failed to delete"),
  });
}

export function useAdminEmployeeBalances(employeeId?: number, year?: number) {
  const y = year ?? new Date().getFullYear();
  return useQuery({
    queryKey: ["leave", "admin-balances", employeeId, y],
    queryFn: async () => {
      const { data } = await api.get(`${BASE}/admin/balances/${employeeId}`, { params: { year: y } });
      return data.data as LeaveBalance[];
    },
    enabled: !!employeeId,
  });
}

export function useYearEndTrigger() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (year: number) => {
      const { data } = await api.post(`${BASE}/admin/year-end`, { year });
      return data.data;
    },
    onSuccess: (res: any) => {
      qc.invalidateQueries({ queryKey: ["leave"] });
      toast.success(`Year-end done. ${res?.processed ?? 0} balances processed`);
    },
    onError: (e: any) => toast.error(e.response?.data?.error ?? "Year-end failed"),
  });
}
