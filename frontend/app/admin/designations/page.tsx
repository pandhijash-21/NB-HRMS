"use client";

import { useState } from "react";
import Link from "next/link";
import {
  useDesignations,
  useCreateDesignation,
  useUpdateDesignation,
  usePositionSlots,
} from "@/lib/hooks/useDesignations";
import { AliasAccountForm } from "@/components/positions/AliasAccountForm";
import { AliasAccountDetailDialog } from "@/components/positions/AliasAccountDetailDialog";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";

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
  const positions = useDesignations(true, { includeInactive: true });
  const aliasSlots = usePositionSlots();
  const create = useCreateDesignation();
  const update = useUpdateDesignation();
  const [name, setName] = useState("");
  const [detailSlotId, setDetailSlotId] = useState<string | null>(null);

  const handleCreateDesignation = async () => {
    if (!name.trim()) return;
    await create.mutateAsync({ name: name.trim() });
    setName("");
  };

  const handleActiveToggle = (id: string, isActive: boolean) => {
    update.mutate({ id, isActive });
  };

  return (
    <div className="space-y-6 max-w-5xl">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Designations</h1>
        <p className="text-sm text-slate-500 mt-1">
          <strong>Step 1:</strong> Create a position from{" "}
          <Link href="/admin/employees" className="text-[#1d3459] underline font-medium">Workforce → Create Position</Link>
          {" "}and set permissions in{" "}
          <Link href="/admin/roles" className="text-[#1d3459] underline font-medium">Roles &amp; Permissions</Link>.
          <br />
          <strong>Step 2:</strong> Below, create <strong>alias accounts</strong> (HOI-GIT, HOI-GIM, …) and pick which position they belong to.
        </p>
      </div>

      {/* Job designations */}
      <Card className="p-4 space-y-3">
        <h2 className="font-semibold text-sm">Add job designation</h2>
        <p className="text-xs text-slate-400">For employees (Professor, Clerk, …). Supports salary structures.</p>
        <div className="flex flex-col sm:flex-row gap-3 items-end">
          <div className="flex-1 space-y-1">
            <Label>Name</Label>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Assistant Professor"
            />
          </div>
          <Button onClick={handleCreateDesignation} disabled={create.isPending || !name.trim()}>
            Add
          </Button>
        </div>
      </Card>

      <Card className="p-4">
        <h2 className="font-semibold text-sm mb-3">Job designations</h2>
        <div className="space-y-2">
          {(regular.data ?? []).map((d) => (
            <div
              key={d.id}
              className={`flex items-center justify-between border-b py-2 ${!d.isActive ? "opacity-60" : ""}`}
            >
              <span className="text-sm">{d.name}</span>
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

      {/* Positions reference */}
      {(positions.data ?? []).length > 0 && (
        <Card className="p-4">
          <h2 className="font-semibold text-sm mb-2">Positions</h2>
          <p className="text-xs text-slate-400 mb-3">
            Created from Workforce. Edit what each can do in Roles &amp; Permissions.
          </p>
          <div className="flex flex-wrap gap-2">
            {(positions.data ?? []).map((p) => (
              <div key={p.id} className="border rounded-lg px-3 py-2 text-sm">
                <span className="font-medium">{p.name}</span>
                {p.linkedRole && (
                  <Link href="/admin/roles" className="ml-2 text-[10px] font-bold uppercase text-[#1d3459] underline">
                    {p.linkedRole.name}
                  </Link>
                )}
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Alias accounts */}
      <Card className="p-4 space-y-4" id="alias-accounts">
        <div>
          <h2 className="font-semibold text-sm">Alias accounts</h2>
          <p className="text-xs text-slate-400 mt-1">
            Institute logins (e.g. 18 HOI accounts for 18 institutes). Each picks a position and inherits its permissions.
          </p>
        </div>
        <AliasAccountForm onCreated={() => aliasSlots.refetch()} />

        <div className="border-t pt-4">
          <h3 className="text-xs font-bold text-slate-500 uppercase tracking-widest mb-3">Existing alias accounts</h3>
          {(aliasSlots.data ?? []).length === 0 ? (
            <p className="text-sm text-slate-400">None yet.</p>
          ) : (
            <div className="space-y-2">
              {(aliasSlots.data ?? []).map((s) => (
                <button
                  key={s.id}
                  type="button"
                  onClick={() => setDetailSlotId(s.id)}
                  className="w-full text-left flex justify-between items-start border rounded-lg p-3 gap-4 hover:border-[#1d3459]/30 hover:bg-slate-50/50 transition-colors"
                >
                  <div>
                    <p className="font-mono font-bold text-sm text-[#1d3459]">{s.code}</p>
                    <p className="text-xs text-slate-600">{s.name}</p>
                    <p className="text-[10px] text-slate-400 mt-1">
                      Position: {s.designation.name} · Role: {s.linkedRole.name}
                      {s.subOrganization ? ` · ${s.subOrganization}` : " · University-wide"}
                    </p>
                  </div>
                  <Badge className={s.user?.isActive ? "bg-emerald-100 text-emerald-700" : "bg-slate-100"}>
                    {s.user?.isActive ? "Active" : "Inactive"}
                  </Badge>
                </button>
              ))}
            </div>
          )}
        </div>
      </Card>

      <AliasAccountDetailDialog
        slotId={detailSlotId}
        open={!!detailSlotId}
        onOpenChange={(open) => { if (!open) setDetailSlotId(null); }}
      />
    </div>
  );
}
