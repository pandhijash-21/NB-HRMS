"use client";

import { useState } from "react";
import { useQuery, useMutation as useApolloMutation, skipToken } from "@apollo/client/react";
import { GET_EXPERIENCES, UPSERT_EXPERIENCE, DELETE_EXPERIENCE } from "@/lib/graphql/experience.gql";
import type { ExperienceFormData } from "@/lib/validators/experience.schema";

export function useExperiences(employeeId: string) {
  const [saving, setSaving] = useState(false);

  const parsedId = parseInt(employeeId, 10);
  const isValidId = Number.isFinite(parsedId) && parsedId > 0;

  const { data, loading, error, refetch } = useQuery<any>(
    GET_EXPERIENCES,
    isValidId ? { variables: { employeeId: parsedId } } : skipToken
  );

  const [upsertExperience] = useApolloMutation(UPSERT_EXPERIENCE);
  const [deleteExperience] = useApolloMutation(DELETE_EXPERIENCE);

  const saveExperience = async (exp: ExperienceFormData) => {
    if (!isValidId) return;
    setSaving(true);
    try {
      // Hasura insert_input uses DB column names (snake_case) for this table.
      // PK has no DB default: Prisma @default(uuid()) does not run for GraphQL inserts — generate id here.
      const now = new Date().toISOString();
      const expData = {
        employee_id: parsedId,
        type: exp.type,
        designation: exp.designation,
        organization_name: exp.organizationName,
        from_date: exp.fromDate,
        to_date: exp.toDate,
        job_description: exp.jobDescription || null,
        last_salary: exp.lastSalary ?? null,
        experience_letter_url: exp.experienceLetterUrl || null,
        last_paycheck_url: exp.lastPaycheckUrl || null,
        recommendation_letters: exp.recommendationLetters ?? [],
        updated_at: now,
      };

      const rowId = exp.id ?? crypto.randomUUID();
      await upsertExperience({
        variables: { objects: [{ ...expData, id: rowId, created_at: now }] },
      });
      refetch();
    } finally {
      setSaving(false);
    }
  };

  const deleteExp = async (id: string) => {
    setSaving(true);
    try {
      await deleteExperience({
        variables: { id },
      });
      refetch();
    } finally {
      setSaving(false);
    }
  };

  return {
    experiences: data?.employee_experience ?? [],
    loading,
    error,
    saving,
    saveExperience,
    deleteExperience: deleteExp,
    refetch,
  };
}
