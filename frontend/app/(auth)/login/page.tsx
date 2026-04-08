import { LoginForm } from "@/modules/auth/components/LoginForm";
import { Suspense } from "react";
import Image from "next/image";

export default function LoginPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-[#0f1f3a] via-[#1d3459] to-[#2a4a7b]">
      <div className="min-h-screen flex items-center justify-center px-4 py-10">
        <div className="w-full max-w-5xl">
          <div className="grid grid-cols-1 lg:grid-cols-2 overflow-hidden rounded-[2rem] border border-white/10 bg-white/5 backdrop-blur-2xl shadow-[0_20px_60px_rgba(0,0,0,0.35)]">
            {/* Left: Institutional panel */}
            <div className="relative p-10 lg:p-12">
              <div className="absolute inset-0 -z-10 bg-gradient-to-br from-white/10 via-transparent to-transparent" />

              <div className="flex items-center gap-5">
                <div className="relative h-20 w-20 overflow-hidden rounded-3xl bg-white/10 ring-1 ring-white/15">
                  <Image
                    src="/gu-logo.png"
                    alt="Gandhinagar University"
                    fill
                    sizes="80px"
                    className="object-contain p-3"
                    priority
                  />
                </div>
                <div>
                  <p className="text-white/95 text-2xl sm:text-3xl font-extrabold tracking-tight leading-none">
                    Gandhinagar University
                  </p>
                  <p className="mt-1 text-white/70 text-sm font-medium tracking-wide">
                    HRMS Portal
                  </p>
                </div>
              </div>

              <div className="mt-14">
                <h1 className="text-4xl font-extrabold tracking-tight text-white">
                  Sign in
                </h1>
                <p className="mt-3 text-sm text-white/65">
                  Staff & Faculty Access
                </p>
              </div>
            </div>

            {/* Right: Login card */}
            <div className="p-8 lg:p-12 bg-white/[0.03]">
              <div className="mx-auto w-full max-w-md">
                <div className="rounded-3xl bg-white/5 ring-1 ring-white/10 p-6 lg:p-8 shadow-[0_12px_40px_rgba(0,0,0,0.25)]">
                  <Suspense>
                    <LoginForm />
                  </Suspense>
                </div>

                <p className="mt-6 text-center text-xs text-white/40 tracking-wide">
                  &copy; {new Date().getFullYear()} Gandhinagar University
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
