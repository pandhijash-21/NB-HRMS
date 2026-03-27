"use client";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { AuditLogDrawer } from "@/components/shared/AuditLogDrawer";

interface ProfileHeaderProps {
  employee: {
    id: string;
    fullName: string;
    employeeCode: string;
    designation: string;
    department: string;
    email: string;
    phone?: string;
    photoUrl?: string;
    status: string;
    joiningDate: string;
    employeeCategory: string;
    updatedAt?: string;
  };
  showAuditLog?: boolean;
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
  showAuditLog,
  actions,
}: ProfileHeaderProps) {
  const initials = employee.fullName
    .split(" ")
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);

  return (
    <div className="bg-white rounded-xl border border-slate-100 shadow-sm p-6">
      <div className="flex flex-col sm:flex-row gap-5 items-start sm:items-center">
        {/* Avatar */}
        <Avatar className="h-20 w-20 shrink-0 ring-2 ring-[#1d3459]/20">
          <AvatarImage src={employee.photoUrl} alt={employee.fullName} />
          <AvatarFallback
            style={{ backgroundColor: "#1d3459", color: "#d9b557" }}
            className="text-2xl font-bold"
          >
            {initials}
          </AvatarFallback>
        </Avatar>

        {/* Info */}
        <div className="flex-1 min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-xl font-bold text-slate-800">
              {employee.fullName}
            </h2>
            <Badge
              className={`text-xs border ${STATUS_COLORS[employee.status] ?? "bg-slate-100"}`}
            >
              {employee.status.replace("_", " ")}
            </Badge>
          </div>

          <p className="text-sm text-slate-500 mt-0.5">
            {employee.designation} · {employee.department}
          </p>

          <div className="flex flex-wrap gap-4 mt-3 text-xs text-slate-500">
            <span>
              <span className="font-medium text-slate-700">EMP ID:</span>{" "}
              {employee.employeeCode}
            </span>
            <span>
              <span className="font-medium text-slate-700">Joined:</span>{" "}
              {new Date(employee.joiningDate).toLocaleDateString("en-IN", {
                day: "2-digit",
                month: "short",
                year: "numeric",
              })}
            </span>
            <span>
              <span className="font-medium text-slate-700">Category:</span>{" "}
              {employee.employeeCategory.replace("_", " ")}
            </span>
          </div>

          <div className="flex flex-wrap gap-4 mt-1.5 text-xs text-slate-500">
            <a href={`mailto:${employee.email}`} className="text-[#1d3459]">
              {employee.email}
            </a>
            {employee.phone && <span>{employee.phone}</span>}
          </div>
        </div>

        {/* Actions & Timestamps */}
        <div className="flex flex-col gap-2 shrink-0 items-end">
          {employee.updatedAt && (
            <div className="text-[10px] uppercase tracking-wider text-slate-400 font-medium">
              Last Updated: {new Date(employee.updatedAt).toLocaleString("en-IN", {
                day: "2-digit", month: "short", year: "numeric",
                hour: "2-digit", minute: "2-digit"
              })}
            </div>
          )}
          <div className="flex gap-2">
            {showAuditLog && (
              <AuditLogDrawer
                employeeId={employee.id}
                trigger={
                  <button className="text-xs px-3 py-1.5 border border-slate-200 rounded-lg text-slate-600 hover:bg-slate-50 transition-colors">
                    Audit Log
                  </button>
                }
              />
            )}
            {actions}
          </div>
        </div>
      </div>

      <Separator className="mt-5" />
    </div>
  );
}
