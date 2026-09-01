"use client";

import { useState } from "react";
import LinkInstance from "next/link";
import { useSession } from "next-auth/react";
import { useAdminEmployeeList, useDeleteEmployee } from "@/modules/admin/hooks/useAdminEmployees";
import { canEditWorkforce } from "@/lib/auth/permissions";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { PhotoLightbox } from "@/components/ui/photo-lightbox";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { AddEmployeeDialog } from "@/components/employees/AddEmployeeDialog";
import { CreatePositionDialog } from "@/components/employees/CreatePositionDialog";
import { PositionsOverview } from "@/components/employees/PositionsOverview";
import { formatEmployeePosition } from "@/components/employees/EmployeePositionSelect";
import { Trash2, MoreHorizontal, Eye, Search, Filter, ChevronLeft, ChevronRight } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

const PAGE_SIZE = 10;

const STATUS_COLORS: Record<string, string> = {
  ACTIVE: "bg-emerald-100/50 text-emerald-700 border-emerald-200/50",
  INACTIVE: "bg-slate-100 text-slate-500 border-slate-200",
  ON_LEAVE: "bg-amber-100/50 text-amber-700 border-amber-200/50",
  TERMINATED: "bg-rose-100/50 text-rose-600 border-rose-200/50",
  RESIGNED: "bg-rose-100/50 text-rose-600 border-rose-200/50",
  RETIRED: "bg-purple-100/50 text-purple-600 border-purple-200/50",
};

