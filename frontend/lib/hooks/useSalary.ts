"use client";

import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/axios";
import { useAuthReady } from "@/lib/hooks/useAuthReady";
import type {
  AttendanceMonthlyStats,
  AttendanceMonthlySummary,
  AdminEmployeeHistoryDay,
  AttendancePolicy,
} from "@/lib/hooks/useAttendance";

function useDebouncedValue<T>(value: T, delay = 400): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}

export type SalaryColumnDefinition = {
  id: string;
  columnIdentifier: string;
  displayName: string;
  category: "EARNING" | "DEDUCTION";
  evaluationOrder: number;
  isRuleConfigurable: boolean;
};

export type SalaryColumnRule = {
  id: string;
  columnIdentifier: string;
  category: "EARNING" | "DEDUCTION";
  ruleType: "FIXED" | "PERCENTAGE" | "CONDITIONAL";
  formulaPreview: string;
  fixedDefaultValue: string | null;
  percentageValue: string | null;
  percentageReferenceColumns: Array<{ column_identifier: string; weight: number }> | null;
  conditions: Array<{
    id: string;
    comparator: string;
    referenceColumnIdentifier: string;
    thresholdValue: string;
    resultType: string;
    resultValue: string;
    resultReferenceColumnIdentifier: string | null;
    resultReferenceColumns: Array<{ column_identifier: string; weight: number }> | null;
    sortOrder: number;
    isElseFallback: boolean;
  }>;
};

export type PayCommission = {
  id: string;
  code: string;
  name: string;
  description?: string | null;
  isActive: boolean;
  ruleEditorEnabled: boolean;
  sortOrder: number;
  _count?: {
    columnDefinitions: number;
    salaryStructureTemplates: number;
    employeeSalaryInfos: number;
  };
};

export type StructureStatus = {
  designation: { id: string; name: string };
  commissions: Array<{
    payCommission: Pick<PayCommission, "id" | "code" | "name" | "ruleEditorEnabled">;
    configured: boolean;
    templateId: string | null;
  }>;
};

export type SalaryRecord = {
  id: string;
  employeeId: number;
  salaryMonth: number;
  salaryYear: number;
  status: "DRAFT" | "FINALIZED";
  grossPay: string;
  totalDeductions: string;
  netPay: string;
  payCommissionCode: string;
  employee?: { generalInfo?: { fullName: string; department: string } };
  template?: { designation: { name: string }; payCommission: { name: string } };
  columnValues?: Array<{
    columnIdentifier: string;
    category: string;
    ruleComputedValue: string;
    overrideValue: string | null;
    effectiveValue: string;
    formulaPreview: string;
  }>;
};

export function useSalaryStructureStatus() {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary", "structures-status"],
    queryFn: async () => {
      const { data } = await api.get("salary/structures/status");
      return data.data as StructureStatus[];
    },
    enabled: authReady,
    retry: 1,
  });
}

export function usePayCommissions() {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary", "pay-commissions"],
    queryFn: async () => {
      const { data } = await api.get("salary/pay-commissions");
      return data.data as PayCommission[];
    },
    enabled: authReady,
    retry: 1,
  });
}

export function usePayCommission(id: string) {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary", "pay-commission", id],
    queryFn: async () => {
      const { data } = await api.get(`salary/pay-commissions/${id}`);
      return data.data as PayCommission & { columnDefinitions: SalaryColumnDefinition[] };
    },
    enabled: authReady && !!id,
    retry: 1,
  });
}

export function useCreatePayCommission() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: {
      code: string;
      name: string;
      description?: string | null;
      ruleEditorEnabled?: boolean;
      cloneFromCommissionId?: string | null;
    }) => {
      const { data } = await api.post("salary/pay-commissions", body);
      return data.data as PayCommission;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["salary"] }),
  });
}

export function useUpdatePayCommission() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      ...body
    }: {
      id: string;
      name?: string;
      description?: string | null;
      isActive?: boolean;
      ruleEditorEnabled?: boolean;
      sortOrder?: number;
    }) => {
      const { data } = await api.patch(`salary/pay-commissions/${id}`, body);
      return data.data as PayCommission;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["salary"] }),
  });
}

export function useCreatePayCommissionColumn() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      payCommissionId,
      ...body
    }: {
      payCommissionId: string;
      columnIdentifier: string;
      displayName: string;
      category: "EARNING" | "DEDUCTION";
      evaluationOrder: number;
      isRuleConfigurable?: boolean;
    }) => {
      const { data } = await api.post(`salary/pay-commissions/${payCommissionId}/columns`, body);
      return data.data as SalaryColumnDefinition;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["salary"] }),
  });
}

