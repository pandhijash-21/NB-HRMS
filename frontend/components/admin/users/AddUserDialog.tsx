"use client";

import { useState } from "react";
import { useUserMgmtActions } from "@/lib/hooks/useUserMgmt";
import { useRolesList } from "@/lib/hooks/useRole";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Plus } from "lucide-react";

export function AddUserDialog({ onUserAdded }: { onUserAdded: () => void }) {
  const [open, setOpen] = useState(false);
  const [employeeId, setEmployeeId] = useState("");
  const [roleId, setRoleId] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const { createUser } = useUserMgmtActions();
  const { roles, loading: rolesLoading } = useRolesList();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!employeeId || !roleId) return alert("Please fill all fields");

    setSubmitting(true);
    try {
      await createUser({ employeeId: parseInt(employeeId, 10), roleId });
      setOpen(false);
      setEmployeeId("");
      setRoleId("");
      onUserAdded();
    } catch (err: any) {
      alert(err?.response?.data?.message || err.message || "Failed to create user");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="bg-[#1d3459] hover:bg-[#2a4a7f] text-white text-xs font-bold uppercase tracking-wider h-10 px-4 rounded-xl shadow-md">
          <Plus className="w-4 h-4 mr-2" />
          Add User
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold text-[#1d3459]">Create User Account</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4 mt-4">
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Employee ID</label>
            <Input
              type="number"
              placeholder="e.g. 1"
              value={employeeId}
              onChange={(e) => setEmployeeId(e.target.value)}
              className="border-slate-200"
              required
            />
            <p className="text-[10px] text-slate-400">The internal employee ID (numeric)</p>
          </div>
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Assign Role</label>
            <Select value={roleId} onValueChange={setRoleId} disabled={rolesLoading}>
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Select a role..." />
              </SelectTrigger>
              <SelectContent>
                {roles.map((role) => (
                  <SelectItem key={role.id} value={role.id}>
                    {role.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
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
              disabled={submitting || !employeeId || !roleId}
              className="bg-[#d9b557] hover:bg-[#c4a148] text-[#1d3459] text-xs font-bold uppercase"
            >
              {submitting ? "Creating..." : "Create Account"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
