"use client";

import { useState } from "react";
import Link from "next/link";
import { useEmployeeList, useDeleteEmployee } from "@/lib/hooks/useEmployee";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { AddEmployeeDialog } from "@/components/employees/AddEmployeeDialog";
import { Trash2, MoreHorizontal, Eye } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

const PAGE_SIZE = 20;

const STATUS_COLORS: Record<string, string> = {
  ACTIVE: "bg-emerald-100 text-emerald-700",
  INACTIVE: "bg-slate-100 text-slate-500",
  ON_LEAVE: "bg-amber-100 text-amber-700",
  TERMINATED: "bg-rose-100 text-rose-600 border-rose-100",
  RESIGNED: "bg-rose-100 text-rose-600",
  RETIRED: "bg-purple-100 text-purple-600",
};

export default function EmployeeListPage() {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(0);

  const searchParam = search ? `%${search}%` : "%%";
  const { employees, total, loading, refetch } = useEmployeeList({
    limit: PAGE_SIZE,
    offset: page * PAGE_SIZE,
    search: searchParam,
  });

  const { deleteEmployee } = useDeleteEmployee();

  const handleDelete = async (id: number, name: string) => {
    if (confirm(`Are you sure you want to deactivate ${name}? This will also disable their user account.`)) {
      try {
        await deleteEmployee(id);
        refetch();
      } catch (err: any) {
        alert(err.message || "Failed to delete employee");
      }
    }
  };

  const totalPages = Math.ceil(total / PAGE_SIZE);

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="space-y-1">
          <h2 className="text-2xl font-bold text-[#1d3459] tracking-tight">Employee Directory</h2>
          <p className="text-xs text-slate-500 font-medium">Manage your institution's workforce ({total} total records)</p>
        </div>
        <div className="flex items-center gap-3">
          <Input
            placeholder="Search employees…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(0); }}
            className="w-64 text-sm bg-white border-slate-200 focus:ring-[#1d3459]"
          />
          <AddEmployeeDialog onEmployeeAdded={refetch} />
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-slate-100 shadow-xl shadow-slate-200/50 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-50 bg-[#1d3459]/[0.02]">
                <th className="text-left px-6 py-4 text-xs font-bold text-[#1d3459] uppercase tracking-wider">Employee</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-[#1d3459] uppercase tracking-wider hidden sm:table-cell">Designation & Dept</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-[#1d3459] uppercase tracking-wider hidden lg:table-cell">Joining Date</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-[#1d3459] uppercase tracking-wider">Status</th>
                <th className="text-right px-6 py-4 text-xs font-bold text-[#1d3459] uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {loading && Array.from({ length: 5 }).map((_, i) => (
                <tr key={i}>
                  <td className="px-6 py-4" colSpan={5}><Skeleton className="h-12 w-full rounded-lg" /></td>
                </tr>
              ))}

              {!loading && employees.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-6 py-20 text-center text-slate-400 italic">No employees found matching your criteria.</td>
                </tr>
              )}

              {!loading && employees.map((emp: any) => {
                const initials = emp.fullName.split(" ").map((n: string) => n[0]).join("").toUpperCase().slice(0, 2);
                return (
                  <tr key={emp.id} className="hover:bg-slate-50/80 transition-all group">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-4">
                        <Avatar className="h-10 w-10 shrink-0 border-2 border-white shadow-sm ring-1 ring-slate-100">
                          <AvatarImage src={emp.photoUrl} />
                          <AvatarFallback style={{ backgroundColor: "#1d3459", color: "#d9b557" }} className="text-xs font-bold">
                            {initials}
                          </AvatarFallback>
                        </Avatar>
                        <div className="space-y-0.5">
                          <p className="font-bold text-slate-800 text-sm group-hover:text-[#1d3459] transition-colors">{emp.fullName}</p>
                          <p className="text-[10px] text-slate-500 font-medium tracking-wide uppercase">{emp.employeeCode}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 hidden sm:table-cell">
                      <div className="space-y-0.5">
                        <p className="text-slate-700 text-xs font-semibold">{emp.designation}</p>
                        <p className="text-[10px] text-slate-400 font-medium">{emp.department}</p>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-slate-500 hidden lg:table-cell text-xs font-medium">
                      {emp.joiningDate ? new Date(emp.joiningDate).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—"}
                    </td>
                    <td className="px-6 py-4">
                      <Badge className={`text-[10px] px-2 py-0.5 border-none font-bold uppercase tracking-tight ${STATUS_COLORS[emp.status] ?? "bg-slate-100 text-slate-500"}`}>
                        {emp.status.replace("_", " ")}
                      </Badge>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <Link href={`/admin/employees/${emp.id}`}>
                          <Button size="sm" variant="ghost" className="h-8 w-8 p-0 text-slate-400 hover:text-[#1d3459] hover:bg-[#1d3459]/5">
                            <Eye className="h-4 w-4" />
                          </Button>
                        </Link>
                        
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button size="sm" variant="ghost" className="h-8 w-8 p-0 text-slate-400 hover:text-slate-600">
                              <MoreHorizontal className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end" className="w-40 border-slate-100 shadow-xl">
                            <DropdownMenuItem className="text-xs font-medium gap-2 cursor-pointer" onClick={() => window.location.href = `/admin/employees/${emp.id}`}>
                              <Eye className="h-3.5 w-3.5" /> View Details
                            </DropdownMenuItem>
                            <DropdownMenuItem 
                              className="text-xs font-medium gap-2 text-rose-600 focus:text-rose-600 cursor-pointer"
                              onClick={() => handleDelete(emp.id, emp.fullName)}
                              disabled={emp.status === 'TERMINATED'}
                            >
                              <Trash2 className="h-3.5 w-3.5" /> Deactivate
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <div className="flex items-center justify-between px-6 py-4 border-t border-slate-50 bg-slate-50/30">
            <p className="text-[10px] text-slate-500 font-bold uppercase tracking-wider">
              Showing {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, total)} of {total}
            </p>
            <div className="flex gap-2">
              <Button size="sm" variant="outline" disabled={page === 0} onClick={() => setPage((p) => p - 1)} className="text-[10px] h-8 font-bold uppercase border-slate-200">Previous</Button>
              <Button size="sm" variant="outline" disabled={page >= totalPages - 1} onClick={() => setPage((p) => p + 1)} className="text-[10px] h-8 font-bold uppercase border-slate-200">Next</Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