export function useDeletePayCommissionColumn() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (columnId: string) => {
      const { data } = await api.delete(`salary/pay-commissions/columns/${columnId}`);
      return data.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["salary"] }),
  });
}

export function useSalaryTemplate(designationId: string, commissionCode: string) {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary", "template", designationId, commissionCode],
    queryFn: async () => {
      const { data } = await api.get(
        `salary/templates/by-designation/${designationId}/${commissionCode}`,
      );
      return data.data as {
        template: { id: string; columnVisibility?: Record<string, boolean> | null } | null;
        columnDefinitions: SalaryColumnDefinition[];
        configured: boolean;
        payCommission: PayCommission | null;
      };
    },
    enabled: authReady && !!designationId && !!commissionCode,
    retry: 1,
  });
}

export function useCreateSalaryTemplate() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: { designationId: string; payCommissionCode: string }) => {
      const { data } = await api.post("salary/templates", body);
      return data.data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["salary"] });
    },
  });
}

export function useUpdateTemplateColumnVisibility() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      templateId,
      columnVisibility,
    }: {
      templateId: string;
      columnVisibility: Record<string, boolean>;
    }) => {
      const { data } = await api.patch(`salary/templates/${templateId}/column-visibility`, {
        columnVisibility,
      });
      return data.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["salary"] }),
  });
}

export function useUpsertColumnRule() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      templateId,
      columnIdentifier,
      category,
      body,
    }: {
      templateId: string;
      columnIdentifier: string;
      category: "EARNING" | "DEDUCTION";
      body: Record<string, unknown>;
    }) => {
      const { data } = await api.put(`salary/templates/${templateId}/rules/${columnIdentifier}`, body, {
        params: { category },
      });
      return data.data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["salary"] }),
  });
}

export type ComputedSalaryResult = {
  columns: Array<{
    column_identifier: string;
    category: string;
    display_name?: string;
    rule_computed_value: number;
    effective_value: number;
    formula_preview: string;
  }>;
  gross_pay: number;
  total_deductions: number;
  net_pay: number;
};

export function useComputeSalary() {
  return useMutation({
    mutationFn: async ({
      templateId,
      overrides,
      employeeId,
      employeeRules,
    }: {
      templateId: string;
      overrides?: Record<string, number>;
      employeeId?: number;
      employeeRules?: Record<string, unknown> | null;
    }) => {
      const { data } = await api.post("salary/compute", {
        templateId,
        overrides,
        employeeId,
        employeeRules,
      });
      return data.data as ComputedSalaryResult;
    },
  });
}

/** Live salary compute — recalculates when overrides or rules change (debounced). */
export function useSalaryComputeLive(opts: {
  templateId: string | null;
  employeeId: number;
  overrides: Record<string, number>;
  employeeRules: Record<string, unknown>;
}) {
  const authReady = useAuthReady();
  const debouncedOverrides = useDebouncedValue(opts.overrides);
  const debouncedRules = useDebouncedValue(opts.employeeRules);

  return useQuery({
    queryKey: [
      "salary",
      "compute-live",
      opts.templateId,
      opts.employeeId,
      debouncedOverrides,
      debouncedRules,
    ],
    queryFn: async () => {
      const { data } = await api.post("salary/compute", {
        templateId: opts.templateId,
        employeeId: opts.employeeId,
        overrides: Object.keys(debouncedOverrides).length ? debouncedOverrides : undefined,
        employeeRules: Object.keys(debouncedRules).length ? debouncedRules : undefined,
      });
      return data.data as ComputedSalaryResult;
    },
    enabled: authReady && !!opts.templateId && Number.isFinite(opts.employeeId),
    placeholderData: (prev) => prev,
  });
}

export function useSalaryRecords(filters?: Record<string, string | number | undefined>) {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary", "records", filters],
    queryFn: async () => {
      const { data } = await api.get("salary/records", { params: filters });
      return data.data as SalaryRecord[];
    },
    enabled: authReady,
    retry: 1,
  });
}

export function useSalaryRecord(id: string) {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary", "record", id],
    queryFn: async () => {
      const { data } = await api.get(`salary/records/${id}`);
      return data.data as SalaryRecord;
    },
    enabled: authReady && !!id,
    retry: 1,
  });
}

export function useCreateSalaryRecord() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: { employeeId: number; salaryMonth: number; salaryYear: number }) => {
      const { data } = await api.post("salary/records", body);
      return data.data as SalaryRecord;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["salary", "records"] }),
  });
}

