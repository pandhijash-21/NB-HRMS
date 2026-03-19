"use client";

import Link from "next/link";
import { useEmployeeList } from "@/lib/hooks/useEmployee";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

function StatCard({
  label,
  value,
  icon,
  href,
  accent,
}: {
  label: string;
  value: string | number;
  icon: React.ReactNode;
  href?: string;
  accent?: string;
}) {
  const content = (
    <Card className="hover:shadow-md transition-shadow">
      <CardContent className="pt-5 pb-4">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-xs text-slate-500 mb-1">{label}</p>
            <p className="text-2xl font-bold" style={{ color: accent ?? "#1d3459" }}>
              {value}
            </p>
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
  const { employees, total, loading } = useEmployeeList({ limit: 5 });
  const activeCount = employees.filter((e: { status: string }) => e.status === "ACTIVE").length;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-bold text-slate-800">Dashboard</h2>
        <p className="text-xs text-slate-500">Overview of the HR system</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Total Employees"
          value={loading ? "—" : total}
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
          value={loading ? "—" : activeCount}
          accent="#16a34a"
          icon={
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5">
              <polyline points="20 6 9 17 4 12" />
            </svg>
          }
        />
        <StatCard
          label="Departments"
          value="—"
          icon={
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5">
              <rect x="2" y="7" width="20" height="14" rx="2" />
              <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16" />
            </svg>
          }
        />
        <StatCard
          label="Pending Actions"
          value="—"
          accent="#d97706"
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

          {loading ? (
            <div className="space-y-3">
              {Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-10 w-full" />)}
            </div>
          ) : employees.length === 0 ? (
            <p className="text-sm text-slate-400 text-center py-6">No employees yet.</p>
          ) : (
            <div className="space-y-2">
              {employees.map((emp: { id: string; fullName: string; employeeCode: string; designation: string }) => (
                <Link
                  key={emp.id}
                  href={`/admin/employees/${emp.id}`}
                  className="flex items-center justify-between px-3 py-2 rounded-lg hover:bg-slate-50 transition-colors group"
                >
                  <div>
                    <p className="text-sm font-medium text-slate-700 group-hover:text-[#1d3459]">{emp.fullName}</p>
                    <p className="text-xs text-slate-400">{emp.employeeCode} · {emp.designation}</p>
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
