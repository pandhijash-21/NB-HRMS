"use client";

import { useState } from "react";
import { useAllChangeRequests, useReviewRequest, type ChangeRequest } from "@/lib/hooks/useApprovals";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { CheckCircle2, XCircle, Clock, ChevronDown, ChevronUp, User, Layers } from "lucide-react";
import { cn } from "@/lib/utils";

const STATUS_STYLES: Record<string, string> = {
  PENDING:  "bg-amber-100 text-amber-700 border-amber-200",
  APPROVED: "bg-emerald-100 text-emerald-700 border-emerald-200",
  REJECTED: "bg-rose-100 text-rose-600 border-rose-200",
};

const MODULE_LABELS: Record<string, string> = {
  PERSONAL:          "Personal Info",
  ADDRESS_LOCAL:     "Current Address",
  ADDRESS_PERMANENT: "Permanent Address",
  OTHER:             "Other Info",
};

function DiffRow({ label, oldVal, newVal }: { label: string; oldVal: any; newVal: any }) {
  const changed = JSON.stringify(oldVal) !== JSON.stringify(newVal);
  if (!changed) return null;
  return (
    <div className="grid grid-cols-3 gap-3 py-2 border-b border-slate-50 last:border-0">
      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest pt-1">{label}</span>
      <span className="text-xs font-medium text-rose-500 line-through break-all">{String(oldVal ?? "—")}</span>
      <span className="text-xs font-semibold text-emerald-600 break-all">{String(newVal ?? "—")}</span>
    </div>
  );
}

function RequestCard({ req }: { req: ChangeRequest }) {
  const [expanded, setExpanded] = useState(false);
  const reviewMutation = useReviewRequest();

  const oldData = req.oldData ?? {};
  const newData = req.newData ?? {};
  const diffKeys = Object.keys(newData).filter(
    k => JSON.stringify(oldData[k]) !== JSON.stringify(newData[k])
  );

  return (
    <div className={cn(
      "bg-white rounded-2xl border shadow-sm overflow-hidden transition-all",
      req.status === "PENDING" ? "border-amber-100" : "border-slate-100"
    )}>
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4">
        <div className="flex items-center gap-4">
          <div className="w-10 h-10 rounded-xl bg-[#1d3459]/5 flex items-center justify-center">
            <User className="w-5 h-5 text-[#1d3459]" />
          </div>
          <div>
            <p className="text-sm font-bold text-slate-800">
              {req.employee?.generalInfo?.fullName ?? `Employee #${req.employeeId}`}
            </p>
            <div className="flex items-center gap-2 mt-0.5">
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                {req.employee?.generalInfo?.employeeCode ?? "—"}
              </span>
              <span className="w-1 h-1 rounded-full bg-slate-300" />
              <span className="text-[10px] font-bold text-[#1d3459] flex items-center gap-1">
                <Layers className="w-2.5 h-2.5" />
                {MODULE_LABELS[req.module] ?? req.module}
              </span>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <Badge className={`text-[9px] font-bold uppercase tracking-widest border px-3 ${STATUS_STYLES[req.status]}`} variant="outline">
            {req.status === "PENDING" && <Clock className="w-2.5 h-2.5 mr-1" />}
            {req.status}
          </Badge>
          <span className="text-[10px] text-slate-400 font-medium hidden sm:block">
            {new Date(req.requestedAt).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })}
          </span>
          <button
            onClick={() => setExpanded(!expanded)}
            className="w-7 h-7 rounded-lg bg-slate-50 hover:bg-slate-100 flex items-center justify-center transition-colors"
          >
            {expanded ? <ChevronUp className="w-3.5 h-3.5 text-slate-500" /> : <ChevronDown className="w-3.5 h-3.5 text-slate-500" />}
          </button>
        </div>
      </div>

      {/* Diff View */}
      {expanded && (
        <div className="border-t border-slate-50 px-6 py-4 bg-slate-50/30 animate-in fade-in slide-in-from-top-1 duration-200">
          {diffKeys.length === 0 ? (
            <p className="text-xs text-slate-400 font-medium">No changed fields detected.</p>
          ) : (
            <>
              <div className="grid grid-cols-3 gap-3 mb-3">
                <span className="text-[9px] font-bold text-slate-300 uppercase tracking-widest">Field</span>
                <span className="text-[9px] font-bold text-rose-300 uppercase tracking-widest">Current Value</span>
                <span className="text-[9px] font-bold text-emerald-400 uppercase tracking-widest">Proposed Value</span>
              </div>
              {diffKeys.map(k => (
                <DiffRow key={k} label={k} oldVal={oldData[k]} newVal={newData[k]} />
              ))}
            </>
          )}

          {/* Actions */}
          {req.status === "PENDING" && (
            <div className="flex gap-3 mt-5 pt-4 border-t border-slate-100">
              <Button
                onClick={() => reviewMutation.mutate({ id: req.id, action: "approve" })}
                disabled={reviewMutation.isPending}
                size="sm"
                className="bg-emerald-500 hover:bg-emerald-600 text-white font-bold text-[10px] uppercase gap-2 rounded-xl px-5 shadow-lg shadow-emerald-500/20"
              >
                <CheckCircle2 className="w-3.5 h-3.5" /> Approve
              </Button>
              <Button
                onClick={() => reviewMutation.mutate({ id: req.id, action: "reject" })}
                disabled={reviewMutation.isPending}
                size="sm"
                variant="outline"
                className="border-rose-200 text-rose-600 hover:bg-rose-50 font-bold text-[10px] uppercase gap-2 rounded-xl px-5"
              >
                <XCircle className="w-3.5 h-3.5" /> Reject
              </Button>
            </div>
          )}
          {req.status !== "PENDING" && req.reviewedAt && (
            <p className="text-[10px] text-slate-400 mt-3">
              {req.status === "APPROVED" ? "Approved" : "Rejected"} on{" "}
              {new Date(req.reviewedAt).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })}
            </p>
          )}
        </div>
      )}
    </div>
  );
}

