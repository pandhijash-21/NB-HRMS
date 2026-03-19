"use client";

import { useState } from "react";
import api from "@/lib/axios";
import { useQuery } from "@apollo/client/react";
import { GET_ACADEMIC_QUALIFICATIONS } from "@/lib/graphql";
import type { AcademicQualFormData } from "@/lib/validators/academic.schema";

export function useAcademicQuals(employeeId: string) {
  const [saving, setSaving] = useState(false);

  const { data, loading, error, refetch } = useQuery(
    GET_ACADEMIC_QUALIFICATIONS,
    {
      variables: { employeeId },
      skip: !employeeId,
    }
  );

  const saveQualification = async (qual: AcademicQualFormData) => {
    setSaving(true);
    try {
      if (qual.id) {
        await api.put(
          `/personal-education/employees/${employeeId}/academic/${qual.id}`,
          qual
        );
      } else {
        await api.post(
          `/personal-education/employees/${employeeId}/academic`,
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
        `/personal-education/employees/${employeeId}/academic/${id}`
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
