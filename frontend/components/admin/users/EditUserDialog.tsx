"use client";

import { useEffect, useState } from "react";
import { useUserMgmtActions, User } from "@/lib/hooks/useUserMgmt";
import { useRolesList } from "@/lib/hooks/useRole";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

export function EditUserDialog({ 
  user, 
  open, 
  onOpenChange,
  onUserUpdated 
}: { 
  user: User | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onUserUpdated: () => void;
}) {
  const [roleId, setRoleId] = useState("");
  const [isActive, setIsActive] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  const { updateUser } = useUserMgmtActions();
  const { roles, loading: rolesLoading } = useRolesList();

  useEffect(() => {
    if (user) {
      setRoleId(user.roleId);
      setIsActive(user.isActive);
    }
  }, [user]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setSubmitting(true);
    try {
      await updateUser(user.id, { roleId, isActive });
      onOpenChange(false);
      onUserUpdated();
    } catch (err: any) {
      alert(err?.response?.data?.message || err.message || "Failed to update user");
    } finally {
      setSubmitting(false);
    }
  };

  if (!user) return null;
  const displayName = user.employee?.fullName ?? user.username ?? `User ${user.id.slice(0, 8)}`;
  const subtitle = user.employee
    ? `${user.employee.employeeCode} - ${user.employee.designation}`
    : "Position account (no employee)";

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="w-full p-6 sm:max-w-[min(98vw,88rem)] sm:p-8">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold text-[#1d3459]">Edit User Account</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4 mt-4">
          <div className="space-y-1 bg-slate-50 p-3 rounded-lg border border-slate-100 mb-4">
            <p className="text-sm font-bold text-slate-800">{displayName}</p>
            <p className="text-xs text-slate-500">{subtitle}</p>
          </div>
          
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Role</label>
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

          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-500 uppercase">Status</label>
            <Select value={isActive ? "true" : "false"} onValueChange={(val) => setIsActive(val === "true")}>
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Select status..." />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="true">Active (Can Login)</SelectItem>
                <SelectItem value="false">Inactive (Suspended)</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="pt-4 flex justify-end gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              className="text-xs font-bold uppercase"
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={submitting}
              className="bg-[#d9b557] hover:bg-[#c4a148] text-[#1d3459] text-xs font-bold uppercase"
            >
              {submitting ? "Saving..." : "Save Changes"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
