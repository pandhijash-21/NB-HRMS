"use client";

import { useQuery, useMutation } from "@apollo/client/react";
import { GET_EMPLOYEE, UPDATE_EMPLOYEE_GENERAL, GET_EMPLOYEE_LIST } from "@/lib/graphql";
import api from "@/lib/axios";

export function useEmployee(id?: string) {
  const { data, loading, error, refetch } = useQuery(GET_EMPLOYEE, {
    variables: { id },
    skip: !id,
  });

  return {
    employee: data?.employee_by_pk ?? null,
    loading,
    error,
    refetch,
  };
}

export function useEmployeeList(params?: {
  limit?: number;
  offset?: number;
  search?: string;
}) {
  const { limit = 20, offset = 0, search = "%%" } = params ?? {};
  const { data, loading, error, refetch } = useQuery(GET_EMPLOYEE_LIST, {
    variables: { limit, offset, search },
  });

  return {
    employees: data?.employee ?? [],
    total: data?.employee_aggregate?.aggregate?.count ?? 0,
    loading,
    error,
    refetch,
  };
}

export function useUpdateEmployeeGeneral() {
  const [mutate, { loading }] = useMutation(UPDATE_EMPLOYEE_GENERAL);
  return { mutate, loading };
}

export function useCreateEmployee() {
  const createEmployee = async (data: {
    fullName: string;
    email: string;
    phone?: string;
    employeeCode: string;
    designation: string;
    department: string;
    joiningDate: string;
    employeeCategory: string;
  }) => {
    const res = await api.post("/personal-education/employee", data);
    return res.data;
  };
  return { createEmployee };
}