export default function ApprovalsPage() {
  const [filter, setFilter] = useState<"PENDING" | "APPROVED" | "REJECTED" | undefined>("PENDING");
  const { data: requests, isLoading } = useAllChangeRequests(filter);

  const tabs = [
    { label: "Pending", value: "PENDING" as const },
    { label: "Approved", value: "APPROVED" as const },
    { label: "Rejected", value: "REJECTED" as const },
  ];

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-extrabold text-slate-800 tracking-tight">Change Requests</h1>
        <p className="text-sm text-slate-500 mt-1">Review and approve employee profile update requests.</p>
      </div>

      {/* Filter Tabs */}
      <div className="flex gap-2 p-1 bg-slate-100/50 rounded-2xl w-fit border border-slate-200/40">
        <button
          onClick={() => setFilter(undefined)}
          className={cn(
            "px-5 py-2 rounded-xl text-[10px] font-bold uppercase tracking-widest transition-all",
            !filter ? "bg-[#1d3459] text-white shadow-lg" : "text-slate-500 hover:text-slate-700"
          )}
        >
          All
        </button>
        {tabs.map(t => (
          <button
            key={t.value}
            onClick={() => setFilter(t.value)}
            className={cn(
              "px-5 py-2 rounded-xl text-[10px] font-bold uppercase tracking-widest transition-all",
              filter === t.value ? "bg-[#1d3459] text-white shadow-lg" : "text-slate-500 hover:text-slate-700"
            )}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* List */}
      {isLoading ? (
        <div className="space-y-3">
          {[...Array(3)].map((_, i) => <Skeleton key={i} className="h-20 rounded-2xl" />)}
        </div>
      ) : !requests?.length ? (
        <div className="py-20 text-center bg-white rounded-2xl border border-slate-100 shadow-sm">
          <CheckCircle2 className="w-10 h-10 text-slate-200 mx-auto mb-3" />
          <p className="text-sm font-bold text-slate-400 uppercase tracking-widest">No requests found</p>
        </div>
      ) : (
        <div className="space-y-3">
          {requests.map(r => <RequestCard key={r.id} req={r} />)}
        </div>
      )}
    </div>
  );
}
