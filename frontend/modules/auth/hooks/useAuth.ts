"use client";

import { useMutation } from "@tanstack/react-query";
import api from "@/lib/axios";
import { signIn } from "next-auth/react";

export function useLogin() {
  return useMutation({
    mutationFn: async ({ employeeId, password }: any) => {
      const result = await signIn("credentials", {
        redirect: false,
        employeeId,
        password,
      });
      if (result?.error) {
        throw new Error(result.error);
      }
      return result;
    },
  });
}

export function useChangePassword() {
  return useMutation({
    mutationFn: async ({ currentPassword, newPassword }: any) => {
      const { data } = await api.post("auth/change-password", {
        currentPassword,
        newPassword,
      });
      return data;
    },
  });
}
