"use client";

import { useState } from "react";
import { usePendingApprovals, useApproveLeave, useRejectLeave } from "@/lib/hooks/useLeave";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { CalendarDays, CheckCircle2, XCircle, ArrowLeft } from "lucide-react";
import Link from "next/link";
import { formatDate } from "@/lib/utils";
import type { LeaveApplication } from "@/lib/hooks/useLeave";

type ActionDialog = { type: "approve" | "reject"; app: LeaveApplication } | null;

export default function PendingApprovalsPage() {
  const { data: apps = [], isLoading } = usePendingApprovals();
  const { mutateAsync: approve, isPending: approving } = useApproveLeave();
  const { mutateAsync: reject, isPending: rejecting } = useRejectLeave();
  const [action, setAction] = useState<ActionDialog>(null);
  const [remarks, setRemarks] = useState("");

  const handleAction = async () => {
    if (!action) return;
    if (action.type === "approve") await approve({ id: action.app.id, remarks });
    else await reject({ id: action.app.id, remarks });
    setAction(null);
    setRemarks("");
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/admin/leaves"><ArrowLeft className="w-4 h-4" /></Link>
        </Button>
        <div>
          <h1 className="text-xl font-bold text-slate-900">Pending Approvals</h1>
          <p className="text-xs text-slate-500">Applications waiting for your action</p>
        </div>
        <Badge className="ml-auto bg-amber-100 text-amber-700 border-amber-200">
          {apps.length} pending
        </Badge>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-24 rounded-xl" />)}
        </div>
      ) : !apps.length ? (
        <div className="text-center py-16 text-slate-400">
          <CheckCircle2 className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p className="font-medium">All caught up!</p>
          <p className="text-xs mt-1">No pending approvals at the moment.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {apps.map((a) => (
            <Card key={a.id} className="border-none shadow-sm border-l-4 border-l-amber-400">
              <CardContent className="py-4 px-5">
                <div className="flex items-start gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-slate-800">
                        {a.employee?.generalInfo?.fullName ?? `Employee #${a.employee?.id}`}
                      </span>
                      <span className="text-xs text-slate-400">
                        {a.employee?.generalInfo?.employeeCode} &middot; {a.employee?.generalInfo?.designation}
                      </span>
                    </div>
                    <p className="text-sm text-slate-600 mt-1">
                      <strong>{a.leaveType.name}</strong> &middot; {formatDate(a.fromDate)} – {formatDate(a.toDate)} &middot; {a.totalDays} day{a.totalDays !== 1 ? "s" : ""}
                      {a.isHalfDay && <span className="ml-2 text-xs text-slate-400">(Half Day)</span>}
                    </p>
                    <p className="text-xs text-slate-500 mt-1 italic line-clamp-2">"{a.reason}"</p>
                    {/* Approval progress */}
                    {a.approvalSteps?.length > 0 && (
                      <div className="flex items-center gap-2 mt-2 flex-wrap">
                        {a.approvalSteps.map((s) => (
                          <span
                            key={s.id}
                            className={`text-[10px] px-2 py-0.5 rounded-full border font-medium ${
                              s.action === "APPROVED" || s.action === "RECOMMENDED"
                                ? "bg-emerald-50 border-emerald-200 text-emerald-700"
                                : s.action === "REJECTED"
                                  ? "bg-rose-50 border-rose-200 text-rose-600"
                                  : s.isSuperseded
                                    ? "bg-slate-50 border-slate-200 text-slate-400"
                                    : "bg-amber-50 border-amber-200 text-amber-700"
                            }`}
                          >
                            {s.approverRole}: {s.action ?? "Awaiting"}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                  <div className="flex gap-2 shrink-0">
                    <Button
                      size="sm"
                      className="bg-emerald-600 hover:bg-emerald-700 text-white h-8 px-3 text-xs"
                      onClick={() => { setAction({ type: "approve", app: a }); setRemarks(""); }}
                    >
                      <CheckCircle2 className="w-3.5 h-3.5 mr-1" /> Approve
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="border-rose-200 text-rose-600 hover:bg-rose-50 h-8 px-3 text-xs"
                      onClick={() => { setAction({ type: "reject", app: a }); setRemarks(""); }}
                    >
                      <XCircle className="w-3.5 h-3.5 mr-1" /> Reject
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <Dialog open={!!action} onOpenChange={(o) => { if (!o) setAction(null); }}>
        <DialogContent className="sm:max-w-[min(98vw,32rem)]">
          <DialogHeader>
            <DialogTitle>
              {action?.type === "approve" ? "Approve Application" : "Reject Application"}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            {action && (
              <div className="bg-slate-50 rounded-lg p-3 text-sm space-y-1">
                <p><strong>{action.app.employee?.generalInfo?.fullName}</strong></p>
                <p>{action.app.leaveType.name} &middot; {formatDate(action.app.fromDate)} – {formatDate(action.app.toDate)} ({action.app.totalDays} days)</p>
                <p className="text-xs text-slate-500 italic">"{action.app.reason}"</p>
              </div>
            )}
            <div className="space-y-1.5">
              <Label>Remarks (optional)</Label>
              <Textarea
                value={remarks}
                onChange={(e) => setRemarks(e.target.value)}
                placeholder="Add remarks…"
                rows={3}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAction(null)}>Cancel</Button>
            <Button
              disabled={approving || rejecting}
              onClick={handleAction}
              className={action?.type === "approve" ? "bg-emerald-600 hover:bg-emerald-700" : "bg-rose-600 hover:bg-rose-700"}
            >
              Confirm {action?.type === "approve" ? "Approval" : "Rejection"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
