"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import api from "@/lib/axios";
import { useAdminEmployeeList } from "@/modules/admin/hooks/useAdminEmployees";
import { useAllChangeRequests } from "@/lib/hooks/useApprovals";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

function StatCard({
  label,
  value,
  icon,
  href,
  accent,
  loading,
}: {
  label: string;
  value: string | number;
  icon: React.ReactNode;
  href?: string;
  accent?: string;
  loading?: boolean;
}) {
  const content = (
    <Card className="hover:shadow-md transition-shadow">
      <CardContent className="pt-5 pb-4">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-xs text-slate-500 mb-1">{label}</p>
            {loading ? (
              <Skeleton className="h-8 w-16 mt-1" />
            ) : (
              <p className="text-2xl font-bold" style={{ color: accent ?? "#1d3459" }}>
                {value}
              </p>
            )}
          </div>
          <div
            className="h-10 w-10 rounded-lg flex items-center justify-center"
            style={{ backgroundColor: "#1d3459", color: "#d9b557" }}
          >
            {icon}
          </div>
        </div>
      </CardContent>
    </Card>
  );
  return href ? <Link href={href}>{content}</Link> : content;
}

export default function DashboardPage() {
  // Employees list for total, active, departments
  const { data: employeeData, isLoading: empLoading } = useAdminEmployeeList({ page: 0, limit: 1000 });

  // Pending change requests count
  const { data: pendingRequests, isLoading: approvalLoading } = useAllChangeRequests("PENDING");

  // Recent employees (latest 5)
  const { data: recentData, isLoading: recentLoading } = useAdminEmployeeList({ page: 0, limit: 5 });

  const employees = employeeData?.items ?? [];
  const total = employeeData?.total ?? 0;
  const activeCount = employees.filter((e: any) => e.status === "ACTIVE").length;

  // Distinct departments from generalInfo.department
  const departments = new Set(
    employees.map((e: any) => e.generalInfo?.department).filter(Boolean)
  ).size;

  const pendingCount = pendingRequests?.length ?? 0;
  const recentEmployees = recentData?.items ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-bold text-slate-800">Dashboard</h2>
        <p className="text-xs text-slate-500">Overview of the HR system</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Total Employees"
          value={total}
          loading={empLoading}
          href="/admin/employees"
          icon={
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
              <circle cx="9" cy="7" r="4" />
              <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
              <path d="M16 3.13a4 4 0 0 1 0 7.75" />
            </svg>
          }
        />
        <StatCard
          label="Active"
          value={activeCount}
          loading={empLoading}
          accent="#16a34a"
          icon={
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5">
              <polyline points="20 6 9 17 4 12" />
            </svg>
          }
        />
        <StatCard
          label="Departments"
          value={departments || "—"}
          loading={empLoading}
          icon={
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5">
              <rect x="2" y="7" width="20" height="14" rx="2" />
              <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16" />
            </svg>
          }
        />
        <StatCard
          label="Pending Actions"
          value={pendingCount}
          loading={approvalLoading}
          accent="#d97706"
          href="/admin/approvals"
          icon={
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
          }
        />
      </div>

      <Card>
        <CardContent className="pt-5">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-slate-700">Recent Employees</h3>
            <Link href="/admin/employees" className="text-xs text-[#1d3459] hover:underline">
              View all →
            </Link>
          </div>

          {recentLoading ? (
            <div className="space-y-3">
              {Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-10 w-full" />)}
            </div>
          ) : recentEmployees.length === 0 ? (
            <p className="text-sm text-slate-400 text-center py-6">No employees yet.</p>
          ) : (
            <div className="space-y-2">
              {recentEmployees.map((emp: any) => (
                <Link
                  key={emp.id}
                  href={`/admin/employees/${emp.id}`}
                  className="flex items-center justify-between px-3 py-2 rounded-lg hover:bg-slate-50 transition-colors group"
                >
                  <div>
                    <p className="text-sm font-medium text-slate-700 group-hover:text-[#1d3459]">
                      {emp.generalInfo?.fullName ?? `Employee #${emp.id}`}
                    </p>
                    <p className="text-xs text-slate-400">
                      {emp.generalInfo?.employeeCode ?? "—"} · {emp.generalInfo?.designation ?? "—"}
                    </p>
                  </div>
                  <span className="text-xs text-slate-400 group-hover:text-[#1d3459]">→</span>
                </Link>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
