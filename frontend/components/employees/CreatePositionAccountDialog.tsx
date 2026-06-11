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
import { Shield } from "lucide-react";

export function CreatePositionAccountDialog({ onCreated }: { onCreated?: () => void }) {
  const [open, setOpen] = useState(false);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [roleId, setRoleId] = useState("");
  const [subOrganization, setSubOrganization] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const { createUser } = useUserMgmtActions();
  const { roles, loading: rolesLoading } = useRolesList();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password || !roleId) return;

    setSubmitting(true);
    try {
      await createUser({ username: username.trim(), password, roleId, subOrganization: subOrganization.trim() || undefined });
      setOpen(false);
      setUsername("");
      setPassword("");
      setRoleId("");
      setSubOrganization("");
      onCreated?.();
    } catch (err: any) {
      alert(err?.response?.data?.message || err.message || "Failed to create position account");
    } finally {
      setSubmitting(false);
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
      <DialogContent className="w-full p-6 sm:max-w-[min(98vw,52rem)] sm:p-8">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold text-[#1d3459]">Create Position Account</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 mt-4">
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Username</label>
            <Input
              placeholder="e.g. HOD_CE_IT"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="border-slate-200"
              required
            />
            <p className="text-[10px] text-slate-400">
              This is the login identifier for the position (not tied to an employee).
            </p>
          </div>

          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Password</label>
            <Input
              type="password"
              placeholder="Set an initial password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="border-slate-200"
              required
            />
          </div>

          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Role</label>
            <Select value={roleId} onValueChange={setRoleId} disabled={rolesLoading}>
              <SelectTrigger className="w-full">
                <SelectValue placeholder={rolesLoading ? "Loading roles..." : "Select a role..."} />
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

          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Sub Organization (Institute)</label>
            <Input
              placeholder="e.g. GIT"
              value={subOrganization}
              onChange={(e) => setSubOrganization(e.target.value)}
              className="border-slate-200"
            />
            <p className="text-[10px] text-slate-400">
              Optional. If set (e.g. GIT), this position account will only see employees under that sub-organization.
            </p>
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
              disabled={submitting || !username.trim() || !password || !roleId}
              className="bg-[#d9b557] hover:bg-[#c4a148] text-[#1d3459] text-xs font-bold uppercase"
            >
              {submitting ? "Creating..." : "Create Position"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}

