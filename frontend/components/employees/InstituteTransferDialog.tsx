"use client";

import { useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useInstituteTransfer } from "@/modules/admin/hooks/useAdminEmployees";
import { InstituteSelect } from "@/components/institutes/InstituteSelect";

export function InstituteTransferDialog(props: { employeeId: string | number }) {
  const [open, setOpen] = useState(false);
  const [effectiveFrom, setEffectiveFrom] = useState<string>("");
  const [instituteId, setInstituteId] = useState<string>("");
  const [reason, setReason] = useState<string>("");

  const m = useInstituteTransfer(props.employeeId);

  const submit = async () => {
    await m.mutateAsync({
      effectiveFrom,
      instituteId: instituteId || undefined,
      reason: reason || null,
    });
    setOpen(false);
    setEffectiveFrom("");
    setInstituteId("");
    setReason("");
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" className="text-xs">
          Institute Transfer
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Institute Transfer</DialogTitle>
        </DialogHeader>

        <div className="grid grid-cols-1 gap-3">
          <div className="space-y-1">
            <Label>Effective from *</Label>
            <Input type="date" value={effectiveFrom} onChange={(e) => setEffectiveFrom(e.target.value)} />
          </div>
          <div className="space-y-1">
            <Label>New Institute *</Label>
            <InstituteSelect value={instituteId} onValueChange={setInstituteId} />
          </div>
          <div className="space-y-1">
            <Label>Reason</Label>
            <Input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Optional note..." />
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <Button variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={submit} disabled={m.isPending || !effectiveFrom || !instituteId}>
              {m.isPending ? "Saving..." : "Save"}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

