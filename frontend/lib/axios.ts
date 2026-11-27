"use client";

import axios from "axios";

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL ? 
    (process.env.NEXT_PUBLIC_API_URL.endsWith('/') ? process.env.NEXT_PUBLIC_API_URL : `${process.env.NEXT_PUBLIC_API_URL}/`) : 
    "http://localhost:4000/api/",
});

import { getSession, signOut } from "next-auth/react";

api.interceptors.request.use(async (config) => {
  if (typeof window !== "undefined") {
    const session = await getSession();
    const token = (session?.user as { token?: string })?.token || localStorage.getItem("hrms_token");
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (typeof window === "undefined" || error.response?.status !== 401) {
      return Promise.reject(error);
    }
    const session = await getSession();
    const hadToken =
      !!(session?.user as { token?: string })?.token || !!localStorage.getItem("hrms_token");
    if (!hadToken) {
      return Promise.reject(error);
    }
    const errorData = error.response?.data;
    const message = String(errorData?.message ?? errorData?.error ?? "");
    const isDisplaced =
      message.toLowerCase().includes("displaced") ||
      message.toLowerCase().includes("another device") ||
      message.toLowerCase().includes("another sign-in");

    if (
      isDisplaced ||
      message.includes("Session expired") ||
      message.includes("Invalid or expired")
    ) {
      try {
        localStorage.removeItem("hrms_token");
        sessionStorage.clear();
      } catch (_) {}
      await signOut({
        callbackUrl: isDisplaced ? "/login?reason=displaced" : "/login?reason=session",
      });
    }
    return Promise.reject(error);
  },
);

export default api;
