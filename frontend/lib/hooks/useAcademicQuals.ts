"use client";

import { useState } from "react";
import api from "@/lib/axios";
import { useQuery, skipToken } from "@apollo/client/react";
import { GET_ACADEMIC_QUALIFICATIONS } from "@/lib/graphql";
import type { AcademicQualFormData } from "@/lib/validators/academic.schema";

export function useAcademicQuals(employeeId: string) {
  const [saving, setSaving] = useState(false);

  const parsedId = parseInt(employeeId, 10);
  const isValidId = Number.isFinite(parsedId) && parsedId > 0;

  const { data, loading, error, refetch } = useQuery<any>(
    GET_ACADEMIC_QUALIFICATIONS,
    isValidId ? { variables: { employeeId: parsedId } } : skipToken
  );

  const saveQualification = async (qual: AcademicQualFormData) => {
    setSaving(true);
    try {
      if (qual.id) {
        await api.patch(
          `employees/${employeeId}/academic/${qual.id}`,
          qual
        );
      } else {
        await api.post(
          `employees/${employeeId}/academic`,
          qual
        );
      }
      refetch();
    } finally {
      setSaving(false);
    }
  };

  const deleteQualification = async (id: string) => {
    setSaving(true);
    try {
      await api.delete(
        `employees/${employeeId}/academic/${id}`
      );
      refetch();
    } finally {
      setSaving(false);
    }
  };

  return {
    qualifications: data?.employee_academic_qualification ?? [],
    loading,
    error,
    saving,
    saveQualification,
    deleteQualification,
    refetch,
  };
}
