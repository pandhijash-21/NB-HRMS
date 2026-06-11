"use client";

import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import type { EmployeeAssignment } from "@/modules/admin/hooks/useAdminEmployees";

function fmtRange(a: EmployeeAssignment) {
  return `${a.effectiveFrom} → ${a.effectiveTo ?? "Present"}`;
}

export function EmploymentHistory(props: { assignments: EmployeeAssignment[]; currentSubOrg?: string | null; currentDesignation?: string | null }) {
  const rows = (props.assignments ?? []).slice().sort((a, b) => a.effectiveFrom.localeCompare(b.effectiveFrom));

  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-3 flex-wrap">
        <div>
          <div className="text-sm font-bold text-slate-800">Employment History</div>
          <div className="text-xs text-slate-500">
            Tracks institute and designation changes over time.
          </div>
        </div>
        <div className="flex gap-2">
          {props.currentSubOrg ? <Badge variant="outline">Current: {props.currentSubOrg}</Badge> : null}
          {props.currentDesignation ? <Badge variant="secondary">{props.currentDesignation}</Badge> : null}
        </div>
      </div>

      {rows.length === 0 ? (
        <div className="mt-4 text-xs text-slate-500">No assignments recorded yet. Run backfill or add a transfer/upgrade.</div>
      ) : (
        <div className="mt-4 overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr className="text-left text-slate-500 border-b">
                <th className="py-2 pr-3">Range</th>
                <th className="py-2 pr-3">Sub-Org</th>
                <th className="py-2 pr-3">Designation</th>
                <th className="py-2 pr-3">Department</th>
                <th className="py-2 pr-3">Reason</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((a) => (
                <tr key={a.id} className="border-b border-slate-100">
                  <td className="py-2 pr-3 font-medium text-slate-700">{fmtRange(a)}</td>
                  <td className="py-2 pr-3">{a.subOrganization ?? "—"}</td>
                  <td className="py-2 pr-3">{a.designation}</td>
                  <td className="py-2 pr-3">{a.department ?? "—"}</td>
                  <td className="py-2 pr-3">{a.reason ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}

