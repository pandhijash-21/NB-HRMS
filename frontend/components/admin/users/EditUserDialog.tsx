"use client";

import { useEffect, useState } from "react";
import { useUserMgmtActions, User } from "@/lib/hooks/useUserMgmt";
import { usePositions } from "@/lib/hooks/useDesignations";
import { useAssignEmployeePosition } from "@/modules/admin/hooks/useAdminEmployees";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { KeyRound } from "lucide-react";
import { AccountCredentialsDialog } from "@/components/admin/AccountCredentialsDialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { EmployeePositionSelect } from "@/components/employees/EmployeePositionSelect";

export function EditUserDialog({
  user,
  open,
  onOpenChange,
  onUserUpdated,
}: {
  user: User | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onUserUpdated: () => void;
}) {
  const [positionDesignationId, setPositionDesignationId] = useState<string | null>(null);
  const [isActive, setIsActive] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [showCreds, setShowCreds] = useState(false);

  const { updateUser } = useUserMgmtActions();
  const { data: positions = [] } = usePositions();
  const assignPosition = useAssignEmployeePosition();

  const isEmployeeAccount = Boolean(user?.employeeId);

  useEffect(() => {
    if (!user) return;
    setIsActive(user.isActive);
    if (isEmployeeAccount && user.roleId) {
      const match = positions.find((p) => p.linkedRoleId === user.roleId);
      setPositionDesignationId(match?.id ?? null);
    }
  }, [user, positions, isEmployeeAccount]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setSubmitting(true);
    try {
      if (isEmployeeAccount && user.employeeId) {
        const currentMatch = positions.find((p) => p.linkedRoleId === user.roleId);
        const currentId = currentMatch?.id ?? null;
        if (positionDesignationId !== currentId) {
          await assignPosition.mutateAsync({
            employeeId: user.employeeId,
            positionDesignationId,
          });
        }
      }

      if (isActive !== user.isActive) {
        await updateUser(user.id, { isActive });
      }

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

          <Button
            type="button"
            variant="outline"
            className="w-full justify-start text-[#1d3459] border-[#1d3459]/20"
            onClick={() => setShowCreds(true)}
          >
            <KeyRound className="h-4 w-4 mr-2" />
            View login &amp; password
          </Button>

          {isEmployeeAccount ? (
            <EmployeePositionSelect
              value={positionDesignationId}
              onValueChange={setPositionDesignationId}
              label="Position"
              hint="Staff = regular employee login with no admin modules."
            />
          ) : (
            <div className="space-y-2">
              <label className="text-xs font-bold text-slate-500 uppercase">Role (alias account)</label>
              <Select value={user.roleId} disabled>
                <SelectTrigger className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={user.roleId}>{user.role?.name ?? user.roleId}</SelectItem>
                </SelectContent>
              </Select>
              <p className="text-[10px] text-slate-400">
                Alias accounts inherit the position role from their slot. Edit under Designations → Alias accounts.
              </p>
            </div>
          )}

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

        <AccountCredentialsDialog
          userId={user.id}
          title={displayName}
          open={showCreds}
          onOpenChange={setShowCreds}
        />
      </DialogContent>
    </Dialog>
  );
}
