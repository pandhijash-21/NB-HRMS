"use client";

import { useEffect } from "react";
import { useSession } from "next-auth/react";
import { useRouter } from "next/navigation";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import Link from "next/link";

const APPROVER_ROLES = ["HOD", "HOI", "REGISTRAR", "VC"];

export default function EmployeeDashboard() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const role = (session?.user as any)?.role ?? "";
  const userName = session?.user?.name ?? "Employee";

  useEffect(() => {
    if (status === "authenticated" && APPROVER_ROLES.includes(role)) {
      router.replace("/approvals");
    }
  }, [status, role, router]);

  if (status === "loading" || (status === "authenticated" && APPROVER_ROLES.includes(role))) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-48" />
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Skeleton className="h-32 w-full" />
          <Skeleton className="h-32 w-full" />
          <Skeleton className="h-32 w-full" />
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-in fade-in duration-700">
      {/* Welcome Header */}
      <div className="flex flex-col gap-1">
        <h1 className="text-2xl font-bold text-slate-900 tracking-tight">
          Welcome back, <span style={{ color: "#1d3459" }}>{userName}</span>! 👋
        </h1>
        <p className="text-sm text-slate-500 font-light">
          Here's what's happening with your profile today.
        </p>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card className="border-none shadow-sm bg-gradient-to-br from-white to-slate-50 hover:shadow-md transition-all duration-300">
          <CardContent className="pt-6">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  Profile Status
                </p>
                <div className="flex items-center gap-2">
                  <span className="h-2 w-2 rounded-full bg-emerald-500" />
                  <p className="text-lg font-bold text-slate-700">Complete</p>
                </div>
              </div>
              <div className="p-2 rounded-xl bg-emerald-50 text-emerald-600">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5">
                   <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
                   <polyline points="22 4 12 14.01 9 11.01" />
                </svg>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="border-none shadow-sm bg-gradient-to-br from-white to-slate-50 hover:shadow-md transition-all duration-300">
          <CardContent className="pt-6">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  My Role
                </p>
                <p className="text-lg font-bold text-slate-700">{session?.user?.role ?? "Employee"}</p>
              </div>
              <div className="p-2 rounded-xl bg-blue-50 text-blue-600">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5">
                   <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                   <circle cx="9" cy="7" r="4" />
                </svg>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="border-none shadow-sm bg-gradient-to-br from-white to-slate-50 hover:shadow-md transition-all duration-300">
          <CardContent className="pt-6">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  ID Number
                </p>
                <p className="text-lg font-bold text-slate-700">#{session?.user?.employeeId ?? "—"}</p>
              </div>
              <div className="p-2 rounded-xl bg-amber-50 text-amber-600">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5">
                   <rect x="3" y="4" width="18" height="16" rx="2" />
                   <line x1="7" y1="8" x2="17" y2="8" />
                   <line x1="7" y1="12" x2="17" y2="12" />
                   <line x1="7" y1="16" x2="12" y2="16" />
                </svg>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Main Content Areas */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Quick Links */}
        <div className="space-y-4">
          <h3 className="text-sm font-semibold text-slate-800 flex items-center gap-2">
            <span className="h-4 w-1 bg-[#d9b557] rounded-full" />
            Quick Actions
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
             <Link href="/profile" className="group">
               <div className="p-4 rounded-2xl border border-slate-100 bg-white hover:border-[#1d3459]/20 hover:bg-slate-50 transition-all duration-200">
                 <p className="text-sm font-medium text-slate-700 group-hover:text-[#1d3459]">View Profile</p>
                 <p className="text-xs text-slate-400 mt-0.5">Check your personal details</p>
               </div>
             </Link>
             <Link href="/profile/edit" className="group">
               <div className="p-4 rounded-2xl border border-slate-100 bg-white hover:border-[#1d3459]/20 hover:bg-slate-50 transition-all duration-200">
                 <p className="text-sm font-medium text-slate-700 group-hover:text-[#1d3459]">Update Info</p>
                 <p className="text-xs text-slate-400 mt-0.5">Edit contact and personal data</p>
               </div>
             </Link>
          </div>
        </div>

        {/* System Info */}
        <div className="space-y-4">
          <h3 className="text-sm font-semibold text-slate-800 flex items-center gap-2">
            <span className="h-4 w-1 bg-[#1d3459] rounded-full" />
            Important Notice
          </h3>
          <div className="p-5 rounded-2xl bg-[#1d3459] text-white shadow-lg overflow-hidden relative">
            <div className="relative z-10">
              <p className="text-sm font-semibold mb-2">Welcome to the New Portal!</p>
              <p className="text-xs text-slate-200 leading-relaxed font-light">
                We've updated our HRMS to serve you better. You now have a dedicated dashboard to manage your activities. Please keep your profile up to date for official communications.
              </p>
            </div>
            {/* Abstract Background Shape */}
            <div className="absolute -bottom-8 -right-8 w-32 h-32 rounded-full bg-white/10 blur-2xl" />
            <div className="absolute -top-4 -left-4 w-24 h-24 rounded-full bg-[#d9b557]/20 blur-xl" />
          </div>
        </div>
      </div>
    </div>
  );
}
