"use client";

import { useState } from "react";
import {
  usePositionSlots,
  useCreatePositionSlot,
  useAssignPositionHolder,
  useDesignations,
} from "@/lib/hooks/useDesignations";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import api from "@/lib/axios";
import { useQuery } from "@tanstack/react-query";

export default function AdminPositionSlotsPage() {
  const slots = usePositionSlots();
  const aliasDesignations = useDesignations(true);
  const create = useCreatePositionSlot();
  const assign = useAssignPositionHolder();

  const [code, setCode] = useState("");
  const [name, setName] = useState("");
  const [designationId, setDesignationId] = useState("");
  const [linkedRoleId, setLinkedRoleId] = useState("");
  const [subOrganization, setSubOrganization] = useState("");
  const [password, setPassword] = useState("01011998");
  const [assignSlotId, setAssignSlotId] = useState("");
  const [holderEmployeeId, setHolderEmployeeId] = useState("");
  const [effectiveFrom, setEffectiveFrom] = useState(new Date().toISOString().slice(0, 10));

  const rolesQ = useQuery({
    queryKey: ["roles-list"],
    queryFn: async () => {
      const { data } = await api.get("admin/roles");
      return data.data as Array<{ id: string; name: string }>;
    },
  });

  const handleCreate = async () => {
    await create.mutateAsync({
      code,
      name,
      designationId,
      linkedRoleId,
      subOrganization: subOrganization || undefined,
      password,
    });
    setCode("");
    setName("");
  };

  const handleAssign = async () => {
    await assign.mutateAsync({
      slotId: assignSlotId,
      holderEmployeeId: Number(holderEmployeeId),
      effectiveFrom,
    });
    setHolderEmployeeId("");
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Position Slots</h1>
        <p className="text-sm text-slate-500">Shared institutional accounts (HOI-GIT, VC, etc.) login via username.</p>
      </div>

      <Card className="p-4 space-y-3">
        <h2 className="font-semibold text-sm">Create Position Slot</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div className="space-y-1">
            <Label>Login Code (username)</Label>
            <Input value={code} onChange={(e) => setCode(e.target.value)} placeholder="HOI-GIT" />
          </div>
          <div className="space-y-1">
            <Label>Display Name</Label>
            <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Head of Institute — GIT" />
          </div>
          <div className="space-y-1">
            <Label>Institute</Label>
            <Input value={subOrganization} onChange={(e) => setSubOrganization(e.target.value)} />
          </div>
          <div className="space-y-1">
            <Label>Alias Designation</Label>
            <Select value={designationId} onValueChange={setDesignationId}>
              <SelectTrigger><SelectValue placeholder="Select" /></SelectTrigger>
              <SelectContent>
                {(aliasDesignations.data ?? []).map((d) => (
                  <SelectItem key={d.id} value={d.id}>{d.name}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1">
            <Label>Role</Label>
            <Select value={linkedRoleId} onValueChange={setLinkedRoleId}>
              <SelectTrigger><SelectValue placeholder="Select role" /></SelectTrigger>
              <SelectContent>
                {(rolesQ.data ?? []).map((r) => (
                  <SelectItem key={r.id} value={r.id}>{r.name}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1">
            <Label>Initial Password</Label>
            <Input value={password} onChange={(e) => setPassword(e.target.value)} type="password" />
          </div>
        </div>
        <Button onClick={handleCreate} disabled={create.isPending || !code || !designationId || !linkedRoleId}>
          Create Slot
        </Button>
      </Card>

      <Card className="p-4 space-y-3">
        <h2 className="font-semibold text-sm">Assign Holder</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3 items-end">
          <div className="space-y-1">
            <Label>Slot</Label>
            <Select value={assignSlotId} onValueChange={setAssignSlotId}>
              <SelectTrigger><SelectValue placeholder="Select slot" /></SelectTrigger>
              <SelectContent>
                {(slots.data ?? []).map((s) => (
                  <SelectItem key={s.id} value={s.id}>{s.code}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1">
            <Label>Holder Employee ID</Label>
            <Input value={holderEmployeeId} onChange={(e) => setHolderEmployeeId(e.target.value)} />
          </div>
          <div className="space-y-1">
            <Label>Effective From</Label>
            <Input type="date" value={effectiveFrom} onChange={(e) => setEffectiveFrom(e.target.value)} />
          </div>
          <Button onClick={handleAssign} disabled={assign.isPending || !assignSlotId}>Assign</Button>
        </div>
      </Card>

      <Card className="p-4">
        <h2 className="font-semibold text-sm mb-3">Existing Slots</h2>
        <div className="space-y-3">
          {(slots.data ?? []).map((s) => (
            <div key={s.id} className="border rounded-lg p-3 flex justify-between items-start">
              <div>
                <p className="font-medium">{s.code}</p>
                <p className="text-sm text-slate-500">{s.name}</p>
                <p className="text-xs text-slate-400">{s.designation.name} · {s.linkedRole.name}</p>
                {s.assignments?.[0] && (
                  <p className="text-xs mt-1">
                    Holder: {s.assignments[0].holderEmployee.generalInfo?.fullName ?? `Employee #${s.assignments[0].holderEmployee.id}`}
                  </p>
                )}
              </div>
              <div className="text-xs text-slate-400">User: {s.user?.username ?? "—"}</div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
