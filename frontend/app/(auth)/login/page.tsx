import { Suspense } from "react";
import LoginForm from "@/app/(auth)/login/login-form";

export default function LoginPage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#1d3459] to-[#243b63]">
      <div className="w-full max-w-md mx-4">
        {/* Glass Card */}
        <div className="relative rounded-3xl bg-white/5 backdrop-blur-2xl border border-white/10 shadow-[0_8px_32px_0_rgba(0,0,0,0.3)] px-8 py-12 overflow-hidden before:absolute before:inset-0 before:-z-10 before:bg-gradient-to-b before:from-white/10 before:to-transparent before:opacity-50">
          {/* Brand */}
          <div className="mb-10 text-center">
            <div
              className="inline-flex items-center justify-center w-16 h-16 rounded-2xl mb-5 bg-white/10 border border-white/20 shadow-inner backdrop-blur-md"
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
            <h1 className="text-2xl font-bold text-white tracking-wide">
              HRMS Portal
            </h1>
            <p className="mt-2 text-xs text-white/60 font-medium tracking-wide">
              GANDHINAGAR UNIVERSITY
            </p>
          </div>

          <Suspense>
            <LoginForm />
          </Suspense>
        </div>

        <p className="mt-6 text-center text-xs text-white/40 tracking-wider font-light">
          &copy; {new Date().getFullYear()} Gandhinagar University
        </p>
      </div>
    </div>
  );
}
