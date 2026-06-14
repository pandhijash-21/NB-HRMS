"use client";

import { useState } from "react";
import Link from "next/link";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Shield } from "lucide-react";
import { useCreatePosition } from "@/lib/hooks/useDesignations";
import { toast } from "sonner";

export function CreatePositionDialog({ onCreated }: { onCreated?: () => void }) {
  const [open, setOpen] = useState(false);
  const [displayName, setDisplayName] = useState("");
  const [roleName, setRoleName] = useState("");
  const [description, setDescription] = useState("");
  const create = useCreatePosition();

  const suggestRoleCode = (label: string) => {
    const words = label.trim().split(/\s+/).filter(Boolean);
    if (words.length === 0) return "";
    if (words.length === 1) return words[0].toUpperCase().slice(0, 12);
    return words.map((w) => w[0]).join("").toUpperCase();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!displayName.trim() || !roleName.trim()) return;

    try {
      const result = await create.mutateAsync({
        displayName: displayName.trim(),
        roleName: roleName.trim(),
        description: description.trim() || undefined,
      });
      toast.success(
        <span>
          Position <strong>{displayName}</strong> created.{" "}
          <Link href={`/admin/roles/${result.role.id}`} className="underline font-bold">
            Set permissions →
          </Link>
        </span>,
        { duration: 8000 },
      );
      setOpen(false);
      setDisplayName("");
      setRoleName("");
      setDescription("");
      onCreated?.();
    } catch (err: unknown) {
      const ax = err as { response?: { data?: { message?: string; error?: string } } };
      toast.error(
        ax.response?.data?.error ||
          ax.response?.data?.message ||
          (err instanceof Error ? err.message : "Failed to create position"),
      );
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button
          variant="outline"
          className="h-11 px-5 rounded-xl text-xs font-bold uppercase tracking-widest border-slate-200"
        >
          <Shield className="h-4 w-4 mr-2" />
          Create Position
        </Button>
      </DialogTrigger>
      <DialogContent className="w-full p-6 sm:max-w-[min(98vw,40rem)] sm:p-8">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold text-[#1d3459]">Create Position</DialogTitle>
        </DialogHeader>
        <p className="text-xs text-slate-500 -mt-2">
          Adds a role in <strong>Roles &amp; Permissions</strong> (edit what this position can do).
          Then create per-institute alias logins (HOI-GIT, …) under <strong>Designations → Alias accounts</strong>.
        </p>

        <form onSubmit={handleSubmit} className="space-y-4 mt-4">
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Position name</label>
            <Input
              placeholder="e.g. Head of Institute"
              value={displayName}
              onChange={(e) => {
                setDisplayName(e.target.value);
                if (!roleName || roleName === suggestRoleCode(displayName)) {
                  setRoleName(suggestRoleCode(e.target.value));
                }
              }}
              required
            />
          </div>
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Role code</label>
            <Input
              placeholder="e.g. HOI"
              value={roleName}
              onChange={(e) => setRoleName(e.target.value.toUpperCase().replace(/\s+/g, "_"))}
              required
            />
            <p className="text-[10px] text-slate-400">
              Shows in Roles &amp; Permissions. If the role code already exists (e.g. EMPLOYEE, HR), it will be linked as a position.
            </p>
          </div>
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Description (optional)</label>
            <Textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="resize-none h-20"
              placeholder="Head of Institute for each campus"
            />
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={create.isPending || !displayName.trim() || !roleName.trim()}
              className="bg-[#d9b557] hover:bg-[#c4a148] text-[#1d3459] font-bold"
            >
              {create.isPending ? "Creating…" : "Create position"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
