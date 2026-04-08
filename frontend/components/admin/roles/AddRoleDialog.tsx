"use client";

import { useState } from "react";
import { useRoleMgmtActions } from "@/lib/hooks/useRole";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Plus } from "lucide-react";
import { Textarea } from "@/components/ui/textarea";

export function AddRoleDialog({ onRoleAdded }: { onRoleAdded: () => void }) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const { createRole } = useRoleMgmtActions();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name) return alert("Role name is required");

    setSubmitting(true);
    try {
      await createRole({ name: name.toUpperCase(), description });
      setOpen(false);
      setName("");
      setDescription("");
      onRoleAdded();
    } catch (err: any) {
      alert(err?.response?.data?.message || err.message || "Failed to create role");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="bg-[#1d3459] hover:bg-[#2a4a7f] text-white text-xs font-bold uppercase tracking-wider h-10 px-4 rounded-xl shadow-md">
          <Plus className="w-4 h-4 mr-2" />
          Add Role
        </Button>
      </DialogTrigger>
      <DialogContent className="w-full p-6 sm:max-w-[min(98vw,88rem)] sm:p-8">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold text-[#1d3459]">Create New Role</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4 mt-4">
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Role Name</label>
            <Input
              type="text"
              placeholder="e.g. HR_MANAGER"
              value={name}
              onChange={(e) => setName(e.target.value.toUpperCase().replace(/\s+/g, "_"))}
              className="border-slate-200"
              required
            />
            <p className="text-[10px] text-slate-400">Must be uppercase with underscores only.</p>
          </div>
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Description</label>
            <Textarea
              placeholder="Brief description of the role operations..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="border-slate-200 resize-none h-20"
            />
          </div>
          
          <div className="pt-4 flex justify-end gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              className="text-xs font-bold uppercase"
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={submitting || !name}
              className="bg-[#d9b557] hover:bg-[#c4a148] text-[#1d3459] text-xs font-bold uppercase"
            >
              {submitting ? "Creating..." : "Create Role"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
