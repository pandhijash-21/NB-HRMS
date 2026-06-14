"use client";

import api from "@/lib/axios";

export type AccountCredentials = {
  userId: string;
  loginId: string | null;
  accountType: "ALIAS" | "EMPLOYEE" | "SYSTEM";
  isFirstLogin: boolean;
  password: string | null;
  passwordNote: string;
  canLogin: boolean;
};

export async function fetchUserCredentials(userId: string): Promise<AccountCredentials> {
  const { data } = await api.get(`admin/users/${userId}/credentials`);
  return data.data as AccountCredentials;
}

export async function resetUserPassword(
  userId: string,
  password?: string,
): Promise<{ loginId: string | null; password: string; message: string }> {
  const { data } = await api.post(`auth/reset-password/${userId}`, password ? { password } : {});
  return data.data;
}