export default function EmployeeListPage() {
  const { data: session } = useSession();
  const su = session?.user as { permissions?: Record<string, string[]>; employeeViewScope?: string };

  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<string>("ALL");
  const [page, setPage] = useState(0);

  const { data, isLoading } = useAdminEmployeeList({
    page,
    limit: PAGE_SIZE,
    search: search || undefined,
    status: status === "ALL" ? undefined : status,
  });

  const canEdit = canEditWorkforce(su?.permissions, su?.employeeViewScope);
  const viewScope = su?.employeeViewScope ?? (data as { viewScope?: string })?.viewScope ?? "UNIVERSITY";

  const deleteMutation = useDeleteEmployee();

  const handleDelete = (id: number, name: string) => {
    if (confirm(`Are you sure you want to deactivate ${name}? This will also disable their user account.`)) {
      deleteMutation.mutate(id);
    }
  };

  const totalPages = data ? Math.ceil(data.total / PAGE_SIZE) : 0;

  return (
    <div className="space-y-8 animate-in fade-in duration-500 max-w-[1400px] mx-auto p-4 md:p-8">
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div className="space-y-1.5">
          <div className="flex items-center gap-2">
            <Badge variant="outline" className="bg-[#1d3459]/5 text-[#1d3459] border-none text-[10px] font-bold uppercase py-0.5 tracking-widest px-3">WMS v2.0</Badge>
          </div>
          <h2 className="text-3xl font-extrabold text-slate-800 tracking-tight">Workforce Directory</h2>
          <p className="text-sm text-slate-500 font-medium">
            Employees and institutional positions. Assign a position for admin access; job designation stays on the profile.
          </p>
          {viewScope === "INSTITUTE" && (
            <Badge variant="outline" className="text-[10px] font-bold uppercase tracking-widest">
              Institute scope only
            </Badge>
          )}
        </div>

        <div className="flex items-center gap-3 w-full md:w-auto">
          {canEdit && <CreatePositionDialog />}
          {canEdit && <AddEmployeeDialog />}
        </div>
      </div>

      <PositionsOverview />

      <div className="bg-white/50 backdrop-blur-sm border border-slate-200/60 p-2 rounded-2xl flex flex-col sm:flex-row items-center gap-2 shadow-sm shadow-slate-100">
        <div className="relative flex-1 w-full">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <Input
                placeholder="Search by name, code, or ID..."
                value={search}
                onChange={(e) => { setSearch(e.target.value); setPage(0); }}
                className="w-full pl-10 h-11 border-none bg-transparent focus-visible:ring-0 text-sm font-medium placeholder:text-slate-400"
            />
        </div>
        <div className="h-6 w-px bg-slate-200 hidden sm:block mx-2" />
        <Select value={status} onValueChange={(v) => { setStatus(v); setPage(0); }}>
            <SelectTrigger className="w-full sm:w-44 h-11 border-none bg-transparent focus-visible:ring-0 text-xs font-bold uppercase tracking-wider text-slate-500">
                <div className="flex items-center gap-2">
                    <Filter className="w-3.5 h-3.5" />
                    <SelectValue placeholder="All Status" />
                </div>
            </SelectTrigger>
            <SelectContent className="rounded-xl border-slate-100">
                <SelectItem value="ALL" className="text-[10px] font-bold uppercase">All Status</SelectItem>
                <SelectItem value="ACTIVE" className="text-[10px] font-bold uppercase text-emerald-600">Active</SelectItem>
                <SelectItem value="ON_LEAVE" className="text-[10px] font-bold uppercase text-amber-600">On Leave</SelectItem>
                <SelectItem value="TERMINATED" className="text-[10px] font-bold uppercase text-rose-500">Terminated</SelectItem>
            </SelectContent>
        </Select>
      </div>

      <div className="bg-white rounded-3xl border border-slate-200/60 shadow-2xl shadow-slate-200/40 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm border-collapse">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/40">
                <th className="text-left px-8 py-5 text-[10px] font-bold text-slate-400 uppercase tracking-widest">Identiy / Code</th>
                <th className="text-left px-8 py-5 text-[10px] font-bold text-slate-400 uppercase tracking-widest hidden sm:table-cell">Professional Context</th>
                <th className="text-left px-8 py-5 text-[10px] font-bold text-slate-400 uppercase tracking-widest hidden md:table-cell">Position</th>
                <th className="text-left px-8 py-5 text-[10px] font-bold text-slate-400 uppercase tracking-widest hidden lg:table-cell">Tenure</th>
                <th className="text-left px-8 py-5 text-[10px] font-bold text-slate-400 uppercase tracking-widest">Compliance</th>
                <th className="text-right px-8 py-5 text-[10px] font-bold text-slate-400 uppercase tracking-widest">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <tr key={i}>
                    <td className="px-8 py-5 text-center" colSpan={6}><Skeleton className="h-14 w-full rounded-2xl" /></td>
                  </tr>
                ))
              ) : data?.items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-8 py-24 text-center">
                    <div className="flex flex-col items-center gap-3">
                        <div className="w-16 h-16 rounded-full bg-slate-100 flex items-center justify-center text-slate-400">
                            <Search className="w-8 h-8" />
                        </div>
                        <p className="text-sm font-bold text-slate-500 uppercase tracking-widest">No matching human resources found.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                data?.items.map((emp: any) => {
                  const info = emp.generalInfo || {};
                  const initials = info.fullName?.split(" ").map((n: string) => n[0]).join("").toUpperCase().slice(0, 2) || "??";
                  return (
                    <tr key={emp.id} className="hover:bg-slate-50/50 transition-all group border-b border-slate-50 last:border-0">
                      <td className="px-8 py-5">
                        <div className="flex items-center gap-4">
                          <PhotoLightbox src={emp.photoUrl} alt={info.fullName || "Employee"}>
                            <Avatar className="h-11 w-11 shrink-0 border-2 border-white shadow-xl shadow-slate-200">
                              <AvatarImage src={emp.photoUrl} />
                              <AvatarFallback className="bg-[#1d3459] text-[#d9b557] text-[10px] font-extrabold">
                                {initials}
                              </AvatarFallback>
                            </Avatar>
                          </PhotoLightbox>
                          <div className="space-y-1">
                            <p className="font-bold text-slate-800 text-sm group-hover:text-[#1d3459] transition-colors">{info.fullName || "Loading..."}</p>
                            <Badge variant="outline" className="text-[9px] font-extrabold text-slate-400 border-slate-200 uppercase tracking-widest px-2 py-0 h-4">
                              {`ID ${emp.id}`}
                            </Badge>
                          </div>
                        </div>
                      </td>
                      <td className="px-8 py-5 hidden sm:table-cell">
                        <div className="space-y-1">
                          <p className="text-slate-800 text-xs font-bold uppercase tracking-tight">{info.designation}</p>
                          <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">{info.department}</p>
                        </div>
                      </td>
                      <td className="px-8 py-5 hidden md:table-cell">
                        <Badge variant="outline" className="text-[9px] font-bold uppercase tracking-wider border-[#1d3459]/15 text-[#1d3459] bg-[#1d3459]/5">
                          {formatEmployeePosition(emp.position)}
                        </Badge>
                      </td>
                      <td className="px-8 py-5 text-slate-500 hidden lg:table-cell">
                         <div className="space-y-1">
                            <p className="text-xs font-bold text-slate-700">{info.joiningDate ? new Date(info.joiningDate).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—"}</p>
                             <p className="text-[9px] font-extrabold text-slate-400 uppercase tracking-tighter">Established Record</p>
                         </div>
                      </td>
                      <td className="px-8 py-5">
                        <Badge variant="outline" className={`text-[9px] px-3 py-1 border-2 font-extrabold uppercase tracking-widest rounded-full ${STATUS_COLORS[emp.status] ?? "bg-slate-100 text-slate-500"}`}>
                          {emp.status.replace("_", " ")}
                        </Badge>
                      </td>
                      <td className="px-8 py-5 text-right">
                        <div className="flex items-center justify-end gap-2">
                           <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                              <Button variant="ghost" size="icon" className="h-9 w-9 rounded-xl hover:bg-[#1d3459]/5 text-slate-400 hover:text-[#1d3459] transition-colors">
                                <MoreHorizontal className="h-4 w-4" />
                              </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end" className="w-48 p-2 rounded-2xl border-slate-100 shadow-2xl">
                              <DropdownMenuItem asChild>
                                <LinkInstance href={`/admin/employees/${emp.id}`} className="flex items-center gap-3 px-3 py-2 text-[11px] font-bold uppercase tracking-wider text-slate-600 rounded-xl cursor-pointer">
                                  <Eye className="h-4 w-4" /> View Profile
                                </LinkInstance>
                              </DropdownMenuItem>
                              <DropdownMenuItem 
                                className="flex items-center gap-3 px-3 py-2 text-[11px] font-bold uppercase tracking-wider text-rose-500 focus:text-rose-600 rounded-xl cursor-pointer"
                                onClick={() => handleDelete(emp.id, info.fullName)}
                                disabled={emp.status === 'TERMINATED' || deleteMutation.isPending}
                              >
                                <Trash2 className="h-4 w-4" /> Deactivate
                              </DropdownMenuItem>
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        <div className="flex items-center justify-between px-8 py-5 border-t border-slate-100 bg-slate-50/30">
          <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">
            {data ? (
                <>Showing <span className="text-slate-800">{page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, data.total)}</span> of <span className="text-slate-800">{data.total}</span> Capital Units</>
            ) : "Contextualizing workforce..."}
          </p>
          <div className="flex gap-3">
            <Button 
                size="sm" 
                variant="outline" 
                disabled={page === 0} 
                onClick={() => setPage((p) => p - 1)} 
                className="text-[10px] h-9 px-4 font-bold uppercase border-slate-200 rounded-xl shadow-sm hover:shadow-md transition-all gap-2"
            >
                <ChevronLeft className="w-4 h-4" /> Prev
            </Button>
            <Button 
                size="sm" 
                variant="outline" 
                disabled={page >= totalPages - 1} 
                onClick={() => setPage((p) => p + 1)} 
                className="text-[10px] h-9 px-4 font-bold uppercase border-slate-200 rounded-xl shadow-sm hover:shadow-md transition-all gap-2"
            >
                Next <ChevronRight className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
