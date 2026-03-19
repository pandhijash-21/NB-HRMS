"use client";

import { useState } from "react";
import Link from "next/link";
import { useEmployeeList } from "@/lib/hooks/useEmployee";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";

const PAGE_SIZE = 20;

const STATUS_COLORS: Record<string, string> = {
  ACTIVE: "bg-emerald-100 text-emerald-700",
  INACTIVE: "bg-slate-100 text-slate-500",
  ON_LEAVE: "bg-amber-100 text-amber-700",
  TERMINATED: "bg-rose-100 text-rose-600",
  RETIRED: "bg-purple-100 text-purple-600",
};

export default function EmployeeListPage() {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(0);

  const searchParam = search ? `%${search}%` : "%%";
  const { employees, total, loading } = useEmployeeList({
    limit: PAGE_SIZE,
    offset: page * PAGE_SIZE,
    search: searchParam,
  });

  const totalPages = Math.ceil(total / PAGE_SIZE);

  return (
    <div className="space-y-5">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h2 className="text-lg font-bold text-slate-800">Employees</h2>
          <p className="text-xs text-slate-500">{total} total</p>
        </div>
        <Input
          placeholder="Search by name, code or email…"
          value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(0); }}
          className="w-64 text-sm"
        />
      </div>

      <div className="bg-white rounded-xl border border-slate-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50">
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Employee</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider hidden sm:table-cell">Designation</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider hidden md:table-cell">Department</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider hidden lg:table-cell">Joining Date</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Status</th>
                <th className="text-right px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wider">Action</th>
              </tr>
            </thead>
            <tbody>
              {loading && Array.from({ length: 8 }).map((_, i) => (
                <tr key={i} className="border-b border-slate-50">
                  <td className="px-4 py-3" colSpan={6}><Skeleton className="h-8 w-full" /></td>
                </tr>
              ))}

              {!loading && employees.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-12 text-center text-sm text-slate-400">No employees found.</td>
                </tr>
              )}

              {!loading && employees.map((emp: {
                id: string; fullName: string; employeeCode: string; email: string;
                photoUrl?: string; designation: string; department: string;
                joiningDate: string; status: string;
              }) => {
                const initials = emp.fullName.split(" ").map((n) => n[0]).join("").toUpperCase().slice(0, 2);
                return (
                  <tr key={emp.id} className="border-b border-slate-50 hover:bg-slate-50/50 transition-colors">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <Avatar className="h-8 w-8 shrink-0">
                          <AvatarImage src={emp.photoUrl} />
                          <AvatarFallback style={{ backgroundColor: "#1d3459", color: "#d9b557" }} className="text-xs font-bold">
                            {initials}
                          </AvatarFallback>
                        </Avatar>
                        <div>
                          <p className="font-medium text-slate-800 text-sm">{emp.fullName}</p>
                          <p className="text-xs text-slate-400">{emp.employeeCode}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-slate-600 hidden sm:table-cell text-xs">{emp.designation}</td>
                    <td className="px-4 py-3 text-slate-600 hidden md:table-cell text-xs">{emp.department}</td>
                    <td className="px-4 py-3 text-slate-500 hidden lg:table-cell text-xs">
                      {emp.joiningDate ? new Date(emp.joiningDate).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—"}
                    </td>
                    <td className="px-4 py-3">
                      <Badge className={`text-xs ${STATUS_COLORS[emp.status] ?? "bg-slate-100 text-slate-500"}`}>
                        {emp.status.replace("_", " ")}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Link href={`/admin/employees/${emp.id}`} className="text-xs px-3 py-1.5 rounded border border-[#1d3459] text-[#1d3459] hover:bg-[#1d3459] hover:text-white transition-colors">
                        View
                      </Link>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-slate-100">
            <p className="text-xs text-slate-500">
              Showing {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, total)} of {total}
            </p>
            <div className="flex gap-2">
              <Button size="sm" variant="outline" disabled={page === 0} onClick={() => setPage((p) => p - 1)} className="text-xs">Previous</Button>
              <Button size="sm" variant="outline" disabled={page >= totalPages - 1} onClick={() => setPage((p) => p + 1)} className="text-xs">Next</Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
