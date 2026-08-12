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
    const message = String(error.response?.data?.message ?? "");
    if (
      message.includes("Session expired") ||
      message.includes("logged in from another device") ||
      message.includes("Invalid or expired")
    ) {
      await signOut({ callbackUrl: "/login?reason=session" });
    }
    return Promise.reject(error);
  },
);

export default api;
