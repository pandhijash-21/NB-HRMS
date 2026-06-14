"use client";

import { useEffect, useState } from "react";
import { toast } from "sonner";
import { Shield } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { EmployeePositionSelect, formatEmployeePosition } from "@/components/employees/EmployeePositionSelect";
import { useAssignEmployeePosition } from "@/modules/admin/hooks/useAdminEmployees";

type Props = {
  employeeId: string | number;
  currentPosition?: { id: string; name: string; linkedRoleName?: string } | null;
  onUpdated?: () => void;
};

export function EmployeePositionDialog({ employeeId, currentPosition, onUpdated }: Props) {
  const [open, setOpen] = useState(false);
  const [positionId, setPositionId] = useState<string | null>(currentPosition?.id ?? null);
  const assign = useAssignEmployeePosition();

  useEffect(() => {
    if (open) setPositionId(currentPosition?.id ?? null);
  }, [open, currentPosition?.id]);

  const handleSave = async () => {
    try {
      await assign.mutateAsync({
        employeeId,
        positionDesignationId: positionId,
      });
      toast.success("Position updated. Ask the employee to log out and back in.");
      setOpen(false);
      onUpdated?.();
    } catch (err: unknown) {
      const ax = err as { response?: { data?: { message?: string } } };
      toast.error(ax.response?.data?.message || "Failed to update position");
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button
          variant="outline"
          size="sm"
          className="text-xs border-[#1d3459]/20 text-[#1d3459] hover:bg-[#1d3459]/5"
        >
          <Shield className="h-3.5 w-3.5 mr-1.5" />
          Position: {formatEmployeePosition(currentPosition)}
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="text-lg font-bold text-[#1d3459]">Assign Position</DialogTitle>
        </DialogHeader>
        <p className="text-xs text-slate-500 -mt-2">
          Sets this employee&apos;s login permissions from an institutional position. Does not change their job designation.
        </p>
        <EmployeePositionSelect
          value={positionId}
          onValueChange={setPositionId}
          label="Position"
          hint="Staff = regular employee with no admin modules."
        />
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={() => setOpen(false)}>
            Cancel
          </Button>
          <Button
            onClick={handleSave}
            disabled={assign.isPending}
            className="bg-[#d9b557] hover:bg-[#c4a148] text-[#1d3459] font-bold"
          >
            {assign.isPending ? "Saving…" : "Save position"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