export function useUpdateSalaryRecord() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, overrides }: { id: string; overrides?: Record<string, number> }) => {
      const { data } = await api.patch(`salary/records/${id}`, { overrides });
      return data.data as SalaryRecord;
    },
    onSuccess: (_, vars) => {
      qc.invalidateQueries({ queryKey: ["salary", "records"] });
      qc.invalidateQueries({ queryKey: ["salary", "record", vars.id] });
    },
  });
}

export function useFinalizeSalaryRecord() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { data } = await api.post(`salary/records/${id}/finalize`);
      return data.data as SalaryRecord;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["salary", "records"] }),
  });
}

export function useSalarySlip(id: string) {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary", "slip", id],
    queryFn: async () => {
      const { data } = await api.get(`salary/records/${id}/slip`);
      return data.data;
    },
    enabled: authReady && !!id,
    retry: 1,
  });
}

export function useEmployeeSalarySlip(employeeId: number, recordId: string) {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary", "employee-slip", employeeId, recordId],
    queryFn: async () => {
      const { data } = await api.get(`salary/employees/${employeeId}/slip/${recordId}`);
      return data.data;
    },
    enabled: authReady && Number.isFinite(employeeId) && !!recordId,
    retry: 1,
  });
}

export type EmployeeSalaryMonthlyOverview = {
  year: number;
  month: number;
  attendance: AttendanceMonthlyStats;
  attendancePolicy: AttendancePolicy;
  days: AdminEmployeeHistoryDay[];
  leaveApplications: AttendanceMonthlySummary["leaveApplications"];
  leaveBalances: Array<{
    leaveType: { code: string; name: string };
    totalCredited: number;
    carryForward: number;
    used: number;
    available: number;
  }>;
  salaryRecord: {
    id: string;
    status: string;
    salaryMonth: number;
    salaryYear: number;
    grossPay: number;
    totalDeductions: number;
    netPay: number;
    payCommissionCode: string;
    designation: string;
    canDownloadSlip: boolean;
  } | null;
};

export function useEmployeeSalaryMonthlyOverview(params: {
  employeeId: number;
  year: number;
  month: number;
}) {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary", "employee-monthly-overview", params.employeeId, params.year, params.month],
    queryFn: async () => {
      const { data } = await api.get(`salary/employees/${params.employeeId}/monthly-overview`, {
        params: { year: params.year, month: params.month },
      });
      return data.data as EmployeeSalaryMonthlyOverview;
    },
    enabled: authReady && !!params.employeeId && !!params.year && !!params.month,
    retry: 1,
  });
}

export function useUpdateEmployeePayCommission() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      employeeId,
      payCommissionCode,
      columnOverrides,
      columnRules,
    }: {
      employeeId: number;
      payCommissionCode?: string;
      columnOverrides?: Record<string, number> | null;
      columnRules?: Record<string, unknown> | null;
    }) => {
      const { data } = await api.patch(`salary/employees/${employeeId}/profile`, {
        payCommissionCode,
        columnOverrides,
        columnRules,
      });
      return data.data;
    },
    onSuccess: (_, vars) => {
      qc.invalidateQueries({ queryKey: ["salary-profile", vars.employeeId] });
      qc.invalidateQueries({ queryKey: ["salary-preview", vars.employeeId] });
    },
  });
}

export type EmployeeSalaryPreview = {
  configured: boolean;
  reason: "NO_DESIGNATION" | "NO_COMMISSION" | "NO_TEMPLATE" | "NO_RULES" | null;
  designation: { id: string; name: string } | null;
  payCommissionCode: string | null;
  payCommission: PayCommission | null;
  ruleEditorEnabled?: boolean;
  columnVisibility?: Record<string, boolean>;
  templateId: string | null;
  columnOverrides: Record<string, number>;
  employeeColumnRules: Record<string, Record<string, unknown>>;
  templateRules: SalaryColumnRule[];
  columnDefinitions: SalaryColumnDefinition[];
  computed: {
    columns: Array<{
      column_identifier: string;
      category: string;
      display_name: string;
      rule_computed_value: number;
      effective_value: number;
      formula_preview: string;
    }>;
    gross_pay: number;
    total_deductions: number;
    net_pay: number;
  } | null;
};

export function useEmployeeSalaryPreview(employeeId: number) {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary-preview", employeeId],
    queryFn: async () => {
      const { data } = await api.get(`salary/employees/${employeeId}/salary-preview`);
      return data.data as EmployeeSalaryPreview;
    },
    enabled: authReady && Number.isFinite(employeeId),
    retry: 1,
  });
}
