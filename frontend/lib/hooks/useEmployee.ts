"use client";

import { useQuery, useMutation } from "@apollo/client/react";
import { GET_EMPLOYEE, UPDATE_EMPLOYEE_GENERAL, GET_EMPLOYEE_LIST } from "@/lib/graphql";
import api from "@/lib/axios";

export function useEmployee(id?: string | number) {
  const numericId = id ? (typeof id === 'string' ? parseInt(id, 10) : id) : undefined;
  
  const { data, loading, error, refetch } = useQuery<any>(GET_EMPLOYEE, {
    variables: { id: numericId },
    skip: !numericId,
  });

  const emp = data?.employees?.[0];
  
  let flatEmployee = null;
  if (emp) {
    const addresses = emp.employee_addresses?.[0] || {};
    const gen = emp.employee_general_infos?.[0] || {};
    const personal = emp.employee_personal_infos?.[0] || {};
    const other = emp.employee_other_infos?.[0] || {};
    const salary = emp.employee_salary_infos?.[0] || {};
    const bank = emp.employee_bank_infos?.[0] || {};
    
    flatEmployee = {
      id: emp.id,
      employeeCode: `EMP-${emp.id.toString().padStart(4, '0')}`,
      status: emp.status,
      photoUrl: emp.photoUrl,
      signatureUrl: emp.signatureUrl,
      updatedAt: emp.updatedAt,
      email: addresses.instituteEmail || addresses.personalEmail || "user@example.com",
      phone: addresses.mobileNo || "",
      ...gen,
      ...personal,
      ...salary,
      ...bank,
      ...other,
      ...addresses,
    };
  }

  return {
    employee: flatEmployee,
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
  const { limit = 20, offset = 0, search } = params ?? {};
  
  const where = search && search !== "%%" ? {
    _or: [
      { employee_general_infos: { full_name: { _ilike: search } } },
      { abbreviation: { _ilike: search } },
      { employee_addresses: { personal_email: { _ilike: search } } },
      { employee_addresses: { institute_email: { _ilike: search } } },
      { employee_general_infos: { designation: { _ilike: search } } },
    ]
  } : {};

  const { data, loading, error, refetch } = useQuery<any>(GET_EMPLOYEE_LIST, {
    variables: { limit, offset, where },
  });

  return {
    employees: (data?.employees ?? []).map((e: any) => {
      const gen = e.employee_general_infos?.[0] || {};
      const addr = e.employee_addresses?.[0] || {};
      return {
        id: e.id,
        employeeCode: `EMP-${e.id.toString().padStart(4, '0')}`,
        fullName: gen.full_name || "Unknown",
        email: addr.institute_email || addr.personal_email || "user@example.com",
        phone: addr.mobile_no || "",
        photoUrl: e.photo_url,
        designation: gen.designation || "",
        department: gen.department || "",
        status: e.status || "ACTIVE",
        joiningDate: gen.joining_date || "",
        employeeCategory: gen.employee_category || "TEACHING",
      };
    }),
    total: data?.employees_aggregate?.aggregate?.count ?? 0,
    activeCount: data?.active_aggregate?.aggregate?.count ?? 0,
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
    designation: string;
    department: string;
    joiningDate: string;
    employeeCategory: string;
    employeeCode: string;
  }) => {
    const res = await api.post("employees/full", data);
    return res.data;
  };
  return { createEmployee };
}

export function useDeleteEmployee() {
  const deleteEmployee = async (id: number) => {
    const res = await api.delete(`employees/${id}`);
    return res.data;
  };
  return { deleteEmployee };
}
