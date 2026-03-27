"use client";

import { useState } from "react";
import api from "@/lib/axios";
import { useQuery } from "@apollo/client/react";
import { GET_FAMILY_MEMBERS } from "@/lib/graphql";
import type { FamilyMemberFormData } from "@/lib/validators/family.schema";

export function useFamilyMembers(employeeId: string) {
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const { data, loading, error, refetch } = useQuery<any>(GET_FAMILY_MEMBERS, {
    variables: { employeeId },
    skip: !employeeId,
  });

  const saveMember = async (member: FamilyMemberFormData) => {
    setSaving(true);
    setSaveError(null);
    try {
      if (member.id) {
        await api.patch(
          `employees/${employeeId}/family/${member.id}`,
          member
        );
      } else {
        await api.post(
          `employees/${employeeId}/family`,
          member
        );
      }
      refetch();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Failed to save";
      setSaveError(msg);
      throw e;
    } finally {
      setSaving(false);
    }
  };

  const deleteMember = async (id: string) => {
    setSaving(true);
    try {
      await api.delete(
        `employees/${employeeId}/family/${id}`
      );
      refetch();
    } finally {
      setSaving(false);
    }
  };

  return {
    members: data?.employee_family ?? [],
    loading,
    error,
    saving,
    saveError,
    saveMember,
    deleteMember,
    refetch,
  };
}
