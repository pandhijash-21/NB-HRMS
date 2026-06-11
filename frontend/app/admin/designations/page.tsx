"use client";

import { useState } from "react";
import { useDesignations, useCreateDesignation, useUpdateDesignation } from "@/lib/hooks/useDesignations";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import api from "@/lib/axios";
import { useQuery } from "@tanstack/react-query";

function DesignationActiveSwitch({
  id,
  isActive,
  onToggle,
  disabled,
}: {
  id: string;
  isActive: boolean;
  onToggle: (id: string, next: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <div className="flex items-center gap-2">
      <Switch
        id={`designation-active-${id}`}
        checked={isActive}
        onCheckedChange={(checked) => onToggle(id, checked)}
        disabled={disabled}
      />
      <Label htmlFor={`designation-active-${id}`} className="text-xs text-slate-500 cursor-pointer">
        {isActive ? "Active" : "Inactive"}
      </Label>
    </div>
  );
}

export default function AdminDesignationsPage() {
  const regular = useDesignations(false, { includeInactive: true });
  const aliases = useDesignations(true, { includeInactive: true });
  const create = useCreateDesignation();
  const update = useUpdateDesignation();
  const [name, setName] = useState("");
  const [isAlias, setIsAlias] = useState(false);
  const [linkedRoleId, setLinkedRoleId] = useState("");

  const rolesQ = useQuery({
    queryKey: ["roles-list"],
    queryFn: async () => {
      const { data } = await api.get("admin/roles");
      return data.data as Array<{ id: string; name: string }>;
    },
  });

  const handleCreate = async () => {
    if (!name.trim()) return;
    await create.mutateAsync({
      name: name.trim(),
      isAlias,
      linkedRoleId: isAlias && linkedRoleId ? linkedRoleId : undefined,
    });
    setName("");
    setIsAlias(false);
    setLinkedRoleId("");
  };

  const handleActiveToggle = (id: string, isActive: boolean) => {
    update.mutate({ id, isActive });
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Designation Master</h1>
        <p className="text-sm text-slate-500">
          Regular designations support salary templates; alias designations are for position accounts.
          Inactive designations are hidden from employee onboarding but remain listed here.
        </p>
      </div>

      <Card className="p-4 space-y-3">
        <h2 className="font-semibold text-sm">Add Designation</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3 items-end">
          <div className="space-y-1">
            <Label>Name</Label>
            <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Assistant Professor" />
          </div>
          <div className="flex items-center gap-2">
            <Switch checked={isAlias} onCheckedChange={setIsAlias} id="is-alias" />
            <Label htmlFor="is-alias">Alias designation</Label>
          </div>
          {isAlias && (
            <div className="space-y-1">
              <Label>Linked Role</Label>
              <Select value={linkedRoleId} onValueChange={setLinkedRoleId}>
                <SelectTrigger><SelectValue placeholder="Select role" /></SelectTrigger>
                <SelectContent>
                  {(rolesQ.data ?? []).map((r) => (
                    <SelectItem key={r.id} value={r.id}>{r.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          )}
          <Button onClick={handleCreate} disabled={create.isPending}>Add</Button>
        </div>
      </Card>

      <Card className="p-4">
        <h2 className="font-semibold text-sm mb-3">Regular Designations</h2>
        <div className="space-y-2">
          {(regular.data ?? []).map((d) => (
            <div
              key={d.id}
              className={`flex items-center justify-between border-b py-2 ${!d.isActive ? "opacity-60" : ""}`}
            >
              <div className="flex items-center gap-2">
                <span className="text-sm">{d.name}</span>
                {!d.isActive && <Badge variant="secondary">Inactive</Badge>}
              </div>
              <DesignationActiveSwitch
                id={d.id}
                isActive={d.isActive}
                onToggle={handleActiveToggle}
                disabled={update.isPending}
              />
            </div>
          ))}
        </div>
      </Card>

      <Card className="p-4">
        <h2 className="font-semibold text-sm mb-3">Alias Designations</h2>
        <div className="space-y-2">
          {(aliases.data ?? []).map((d) => (
            <div
              key={d.id}
              className={`flex items-center justify-between border-b py-2 ${!d.isActive ? "opacity-60" : ""}`}
            >
              <div>
                <span className="text-sm">{d.name}</span>
                {d.linkedRole && <span className="text-xs text-slate-400 ml-2">→ {d.linkedRole.name}</span>}
                <Badge variant="outline" className="ml-2">No salary</Badge>
                {!d.isActive && <Badge variant="secondary" className="ml-2">Inactive</Badge>}
              </div>
              <DesignationActiveSwitch
                id={d.id}
                isActive={d.isActive}
                onToggle={handleActiveToggle}
                disabled={update.isPending}
              />
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
