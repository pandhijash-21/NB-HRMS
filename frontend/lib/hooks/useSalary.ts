"use client";

import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/axios";
import { useAuthReady } from "@/lib/hooks/useAuthReady";

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

export type StructureStatus = {
  designation: { id: string; name: string };
  fifthConfigured: boolean;
  sixthConfigured: boolean;
  fifthTemplateId: string | null;
  sixthTemplateId: string | null;
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
  payCommissionType: "FIFTH" | "SIXTH";
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

export function useSalaryTemplate(designationId: string, commission: "FIFTH" | "SIXTH") {
  const authReady = useAuthReady();
  return useQuery({
    queryKey: ["salary", "template", designationId, commission],
    queryFn: async () => {
      const { data } = await api.get(`salary/templates/by-designation/${designationId}/${commission}`);
      return data.data as {
        template: { id: string } | null;
        columnDefinitions: SalaryColumnDefinition[];
        configured: boolean;
      };
    },
    enabled: authReady && !!designationId && !!commission,
    retry: 1,
  });
}

export function useCreateSalaryTemplate() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: { designationId: string; payCommissionType: "FIFTH" | "SIXTH" }) => {
      const { data } = await api.post("salary/templates", body);
      return data.data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["salary"] });
    },
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

export function useUpdateEmployeePayCommission() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      employeeId,
      payCommissionType,
      columnOverrides,
      columnRules,
    }: {
      employeeId: number;
      payCommissionType?: "FIFTH" | "SIXTH";
      columnOverrides?: Record<string, number> | null;
      columnRules?: Record<string, unknown> | null;
    }) => {
      const { data } = await api.patch(`salary/employees/${employeeId}/profile`, {
        payCommissionType,
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
  payCommissionType: "FIFTH" | "SIXTH" | null;
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
