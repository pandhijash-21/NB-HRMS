"use client";

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { usePositions } from "@/lib/hooks/useDesignations";

const STAFF_VALUE = "__STAFF__";

type Props = {
  value: string | null | undefined;
  onValueChange: (positionDesignationId: string | null) => void;
  disabled?: boolean;
  label?: string;
  hint?: string;
  className?: string;
};

export function EmployeePositionSelect({
  value,
  onValueChange,
  disabled,
  label = "Position (permissions)",
  hint = "Controls admin portal access. Job designation is separate.",
  className,
}: Props) {
  const { data: positions = [], isLoading } = usePositions();

  const selectValue = value && value.length > 0 ? value : STAFF_VALUE;

  return (
    <div className={`space-y-2 ${className ?? ""}`}>
      <Label className="text-[10px] font-bold text-slate-400 uppercase ml-1">{label}</Label>
      <Select
        value={selectValue}
        onValueChange={(v) => onValueChange(v === STAFF_VALUE ? null : v)}
        disabled={disabled || isLoading}
      >
        <SelectTrigger className="rounded-xl border-slate-200/60 bg-white h-11 text-sm font-medium">
          <SelectValue placeholder={isLoading ? "Loading positions…" : "Staff (no admin position)"} />
        </SelectTrigger>
        <SelectContent className="rounded-xl border-slate-100 shadow-xl max-h-[240px]">
          <SelectItem value={STAFF_VALUE} className="text-[10px] font-medium py-2">
            Staff — no admin position
          </SelectItem>
          {positions.map((p) => (
            <SelectItem key={p.id} value={p.id} className="text-[10px] font-medium py-2">
              {p.name}
              <span className="text-slate-400 ml-1">({p.linkedRoleName})</span>
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      {hint ? <p className="text-[9px] text-slate-400 uppercase ml-1">{hint}</p> : null}
    </div>
  );
}

export function formatEmployeePosition(
  position?: { name: string; linkedRoleName?: string } | null,
): string {
  if (!position?.name) return "Staff";
  return position.linkedRoleName ? `${position.name} (${position.linkedRoleName})` : position.name;
}
