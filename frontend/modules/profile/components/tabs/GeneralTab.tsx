"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useGeneralInfo } from "../../hooks/useProfile";
import { Skeleton } from "@/components/ui/skeleton";
import { ShieldCheck } from "lucide-react";

interface GeneralTabProps {
  employeeId: string | number;
}

function ReadOnlyField({ label, value }: { label: string; value?: string | null }) {
  return (
    <div className="space-y-1 p-3 rounded-lg bg-slate-50/50 border border-transparent hover:border-slate-100 transition-all">
      <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{label}</p>
      <p className="text-sm font-semibold text-slate-700">{value || "—"}</p>
    </div>
  );
}

export function GeneralTab({ employeeId }: GeneralTabProps) {
  const { data: general, isLoading } = useGeneralInfo(employeeId);

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {[...Array(9)].map((_, i) => (
          <Skeleton key={i} className="h-16 w-full rounded-xl" />
        ))}
      </div>
    );
  }

  if (!general) {
    return (
      <div className="p-8 text-center bg-slate-50 rounded-2xl border border-dashed border-slate-200">
        <p className="text-sm text-slate-400 font-medium">No general information available.</p>
      </div>
    );
  }

  return (
    <Card className="border-none shadow-none bg-transparent">
      <CardHeader className="px-0 pt-0 pb-4">
        <div className="flex items-center gap-2">
          <ShieldCheck className="w-4 h-4 text-[#1d3459]" />
          <CardTitle className="text-sm font-bold text-slate-800 uppercase tracking-tight">
            Employment Records
          </CardTitle>
        </div>
        <p className="text-[11px] text-slate-500 font-medium">
          Official institutional data provided by the Registrar/HR office. These details are read-only.
        </p>
      </CardHeader>
      <CardContent className="px-0">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <ReadOnlyField label="Full Name" value={general.fullName} />
          <ReadOnlyField label="Designation" value={general.designation} />
          <ReadOnlyField label="Department" value={general.department} />
          <ReadOnlyField label="Organization" value={general.organization} />
          <ReadOnlyField label="Sub-Organization" value={general.subOrganization} />
          <ReadOnlyField label="Employee Category" value={general.employeeCategory?.replace("_", " ")} />
          <ReadOnlyField label="Appointment Type" value={general.appointmentType?.replace(/_/g, " ")} />
          <ReadOnlyField label="Shift" value={general.shift} />
          <ReadOnlyField 
            label="Joining Date" 
            value={general.joiningDate ? new Date(general.joiningDate).toLocaleDateString("en-IN", { day: '2-digit', month: 'short', year: 'numeric' }) : null} 
          />
          <ReadOnlyField 
            label="Original Joining" 
            value={general.originalJoiningDate ? new Date(general.originalJoiningDate).toLocaleDateString("en-IN", { day: '2-digit', month: 'short', year: 'numeric' }) : null} 
          />
          <ReadOnlyField label="Increment Month" value={general.incrementMonth} />
          <ReadOnlyField label="Functional Dept" value={general.functionalDepartment} />
          <ReadOnlyField label="Primary Reporting" value={general.firstReporting} />
          <ReadOnlyField label="Secondary Reporting" value={general.secondReporting} />
        </div>
      </CardContent>
    </Card>
  );
}
