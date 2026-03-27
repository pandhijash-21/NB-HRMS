"use client";

import { useState } from "react";
import api from "@/lib/axios";
import type { PersonalInfoFormData } from "@/lib/validators/personalInfo.schema";

export function usePersonalInfo(employeeId: string) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getPersonalInfo = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get(`employees/${employeeId}/personal`);
      return res.data.data;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Failed to load personal info";
      setError(msg);
      return null;
    } finally {
      setLoading(false);
    }
  };

  const savePersonalInfo = async (data: PersonalInfoFormData) => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.patch(
        `employees/${employeeId}/personal`,
        data
      );
      return res.data.data;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Failed to save personal info";
      setError(msg);
      throw e;
    } finally {
      setLoading(false);
    }
  };

  return { getPersonalInfo, savePersonalInfo, loading, error };
}
