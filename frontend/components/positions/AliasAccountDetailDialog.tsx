"use client";

import { useEffect, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { KeyRound } from "lucide-react";
import api from "@/lib/axios";
import { AccountCredentialsDialog } from "@/components/admin/AccountCredentialsDialog";
import type { PositionSlot } from "@/lib/hooks/useDesignations";

type Props = {
  slotId: string | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
};

export function AliasAccountDetailDialog({ slotId, open, onOpenChange }: Props) {
  const [slot, setSlot] = useState<PositionSlot | null>(null);
  const [loading, setLoading] = useState(false);
  const [showCreds, setShowCreds] = useState(false);

  useEffect(() => {
    if (!open || !slotId) {
      setSlot(null);
      return;
    }
    setLoading(true);
    api
      .get(`admin/position-slots/${slotId}`)
      .then(({ data }) => setSlot(data.data))
      .finally(() => setLoading(false));
  }, [open, slotId]);

  const holder = slot?.assignments?.[0]?.holderEmployee;

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle className="text-[#1d3459]">Alias account details</DialogTitle>
          </DialogHeader>

          {loading || !slot ? (
            <p className="text-sm text-slate-500 py-6">{loading ? "Loading…" : "Not found"}</p>
          ) : (
            <div className="space-y-4">
              <div className="rounded-lg border p-4 space-y-2">
                <p className="font-mono text-lg font-bold text-[#1d3459]">{slot.code}</p>
                <p className="text-sm text-slate-700">{slot.name}</p>
                <div className="flex flex-wrap gap-2 pt-1">
                  <Badge variant="outline">{slot.designation.name}</Badge>
                  <Badge variant="outline">{slot.linkedRole.name}</Badge>
                  {slot.subOrganization && (
                    <Badge variant="secondary">{slot.subOrganization}</Badge>
                  )}
                  <Badge className={slot.user?.isActive ? "bg-emerald-100 text-emerald-700" : ""}>
                    {slot.user?.isActive ? "Active · ready to login" : "Inactive"}
                  </Badge>
                </div>
              </div>

              <dl className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                <dt className="text-slate-400">Login username</dt>
                <dd className="font-mono font-medium">{slot.user?.username ?? slot.code}</dd>
                <dt className="text-slate-400">Institute</dt>
                <dd>{slot.institute?.name ?? slot.subOrganization ?? "University-wide"}</dd>
                <dt className="text-slate-400">Last login</dt>
                <dd>
                  {slot.user?.lastLoginAt
                    ? new Date(slot.user.lastLoginAt).toLocaleString()
                    : "Never"}
                </dd>
                <dt className="text-slate-400">Current holder</dt>
                <dd>
                  {holder?.generalInfo?.fullName
                    ? `${holder.generalInfo.fullName} (${holder.generalInfo.employeeCode ?? holder.id})`
                    : "—"}
                </dd>
              </dl>

              <Button
                className="w-full bg-[#1d3459]"
                onClick={() => setShowCreds(true)}
                disabled={!slot.userId}
              >
                <KeyRound className="h-4 w-4 mr-2" />
                View login & password
              </Button>
            </div>
          )}
        </DialogContent>
      </Dialog>

      <AccountCredentialsDialog
        userId={slot?.userId ?? null}
        title={`Credentials — ${slot?.code ?? ""}`}
        open={showCreds}
        onOpenChange={setShowCreds}
      />
    </>
  );
}
