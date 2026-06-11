"use client";

import { useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useInstituteTransfer } from "@/modules/admin/hooks/useAdminEmployees";

const INSTITUTES = [
  "Gandhinagar Institute of Technology",
  "Gandhinagar Institute of Management",
  "Gandhinagar Institute of Commerce",
  "Gandhinagar Institute of Science",
  "Gandhinagar Institute of Research & Development",
  "Gandhinagar Institute of Liberal Studies",
  "Gandhinagar Institute of Computer Science & Applications",
  "Gandhinagar Institute of Law",
  "Gandhinagar Institute of Valuation Studies",
  "Gandhinagar Institute of Design",
  "Gandhinagar Institute of Pharmacy",
  "Gandhinagar Institute of Nursing",
  "Gandhinagar Institute of Skill Development",
  "Gandhinagar Institute of Library & Information Science",
  "Gandhinagar Institute of Vocational Education",
] as const;

export function InstituteTransferDialog(props: { employeeId: string | number }) {
  const [open, setOpen] = useState(false);
  const [effectiveFrom, setEffectiveFrom] = useState<string>("");
  const [newSubOrganization, setNewSubOrganization] = useState<string>("");
  const [reason, setReason] = useState<string>("");

  const m = useInstituteTransfer(props.employeeId);

  const submit = async () => {
    await m.mutateAsync({
      effectiveFrom,
      newSubOrganization: newSubOrganization || null,
      reason: reason || null,
    });
    setOpen(false);
    setEffectiveFrom("");
    setNewSubOrganization("");
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
            <Label>New Sub-Organization *</Label>
            <Select value={newSubOrganization} onValueChange={setNewSubOrganization}>
              <SelectTrigger>
                <SelectValue placeholder="Select institute..." />
              </SelectTrigger>
              <SelectContent className="max-h-[240px]">
                {INSTITUTES.map((i) => (
                  <SelectItem key={i} value={i}>
                    {i}
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
            <Button onClick={submit} disabled={m.isPending || !effectiveFrom || !newSubOrganization}>
              {m.isPending ? "Saving..." : "Save"}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

