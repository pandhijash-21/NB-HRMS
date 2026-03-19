import { Suspense } from "react";
import LoginForm from "@/app/(auth)/login/login-form";

export default function LoginPage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#1d3459] to-[#243b63]">
      <div className="w-full max-w-md mx-4">
        {/* Card */}
        <div className="rounded-2xl bg-white shadow-2xl px-8 py-10">
          {/* Brand */}
          <div className="mb-8 text-center">
            <div
              className="inline-flex items-center justify-center w-14 h-14 rounded-2xl mb-4"
              style={{ backgroundColor: "#1d3459" }}
            >
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="#d9b557"
                strokeWidth={2}
                className="w-7 h-7"
              >
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                <path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </div>
            <h1
              className="text-xl font-bold"
              style={{ color: "#1d3459" }}
            >
              HRMS Portal
            </h1>
            <p className="mt-1 text-xs text-slate-500">
              Gandhinagar University · Human Resource Management
            </p>
          </div>

          <Suspense>
            <LoginForm />
          </Suspense>
        </div>

        <p className="mt-4 text-center text-xs text-slate-300">
          &copy; {new Date().getFullYear()} Gandhinagar University · All rights reserved
        </p>
      </div>
    </div>
  );
}
