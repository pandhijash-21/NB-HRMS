"use client";

import { useState } from "react";
import Link from "next/link";
import {
  usePayCommissions,
  useCreatePayCommission,
  useUpdatePayCommission,
} from "@/lib/hooks/useSalary";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { toast } from "sonner";

function slugCode(name: string) {
  return name
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, "_")
    .replace(/^_|_$/g, "");
}

export default function PayCommissionsPage() {
  const { data: commissions, isLoading } = usePayCommissions();
  const createCommission = useCreatePayCommission();
  const updateCommission = useUpdatePayCommission();

  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [description, setDescription] = useState("");
  const [ruleEditorEnabled, setRuleEditorEnabled] = useState(true);
  const [cloneFrom, setCloneFrom] = useState<string>("");

  const resetForm = () => {
    setName("");
    setCode("");
    setDescription("");
    setRuleEditorEnabled(true);
    setCloneFrom("");
  };

  const handleCreate = async () => {
    if (!name.trim() || !code.trim()) {
      toast.error("Name and code are required");
      return;
    }
    try {
      await createCommission.mutateAsync({
        name: name.trim(),
        code: code.trim(),
        description: description.trim() || null,
        ruleEditorEnabled,
        cloneFromCommissionId: cloneFrom || null,
      });
      toast.success("Pay commission created");
      setOpen(false);
      resetForm();
    } catch (err: any) {
      toast.error(err.response?.data?.message ?? "Failed to create commission");
    }
  };

  const toggleActive = async (id: string, isActive: boolean) => {
    try {
      await updateCommission.mutateAsync({ id, isActive });
      toast.success(isActive ? "Commission activated" : "Commission deactivated");
    } catch (err: any) {
      toast.error(err.response?.data?.message ?? "Update failed");
    }
  };

  const toggleRuleEditor = async (id: string, enabled: boolean) => {
    try {
      await updateCommission.mutateAsync({ id, ruleEditorEnabled: enabled });
      toast.success(enabled ? "Rule editor enabled" : "Rule editor disabled — fixed amounts only");
    } catch (err: any) {
      toast.error(err.response?.data?.message ?? "Update failed");
    }
  };

  if (isLoading) return <p className="text-sm text-slate-500">Loading pay commissions…</p>;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Pay Commissions</h1>
          <p className="text-sm text-slate-500 mt-1">
            Manage 5th, 6th, 7th pay and custom commissions. Add or remove salary columns per commission.
          </p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Link href="/admin/salary/structures">
            <Button variant="outline" size="sm">Salary Structures</Button>
          </Link>
          <Button size="sm" onClick={() => setOpen(true)}>Add Commission</Button>
        </div>
      </div>

      <div className="grid gap-4">
        {(commissions ?? []).map((pc) => (
          <Card key={pc.id} className="p-4 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
            <div className="space-y-2">
              <div className="flex items-center gap-2 flex-wrap">
                <h2 className="font-semibold text-slate-800">{pc.name}</h2>
                <Badge variant="outline" className="font-mono text-[10px]">{pc.code}</Badge>
                {!pc.isActive && <Badge variant="secondary">Inactive</Badge>}
              </div>
              {pc.description && <p className="text-xs text-slate-500">{pc.description}</p>}
              <p className="text-xs text-slate-400">
                {pc._count?.columnDefinitions ?? 0} columns · {pc._count?.salaryStructureTemplates ?? 0} structure templates
              </p>
            </div>

            <div className="flex flex-col sm:flex-row sm:items-center gap-4">
              <div className="flex items-center gap-2">
                <Switch
                  checked={pc.isActive}
                  onCheckedChange={(v) => toggleActive(pc.id, v)}
                />
                <span className="text-xs text-slate-600">Active</span>
              </div>
              <div className="flex items-center gap-2">
                <Switch
                  checked={pc.ruleEditorEnabled}
                  onCheckedChange={(v) => toggleRuleEditor(pc.id, v)}
                />
                <span className="text-xs text-slate-600">Rule editor (conditions)</span>
              </div>
              <Link href={`/admin/salary/commissions/${pc.id}`}>
                <Button variant="outline" size="sm">Manage Columns</Button>
              </Link>
            </div>
          </Card>
        ))}
      </div>

      <Dialog open={open} onOpenChange={(o) => { setOpen(o); if (!o) resetForm(); }}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Add Pay Commission</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-1">
              <Label>Name</Label>
              <Input
                placeholder="7th Pay Commission"
                value={name}
                onChange={(e) => {
                  setName(e.target.value);
                  if (!code || code === slugCode(name)) setCode(slugCode(e.target.value));
                }}
              />
            </div>
            <div className="space-y-1">
              <Label>Code</Label>
              <Input
                placeholder="SEVENTH"
                value={code}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
                className="font-mono uppercase"
              />
              <p className="text-[10px] text-slate-400">Used in URLs and employee assignment (e.g. FIFTH, SIXTH, SEVENTH)</p>
            </div>
            <div className="space-y-1">
              <Label>Description (optional)</Label>
              <Input value={description} onChange={(e) => setDescription(e.target.value)} />
            </div>
            <div className="space-y-1">
              <Label>Clone columns from</Label>
              <Select value={cloneFrom || "__none__"} onValueChange={(v) => setCloneFrom(v === "__none__" ? "" : v)}>
                <SelectTrigger><SelectValue placeholder="Start empty or copy existing" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="__none__">Start empty</SelectItem>
                  {(commissions ?? []).map((c) => (
                    <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center gap-2">
              <Switch checked={ruleEditorEnabled} onCheckedChange={setRuleEditorEnabled} />
              <Label className="font-normal">Enable advanced rule editor (conditions, percentages)</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setOpen(false)}>Cancel</Button>
            <Button onClick={handleCreate} disabled={createCommission.isPending}>
              {createCommission.isPending ? "Creating…" : "Create"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
