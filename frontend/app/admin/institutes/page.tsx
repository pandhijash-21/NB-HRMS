"use client";

import { useState } from "react";
import Link from "next/link";
import { useInstitutes, useInstituteMutations } from "@/lib/hooks/useInstitutes";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Building2, ChevronRight } from "lucide-react";
import { toast } from "sonner";

export default function AdminInstitutesPage() {
  const { data: institutes = [], isLoading, refetch } = useInstitutes({ admin: true, activeOnly: false });
  const { create, update } = useInstituteMutations();

  const [code, setCode] = useState("");
  const [name, setName] = useState("");

  const handleCreate = async () => {
    if (!code.trim() || !name.trim()) return;
    try {
      await create.mutateAsync({ code: code.trim(), name: name.trim() });
      toast.success("Institute added");
      setCode("");
      setName("");
      refetch();
    } catch (err: unknown) {
      const ax = err as { response?: { data?: { message?: string } } };
      toast.error(ax.response?.data?.message || "Failed to add institute");
    }
  };

  const toggleActive = async (id: string, isActive: boolean) => {
    try {
      await update.mutateAsync({ id, isActive });
      refetch();
    } catch {
      toast.error("Failed to update institute");
    }
  };

  return (
    <div className="space-y-6 max-w-4xl">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Institutes</h1>
        <p className="text-sm text-slate-500 mt-1">
          Configure campuses / sub-organizations. Click an institute to see its employees and alias accounts.
        </p>
      </div>

      <Card className="p-4 space-y-3">
        <h2 className="font-semibold text-sm">Add institute</h2>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 items-end">
          <div className="space-y-1">
            <Label>Code</Label>
            <Input
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              placeholder="GIT"
            />
          </div>
          <div className="space-y-1">
            <Label>Full name</Label>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Gandhinagar Institute of Technology"
            />
          </div>
          <Button onClick={handleCreate} disabled={create.isPending || !code.trim() || !name.trim()}>
            Add
          </Button>
        </div>
      </Card>

      <Card className="p-4">
        <h2 className="font-semibold text-sm mb-3">All institutes</h2>
        {isLoading ? (
          <p className="text-sm text-slate-400">Loading…</p>
        ) : institutes.length === 0 ? (
          <p className="text-sm text-slate-400">No institutes configured yet.</p>
        ) : (
          <div className="space-y-1">
            {institutes.map((inst) => (
              <div
                key={inst.id}
                className={`flex items-center justify-between border-b py-3 gap-4 ${!inst.isActive ? "opacity-60" : ""}`}
              >
                <Link
                  href={`/admin/institutes/${inst.id}`}
                  className="flex items-center gap-3 flex-1 min-w-0 group"
                >
                  <div className="h-9 w-9 rounded-lg bg-[#1d3459]/10 flex items-center justify-center shrink-0">
                    <Building2 className="h-4 w-4 text-[#1d3459]" />
                  </div>
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-slate-800 group-hover:text-[#1d3459] truncate">
                      {inst.name}
                    </p>
                    <p className="text-xs font-mono text-slate-400">{inst.code}</p>
                  </div>
                  <ChevronRight className="h-4 w-4 text-slate-300 group-hover:text-[#1d3459] shrink-0" />
                </Link>
                <div className="flex items-center gap-3 shrink-0">
                  {!inst.isActive && <Badge variant="secondary">Inactive</Badge>}
                  <div className="flex items-center gap-2">
                    <Switch
                      checked={inst.isActive}
                      onCheckedChange={(checked) => toggleActive(inst.id, checked)}
                      disabled={update.isPending}
                    />
                    <span className="text-xs text-slate-500">{inst.isActive ? "Active" : "Off"}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
