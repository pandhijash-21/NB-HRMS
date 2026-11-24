"use client";

import React, { useState } from "react";
import { useSession } from "next-auth/react";
import { AdminAuditView } from "@/components/admin/audit/AdminAuditView";
import { SuperadminAuditView } from "@/components/admin/audit/SuperadminAuditView";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Shield, Building2, UserCheck } from "lucide-react";

export default function AuditPage() {
  const { data: session, status } = useSession();

  const userRole = (session?.user?.role || "").toUpperCase().replace(/[\s_-]+/g, "");
  const isSuperAdmin = userRole === "SUPERADMIN";

  // Superadmin can toggle between Superadmin drill-down mode and Tenant view
  const [viewMode, setViewMode] = useState<"SUPERADMIN" | "TENANT">("SUPERADMIN");

  if (status === "loading") {
    return (
      <div className="space-y-4 p-6">
        <div className="h-8 bg-slate-200 rounded w-1/4 animate-pulse" />
        <div className="h-4 bg-slate-100 rounded w-1/2 animate-pulse" />
        <div className="grid grid-cols-4 gap-4 mt-6">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="h-24 bg-slate-100 rounded-xl animate-pulse" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Superadmin Mode Switcher Bar */}
      {isSuperAdmin && (
        <div className="bg-slate-900 text-white px-4 py-2.5 rounded-xl flex items-center justify-between text-xs shadow-sm">
          <div className="flex items-center gap-2">
            <Shield className="w-4 h-4 text-amber-400" />
            <span className="font-semibold text-slate-200">Platform Super Admin Mode:</span>
            <Badge className="bg-amber-400/20 text-amber-300 border border-amber-400/30 text-[10px] font-bold">
              SUPERADMIN ACTIVE
            </Badge>
          </div>

          <div className="flex items-center gap-1.5 bg-slate-800 p-1 rounded-lg border border-slate-700">
            <button
              type="button"
              onClick={() => setViewMode("SUPERADMIN")}
              className={`px-3 py-1 rounded text-xs font-semibold transition-all flex items-center gap-1.5 ${
                viewMode === "SUPERADMIN"
                  ? "bg-indigo-600 text-white shadow-sm"
                  : "text-slate-400 hover:text-white"
              }`}
            >
              <Building2 className="w-3.5 h-3.5" />
              Company &gt; Employee Drill-down
            </button>
            <button
              type="button"
              onClick={() => setViewMode("TENANT")}
              className={`px-3 py-1 rounded text-xs font-semibold transition-all flex items-center gap-1.5 ${
                viewMode === "TENANT"
                  ? "bg-indigo-600 text-white shadow-sm"
                  : "text-slate-400 hover:text-white"
              }`}
            >
              <UserCheck className="w-3.5 h-3.5" />
              Tenant Scope View
            </button>
          </div>
        </div>
      )}

      {/* Render Appropriate Audit View */}
      {isSuperAdmin && viewMode === "SUPERADMIN" ? (
        <SuperadminAuditView />
      ) : (
        <AdminAuditView />
      )}
    </div>
  );
}
