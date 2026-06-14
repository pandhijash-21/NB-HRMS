"use client";

import { use, useState } from "react";
import Link from "next/link";
import { useInstituteMembers } from "@/lib/hooks/useInstitutes";
import { AliasAccountDetailDialog } from "@/components/positions/AliasAccountDetailDialog";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";

interface PageProps {
  params: Promise<{ id: string }>;
}

export default function InstituteDetailPage({ params }: PageProps) {
  const { id } = use(params);
  const { data, isLoading, isError, error } = useInstituteMembers(id);
  const [detailSlotId, setDetailSlotId] = useState<string | null>(null);

  if (isLoading) {
    return (
      <div className="space-y-4 max-w-5xl">
        <Skeleton className="h-10 w-64" />
        <Skeleton className="h-48 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div className="py-16 text-center text-slate-400">
        <p>{isError ? (error as Error)?.message || "Failed to load institute" : "Institute not found."}</p>
        <Link href="/admin/institutes" className="text-[#1d3459] underline text-sm mt-2 inline-block">
          ← Back to institutes
        </Link>
      </div>
    );
  }

  const { institute, employees, aliases } = data;

  return (
    <div className="space-y-6 max-w-5xl">
      <div>
        <Link href="/admin/institutes" className="text-xs text-slate-400 hover:text-[#1d3459]">
          ← All institutes
        </Link>
        <h1 className="text-xl font-bold text-slate-800 mt-2">{institute.name}</h1>
        <p className="text-sm text-slate-500 font-mono">{institute.code}</p>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <Card className="p-4 text-center">
          <p className="text-2xl font-bold text-[#1d3459]">{employees.length}</p>
          <p className="text-[10px] font-bold uppercase text-slate-400 tracking-widest">Employees</p>
        </Card>
        <Card className="p-4 text-center">
          <p className="text-2xl font-bold text-[#1d3459]">{aliases.length}</p>
          <p className="text-[10px] font-bold uppercase text-slate-400 tracking-widest">Alias accounts</p>
        </Card>
      </div>

      <Card className="p-4">
        <h2 className="font-semibold text-sm mb-3">Employees</h2>
        {employees.length === 0 ? (
          <p className="text-sm text-slate-400">No employees assigned to this institute.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-[10px] uppercase text-slate-400 tracking-widest">
                  <th className="py-2 pr-4">Name</th>
                  <th className="py-2 pr-4 hidden sm:table-cell">Designation</th>
                  <th className="py-2">ID</th>
                </tr>
              </thead>
              <tbody>
                {employees.map((emp) => (
                  <tr key={emp.id} className="border-b border-slate-50 last:border-0">
                    <td className="py-3 pr-4">
                      <Link href={`/admin/employees/${emp.id}`} className="font-medium text-[#1d3459] hover:underline">
                        {emp.generalInfo?.fullName ?? `Employee #${emp.id}`}
                      </Link>
                      {emp.generalInfo?.employeeCode && (
                        <p className="text-xs text-slate-400">{emp.generalInfo.employeeCode}</p>
                      )}
                    </td>
                    <td className="py-3 pr-4 hidden sm:table-cell text-slate-600">
                      {emp.generalInfo?.designation ?? "—"}
                    </td>
                    <td className="py-3 text-slate-400 font-mono text-xs">{emp.id}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Card className="p-4">
        <h2 className="font-semibold text-sm mb-3">Alias accounts</h2>
        <p className="text-xs text-slate-400 mb-3">
          Logins scoped to this institute (e.g. HOI-GIT). Matched by institute code or login suffix.
        </p>
        {aliases.length === 0 ? (
          <p className="text-sm text-slate-400">No alias accounts for this institute.</p>
        ) : (
          <div className="space-y-2">
            {aliases.map((slot) => (
              <button
                key={slot.id}
                type="button"
                onClick={() => setDetailSlotId(slot.id)}
                className="w-full text-left flex justify-between items-start border rounded-lg p-3 gap-4 hover:border-[#1d3459]/30 hover:bg-slate-50/50 transition-colors"
              >
                <div>
                  <p className="font-mono font-bold text-sm text-[#1d3459]">{slot.code}</p>
                  <p className="text-xs text-slate-600">{slot.name}</p>
                  <p className="text-[10px] text-slate-400 mt-1">
                    Position: {slot.designation.name} · {slot.linkedRole.name}
                  </p>
                </div>
                <Badge className={slot.user?.isActive ? "bg-emerald-100 text-emerald-700" : "bg-slate-100"}>
                  {slot.user?.isActive ? "Active" : "Inactive"}
                </Badge>
              </button>
            ))}
          </div>
        )}
      </Card>

      <AliasAccountDetailDialog
        slotId={detailSlotId}
        open={!!detailSlotId}
        onOpenChange={(open) => { if (!open) setDetailSlotId(null); }}
      />
    </div>
  );
}
