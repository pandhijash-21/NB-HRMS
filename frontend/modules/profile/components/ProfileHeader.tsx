"use client";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { EmployeeStatus, EmployeeCategory } from "../types";

interface ProfileHeaderProps {
  employee: {
    id: number;
    fullName: string;
    employeeCode: string;
    designation: string;
    department: string;
    email: string;
    phone?: string | null;
    photoUrl?: string | null;
    status: EmployeeStatus;
    joiningDate: string;
    employeeCategory: EmployeeCategory;
    updatedAt?: string;
  };
  actions?: React.ReactNode;
}

const STATUS_COLORS: Record<string, string> = {
  ACTIVE: "bg-emerald-100 text-emerald-700 border-emerald-200",
  INACTIVE: "bg-slate-100 text-slate-500 border-slate-200",
  ON_LEAVE: "bg-amber-100 text-amber-700 border-amber-200",
  TERMINATED: "bg-rose-100 text-rose-600 border-rose-200",
  RETIRED: "bg-purple-100 text-purple-600 border-purple-200",
};

export function ProfileHeader({
  employee,
  actions,
}: ProfileHeaderProps) {
  const initials = (employee.fullName || "??")
    .split(" ")
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);

  return (
    <div className="bg-white rounded-2xl border border-slate-100 shadow-sm p-6 overflow-hidden">
      <div className="flex flex-col sm:flex-row gap-6 items-start sm:items-center">
        {/* Avatar */}
        <Avatar className="h-24 w-24 shrink-0 ring-4 ring-[#1d3459]/5 border-2 border-white">
          <AvatarImage src={employee.photoUrl || undefined} alt={employee.fullName} />
          <AvatarFallback
            style={{ backgroundColor: "#1d3459", color: "#d9b557" }}
            className="text-3xl font-bold"
          >
            {initials}
          </AvatarFallback>
        </Avatar>

        {/* Info */}
        <div className="flex-1 min-w-0 space-y-1">
          <div className="flex flex-wrap items-center gap-3">
            <h2 className="text-2xl font-extrabold text-slate-900 tracking-tight">
              {employee.fullName || "Unknown Employee"}
            </h2>
            <Badge
              className={`text-[10px] font-bold uppercase tracking-wider border ${STATUS_COLORS[employee.status] ?? "bg-slate-100 text-slate-500 transition-all hover:scale-105"}`}
              variant="outline"
            >
              {employee.status.replace("_", " ")}
            </Badge>
          </div>

          <p className="text-sm font-medium text-slate-500 flex items-center gap-2">
            <span className="text-[#1d3459]">{employee.designation}</span>
            <span className="w-1 h-1 bg-slate-300 rounded-full" />
            <span>{employee.department}</span>
          </p>

          <div className="flex flex-wrap gap-x-5 gap-y-2 mt-4 text-[11px] text-slate-400 font-bold uppercase tracking-widest">
            <div className="flex items-center gap-1.5">
              <span className="text-slate-300">ID:</span>
              <span className="text-slate-600">{employee.employeeCode}</span>
            </div>
            <div className="flex items-center gap-1.5">
              <span className="text-slate-300">Joined:</span>
              <span className="text-slate-600">
                {new Date(employee.joiningDate).toLocaleDateString("en-IN", {
                  day: "2-digit",
                  month: "short",
                  year: "numeric",
                })}
              </span>
            </div>
            <div className="flex items-center gap-1.5 text-[#d9b557]">
              <span>{employee.employeeCategory.replace("_", " ")}</span>
            </div>
          </div>
        </div>

        {/* Interaction Area */}
        <div className="flex flex-col gap-3 shrink-0 items-end self-start sm:self-center">
          {actions}
          {employee.updatedAt && (
            <div className="text-[10px] uppercase tracking-widest text-slate-300 font-bold">
              Updated: {new Date(employee.updatedAt).toLocaleDateString("en-IN")}
            </div>
          )}
        </div>
      </div>

      <Separator className="mt-8 bg-slate-50" />
    </div>
  );
}
