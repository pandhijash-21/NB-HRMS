"use client";

import { useQuery } from "@tanstack/react-query";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/axios";

export type AttendanceCalendarDay = {
  count: number;
  firstIn?: string;
  lastOut?: string;
};

export function useMyAttendanceCalendar(params: { from: string; to: string }) {
  return useQuery({
    queryKey: ["attendance", "my-calendar", params],
    queryFn: async () => {
      const { data } = await api.get("attendance/my/calendar", { params });
      return data.data as Record<string, AttendanceCalendarDay>;
    },
    enabled: !!params.from && !!params.to,
  });
}

export type AttendancePunch = {
  id: string;
  punchAt: string;
  terminalId?: string | null;
  punchType?: string | null;
  source: string;
};

export type AttendancePolicy = {
  id: string;
  defaultPunchInTime: string; // "HH:MM" IST
  defaultPunchOutTime: string; // "HH:MM" IST
  punchInBufferMinutes: number;
  punchOutBufferMinutes: number;
  updatedAt?: string;
  updatedBy?: string | null;
};

export function useMyAttendanceDay(date: string) {
  return useQuery({
    queryKey: ["attendance", "my-day", date],
    queryFn: async () => {
      const { data } = await api.get("attendance/my/day", { params: { date } });
      return data.data as {
        punches: AttendancePunch[];
        summary: {
          firstIn: string | null;
          lastOut: string | null;
          totalMinutes: number;
          policy: AttendancePolicy;
          evaluation: {
            isLate: boolean | null;
            isHalfDay: boolean | null;
            meetsPunchOut: boolean | null;
          };
        };
      };
    },
    enabled: !!date,
  });
}

export type AdminAttendanceEmployeeDay = {
  employeeId: number;
  fullName: string;
  employeeCode: string | null;
  designation?: string | null;
  department?: string | null;
  punches: Array<{
    id: string;
    punchAt: string;
    terminalId: string | null;
    punchType: string | null;
    source: string;
  }>;
};

export function useAdminAttendanceDay(date: string) {
  return useQuery({
    queryKey: ["attendance", "admin-day", date],
    queryFn: async () => {
      const { data } = await api.get("attendance/admin/day", { params: { date } });
      return data.data as AdminAttendanceEmployeeDay[];
    },
    enabled: !!date,
  });
}

export function useAdminAddPunch() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { employeeId: number; punchAt: string; punchType?: string | null; terminalId?: string | null }) => {
      const { data } = await api.post("attendance/admin/punch", payload);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["attendance", "admin-day"] });
      queryClient.invalidateQueries({ queryKey: ["attendance", "my-day"] });
      queryClient.invalidateQueries({ queryKey: ["attendance", "my-calendar"] });
      queryClient.invalidateQueries({ queryKey: ["attendance", "admin-employee-history"] });
    },
  });
}

export function useAdminUpdatePunch() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { punchId: string; punchAt: string; punchType?: string | null; terminalId?: string | null }) => {
      const { punchId, ...body } = payload;
      const { data } = await api.patch(`attendance/admin/punch/${punchId}`, body);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["attendance", "admin-day"] });
      queryClient.invalidateQueries({ queryKey: ["attendance", "my-day"] });
      queryClient.invalidateQueries({ queryKey: ["attendance", "my-calendar"] });
      queryClient.invalidateQueries({ queryKey: ["attendance", "admin-employee-history"] });
    },
  });
}

export function useAdminAttendancePolicy() {
  return useQuery({
    queryKey: ["attendance", "admin-policy"],
    queryFn: async () => {
      const { data } = await api.get("attendance/admin/policy");
      return data.data as AttendancePolicy;
    },
  });
}

export function useAdminUpdateAttendancePolicy() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: Omit<AttendancePolicy, "id" | "updatedAt" | "updatedBy">) => {
      const { data } = await api.patch("attendance/admin/policy", payload);
      return data.data as AttendancePolicy;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["attendance", "admin-policy"] });
      queryClient.invalidateQueries({ queryKey: ["attendance", "my-day"] });
      queryClient.invalidateQueries({ queryKey: ["attendance", "admin-employee-history"] });
    },
  });
}

export type AdminEmployeeHistoryDay = {
  date: string;
  firstIn: string | null;
  lastOut: string | null;
  totalMinutes: number;
  punches: Array<{
    id: string;
    punchAt: string;
    terminalId: string | null;
    punchType: string | null;
    source: string;
  }>;
  isLate: boolean | null;
  isHalfDay: boolean | null;
  meetsPunchOut: boolean | null;
};

export type AdminEmployeeHistory = {
  employee: {
    employeeId: number;
    fullName: string;
    employeeCode: string | null;
    designation: string | null;
    department: string | null;
  };
  from: string;
  to: string;
  policy: AttendancePolicy;
  days: AdminEmployeeHistoryDay[];
};

export function useAdminEmployeeHistory(params: {
  employeeId: number;
  from: string;
  to: string;
}) {
  return useQuery({
    queryKey: ["attendance", "admin-employee-history", params],
    queryFn: async () => {
      const { data } = await api.get(`attendance/admin/employee/${params.employeeId}/history`, {
        params: { from: params.from, to: params.to },
      });
      return data.data as AdminEmployeeHistory;
    },
    enabled: !!params.employeeId && !!params.from && !!params.to,
  });
}

