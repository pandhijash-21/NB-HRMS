"use client";

import { useState } from "react";
import { useQuery, useMutation as useApolloMutation } from "@apollo/client/react";
import { GET_EXPERIENCES, UPSERT_EXPERIENCE, DELETE_EXPERIENCE } from "@/lib/graphql/experience.gql";
import type { ExperienceFormData } from "@/lib/validators/experience.schema";

export function useExperiences(employeeId: string) {
  const [saving, setSaving] = useState(false);

  const parsedId = parseInt(employeeId, 10);
  const isValidId = !Number.isNaN(parsedId);

  const { data, loading, error, refetch } = useQuery<any>(
    GET_EXPERIENCES,
    {
      variables: { employeeId: parsedId },
      skip: !isValidId,
    }
  );

  const [upsertExperience] = useApolloMutation(UPSERT_EXPERIENCE);
  const [deleteExperience] = useApolloMutation(DELETE_EXPERIENCE);

  const saveExperience = async (exp: ExperienceFormData) => {
    setSaving(true);
    try {
      const expData = {
        employeeId: parseInt(employeeId),
        type: exp.type,
        designation: exp.designation,
        organizationName: exp.organizationName,
        fromDate: exp.fromDate,
        toDate: exp.toDate,
        jobDescription: exp.jobDescription || null,
        lastSalary: exp.lastSalary || null,
        experienceLetterUrl: exp.experienceLetterUrl || null,
        lastPaycheckUrl: exp.lastPaycheckUrl || null,
        recommendationLetters: exp.recommendationLetters || [],
      };

      if (exp.id) {
        await upsertExperience({
          variables: {
            employeeId: parseInt(employeeId),
            objects: [{ ...expData, id: exp.id }],
          },
        });
      } else {
        await upsertExperience({
          variables: {
            employeeId: parseInt(employeeId),
            objects: [expData],
          },
        });
      }
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
