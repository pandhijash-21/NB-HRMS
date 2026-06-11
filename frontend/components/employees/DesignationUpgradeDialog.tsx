"use client";

import { useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { DESIGNATIONS } from "@/lib/constants/designations";
import { useDesignationUpgrade } from "@/modules/admin/hooks/useAdminEmployees";

export function DesignationUpgradeDialog(props: { employeeId: string | number }) {
  const [open, setOpen] = useState(false);
  const [effectiveFrom, setEffectiveFrom] = useState<string>("");
  const [newDesignation, setNewDesignation] = useState<string>("");
  const [reason, setReason] = useState<string>("");

  const m = useDesignationUpgrade(props.employeeId);

  const submit = async () => {
    await m.mutateAsync({
      effectiveFrom,
      newDesignation,
      reason: reason || null,
    });
    setOpen(false);
    setEffectiveFrom("");
    setNewDesignation("");
    setReason("");
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" className="text-xs">
          Designation Upgrade
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Designation Upgrade</DialogTitle>
        </DialogHeader>

        <div className="grid grid-cols-1 gap-3">
          <div className="space-y-1">
            <Label>Effective from *</Label>
            <Input type="date" value={effectiveFrom} onChange={(e) => setEffectiveFrom(e.target.value)} />
          </div>
          <div className="space-y-1">
            <Label>New Designation *</Label>
            <Select value={newDesignation} onValueChange={setNewDesignation}>
              <SelectTrigger>
                <SelectValue placeholder="Select..." />
              </SelectTrigger>
              <SelectContent className="max-h-[240px]">
                {DESIGNATIONS.map((d) => (
                  <SelectItem key={d} value={d}>
                    {d}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1">
            <Label>Reason</Label>
            <Input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Optional note..." />
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <Button variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={submit} disabled={m.isPending || !effectiveFrom || !newDesignation}>
              {m.isPending ? "Saving..." : "Save"}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

