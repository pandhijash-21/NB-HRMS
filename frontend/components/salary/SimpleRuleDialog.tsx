"use client";

import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { SalaryColumnDefinition } from "@/lib/hooks/useSalary";

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  column: SalaryColumnDefinition;
  defaultValue?: number;
  onSave: (body: { rule_type: "FIXED"; default_value: number }) => Promise<void>;
};

export function SimpleRuleDialog({ open, onOpenChange, column, defaultValue, onSave }: Props) {
  const [value, setValue] = useState(String(defaultValue ?? 0));
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    setSaving(true);
    try {
      await onSave({ rule_type: "FIXED", default_value: Number(value) || 0 });
      onOpenChange(false);
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Set amount — {column.displayName}</DialogTitle>
        </DialogHeader>
        <p className="text-xs text-slate-500">
          Advanced rule editor is disabled for this pay commission. Enter a fixed default amount.
        </p>
        <div className="space-y-2">
          <Label>Default amount (₹)</Label>
          <Input
            type="number"
            min={0}
            step="0.01"
            value={value}
            onChange={(e) => setValue(e.target.value)}
          />
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving ? "Saving…" : "Save"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
