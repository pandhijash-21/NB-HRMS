"use client";

import { useState } from "react";
import Link from "next/link";
import { Shield, Settings } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { usePositions } from "@/lib/hooks/useDesignations";

export function PositionsOverview() {
  const { data: positions = [], isLoading } = usePositions();

  if (isLoading) {
    return <Skeleton className="h-28 w-full rounded-2xl" />;
  }

  if (positions.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-slate-200 bg-slate-50/50 px-6 py-5 text-sm text-slate-500">
        No positions yet. Use <strong>Create Position</strong> to add one, then configure permissions under{" "}
        <Link href="/admin/roles" className="text-[#1d3459] underline font-semibold">
          Roles &amp; Permissions
        </Link>
        .
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-slate-200/60 bg-white/70 backdrop-blur-sm p-5 shadow-sm space-y-3">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex items-center gap-2">
          <Shield className="h-4 w-4 text-[#1d3459]" />
          <h3 className="text-xs font-bold uppercase tracking-widest text-slate-600">Institutional Positions</h3>
          <Badge variant="outline" className="text-[9px] font-bold">{positions.length}</Badge>
        </div>
        <p className="text-[10px] text-slate-400 max-w-xl">
          Assign these to employees for admin access. Permissions are edited per position in Roles &amp; Permissions.
        </p>
      </div>
      <div className="flex flex-wrap gap-2">
        {positions.map((p) => (
          <div
            key={p.id}
            className="inline-flex items-center gap-2 rounded-xl border border-[#1d3459]/10 bg-[#1d3459]/5 px-3 py-2"
          >
            <span className="text-[11px] font-bold text-[#1d3459]">{p.name}</span>
            <Badge variant="outline" className="text-[9px] font-bold uppercase border-none bg-white/80">
              {p.linkedRoleName}
            </Badge>
            <Link href={`/admin/roles/${p.linkedRoleId}`}>
              <Button size="sm" variant="ghost" className="h-7 px-2 text-[10px] font-bold uppercase text-[#1d3459]">
                <Settings className="h-3 w-3 mr-1" />
                Matrix
              </Button>
            </Link>
          </div>
        ))}
      </div>
    </div>
  );
}
