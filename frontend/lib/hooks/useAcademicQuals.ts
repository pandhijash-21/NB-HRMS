"use client";

import { useState } from "react";
import api from "@/lib/axios";
import { useQuery, skipToken } from "@apollo/client/react";
import { GET_ACADEMIC_QUALIFICATIONS } from "@/lib/graphql";
import { getEffectiveAcademicLevel, type AcademicQualFormData } from "@/lib/validators/academic.schema";

/** Maps profile form (`level`, `institution`, …) to REST API / Prisma (`degreeType`, `boardUniversity`, …). */
function mapAcademicFormToRestPayload(
  qual: AcademicQualFormData & { semMarksheetUrls?: string[] },
  opts: { includeIdForCreate?: boolean }
) {
  const levelToDegree: Record<
    string,
    "SSC" | "HSC" | "DIPLOMA" | "BACHELOR" | "MASTER" | "PHD"
  > = {
    SSC: "SSC",
    HSC: "HSC",
    DIPLOMA: "DIPLOMA",
    UG: "BACHELOR",
    PG: "MASTER",
    PHD: "PHD",
    OTHER: "PHD",
  };

  const eff = getEffectiveAcademicLevel(qual);
  const degreeType = levelToDegree[eff] ?? "BACHELOR";
  const sem = qual.semMarksheetUrls ?? [];

  const payload: Record<string, unknown> = {
    degreeType,
    degreeName: qual.degreeName?.trim() || null,
    medium: qual.medium ?? "ENGLISH",
    boardUniversity: qual.institution?.trim() || "",
    schoolCollege: (qual.schoolCollege ?? "").trim() || "",
    passingYear: qual.passingYear,
    percentage: qual.percentage ?? null,
    grade: qual.cgpa != null ? String(qual.cgpa) : null,
    specialization: (qual.hscStream ?? qual.stream ?? null) as string | null,
    certificateUrl: qual.certificateUrl || null,
  };

  if (eff === "SSC" || eff === "HSC") {
    if (qual.marksheetUrl) payload.sem1MarksheetUrl = qual.marksheetUrl;
  }

  for (let i = 0; i < 8; i++) {
    const u = sem[i];
    if (u) payload[`sem${i + 1}MarksheetUrl`] = u;
  }

  if (opts.includeIdForCreate && qual.id) payload.id = qual.id;

  return payload;
}

export function useAcademicQuals(employeeId: string) {
  const [saving, setSaving] = useState(false);

  const parsedId = parseInt(employeeId, 10);
  const isValidId = Number.isFinite(parsedId) && parsedId > 0;

  const { data, loading, error, refetch } = useQuery<any>(
    GET_ACADEMIC_QUALIFICATIONS,
    isValidId ? { variables: { employeeId: parsedId } } : skipToken
  );

  const saveQualification = async (qual: AcademicQualFormData & { semMarksheetUrls?: string[] }) => {
    setSaving(true);
    try {
      if (qual.id) {
        const body = mapAcademicFormToRestPayload(qual, { includeIdForCreate: false });
        await api.patch(`employees/${employeeId}/academic/${qual.id}`, body);
      } else {
        const body = mapAcademicFormToRestPayload(qual, { includeIdForCreate: true });
        await api.post(`employees/${employeeId}/academic`, body);
      }
      refetch();
    } finally {
      setSaving(false);
    }
  };

  const deleteQualification = async (id: string) => {
    setSaving(true);
    try {
      await api.delete(`employees/${employeeId}/academic/${id}`);
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
