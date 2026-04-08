"use client";

import { useState } from "react";
import api from "@/lib/axios";
import { useQuery, skipToken } from "@apollo/client/react";
import { GET_FAMILY_MEMBERS } from "@/lib/graphql";
import type { FamilyMemberFormData } from "@/lib/validators/family.schema";

/** Form uses SPOUSE | CHILD | …; REST expects Prisma `FamilyRelation`. */
function mapRelationToApi(relation: FamilyMemberFormData["relation"]) {
  const m = {
    SPOUSE: "SPOUSE",
    CHILD: "SON",
    PARENT: "FATHER",
    SIBLING: "BROTHER",
    OTHER: "OTHER",
  } as const;
  type ApiRelation = (typeof m)[keyof typeof m];
  return (m[relation as keyof typeof m] ?? "OTHER") as ApiRelation;
}

export function useFamilyMembers(employeeId: string) {
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const parsedId = parseInt(employeeId, 10);
  const isValidId = Number.isFinite(parsedId) && parsedId > 0;

  const { data, loading, error, refetch } = useQuery<any>(
    GET_FAMILY_MEMBERS,
    isValidId ? { variables: { employeeId: parsedId } } : skipToken
  );

  const saveMember = async (member: FamilyMemberFormData) => {
    setSaving(true);
    setSaveError(null);
    try {
      const payload = {
        ...member,
        relation: mapRelationToApi(member.relation),
      };
      if (member.id) {
        await api.patch(
          `employees/${employeeId}/family/${member.id}`,
          payload
        );
      } else {
        await api.post(
          `employees/${employeeId}/family`,
          payload
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
