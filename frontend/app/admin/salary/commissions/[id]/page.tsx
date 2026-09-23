"use client";

import { use, useState } from "react";
import Link from "next/link";
import {
  usePayCommission,
  useCreatePayCommissionColumn,
  useDeletePayCommissionColumn,
  useUpdatePayCommission,
  type PayableDaysMode,
} from "@/lib/hooks/useSalary";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { toast } from "sonner";
import { Trash2 } from "lucide-react";

const PAYABLE_DAYS_LABELS: Record<PayableDaysMode, string> = {
  WORKING_DAYS_26_27: "Working days (26 / 27)",
  CALENDAR_30_31: "Calendar days (30 / 31)",
};

export default function PayCommissionColumnsPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { data: pc, isLoading, refetch } = usePayCommission(id);
  const createColumn = useCreatePayCommissionColumn();
  const deleteColumn = useDeletePayCommissionColumn();
  const updateCommission = useUpdatePayCommission();

  const [open, setOpen] = useState(false);
  const [displayName, setDisplayName] = useState("");
  const [columnIdentifier, setColumnIdentifier] = useState("");
  const [category, setCategory] = useState<"EARNING" | "DEDUCTION">("EARNING");
  const [evaluationOrder, setEvaluationOrder] = useState(100);
  const [isRuleConfigurable, setIsRuleConfigurable] = useState(true);

  const columns = pc?.columnDefinitions ?? [];
  const earnings = columns.filter((c) => c.category === "EARNING");
  const deductions = columns.filter((c) => c.category === "DEDUCTION");

  const payableDaysMode: PayableDaysMode = pc?.payableDaysMode ?? "WORKING_DAYS_26_27";

  const resetForm = () => {
    setDisplayName("");
    setColumnIdentifier("");
    setCategory("EARNING");
    setEvaluationOrder((columns.length + 1) * 10);
    setIsRuleConfigurable(true);
  };

  const handlePayableDaysModeChange = async (mode: PayableDaysMode) => {
    try {
      await updateCommission.mutateAsync({ id, payableDaysMode: mode });
      toast.success("Payable days mode updated");
      refetch();
    } catch (err: any) {
      toast.error(err.response?.data?.message ?? "Failed to update payable days mode");
    }
  };

  const handleAdd = async () => {
    if (!displayName.trim()) {
      toast.error("Display name is required");
      return;
    }
    const identifier =
      columnIdentifier.trim() ||
      displayName.trim().toLowerCase().replace(/[^a-z0-9]+/g, "_");
    try {
      await createColumn.mutateAsync({
        payCommissionId: id,
        columnIdentifier: identifier,
        displayName: displayName.trim(),
        category,
        evaluationOrder,
        isRuleConfigurable,
      });
      toast.success("Column added");
      setOpen(false);
      resetForm();
      refetch();
    } catch (err: any) {
      toast.error(err.response?.data?.message ?? "Failed to add column");
    }
  };

  const handleDelete = async (columnId: string, name: string) => {
    if (!confirm(`Remove column "${name}"? Rules using this column will be deleted from all designation templates.`)) {
      return;
    }
    try {
      await deleteColumn.mutateAsync(columnId);
      toast.success("Column removed");
      refetch();
    } catch (err: any) {
      toast.error(err.response?.data?.message ?? "Failed to remove column");
    }
  };

  const renderTable = (title: string, items: typeof columns, accent: string) => (
    <Card className="p-4">
      <h2 className={`font-semibold mb-3 ${accent}`}>{title}</h2>
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b text-left text-slate-500 text-xs">
            <th className="py-2" title="Calculation sequence — lower runs first">Order</th>
            <th className="py-2">Display name</th>
            <th className="py-2">Identifier</th>
            <th className="py-2">Configurable</th>
            <th className="py-2 w-16" />
          </tr>
        </thead>
        <tbody>
          {items.map((col) => (
            <tr key={col.id} className="border-b border-slate-100">
              <td className="py-2 tabular-nums">{col.evaluationOrder}</td>
              <td className="py-2 font-medium">{col.displayName}</td>
              <td className="py-2 font-mono text-xs text-slate-500">{col.columnIdentifier}</td>
              <td className="py-2">
                {col.isRuleConfigurable ? (
                  <Badge variant="secondary">Yes</Badge>
                ) : (
                  <Badge variant="outline">Auto</Badge>
                )}
              </td>
              <td className="py-2">
                <Button
                  size="icon"
                  variant="ghost"
                  className="h-8 w-8 text-rose-600"
                  onClick={() => handleDelete(col.id, col.displayName)}
                >
                  <Trash2 className="w-4 h-4" />
                </Button>
              </td>
            </tr>
          ))}
          {!items.length && (
            <tr>
              <td colSpan={5} className="py-4 text-center text-slate-400 text-xs">No columns yet</td>
            </tr>
          )}
        </tbody>
      </table>
    </Card>
  );

  if (isLoading) return <p className="text-sm text-slate-500">Loading…</p>;
  if (!pc) return <p className="text-sm text-rose-600">Commission not found</p>;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <Link href="/admin/salary/commissions" className="text-sm text-slate-500 hover:text-slate-800">
            ← Pay Commissions
          </Link>
          <h1 className="text-xl font-bold text-slate-800 mt-1">{pc.name}</h1>
          <div className="flex gap-2 mt-1 flex-wrap">
            <Badge variant="outline" className="font-mono">{pc.code}</Badge>
            <Badge variant={pc.ruleEditorEnabled ? "default" : "secondary"}>
              {pc.ruleEditorEnabled ? "Rule editor on" : "Fixed amounts only"}
            </Badge>
          </div>
        </div>
        <Button size="sm" onClick={() => { resetForm(); setOpen(true); }}>Add Column</Button>
      </div>

      <Card className="p-4 space-y-3">
        <div>
          <h2 className="text-sm font-semibold text-slate-800">Payable days mode</h2>
          <p className="text-xs text-slate-500 mt-1">
            Controls how monthly payable days are counted for salary and attendance calculations.
          </p>
        </div>
        <div className="max-w-md space-y-1">
          <Label className="text-xs text-slate-600">Mode</Label>
          <Select
            value={payableDaysMode}
            onValueChange={(v) => handlePayableDaysModeChange(v as PayableDaysMode)}
            disabled={updateCommission.isPending}
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="WORKING_DAYS_26_27">
                {PAYABLE_DAYS_LABELS.WORKING_DAYS_26_27}
              </SelectItem>
              <SelectItem value="CALENDAR_30_31">
                {PAYABLE_DAYS_LABELS.CALENDAR_30_31}
              </SelectItem>
            </SelectContent>
          </Select>
          <p className="text-[11px] text-slate-400 leading-snug">
            {payableDaysMode === "WORKING_DAYS_26_27"
              ? "Uses a fixed working-day base (26 or 27 days depending on the month)."
              : "Uses calendar days in the month (30 or 31)."}
          </p>
        </div>
      </Card>

      <Card className="p-4 bg-slate-50 border-slate-200">
        <h2 className="text-sm font-semibold text-slate-800">About column order</h2>
        <p className="text-xs text-slate-600 mt-2 leading-relaxed">
          <strong>Order</strong> controls the sequence in which each column is calculated and shown.
          Lower numbers run first. Put regular earnings and deductions before totals — e.g. Basic (10),
          other allowances (20–100), <strong>Gross Pay</strong> (~110), individual deductions (200–250),
          then <strong>Total Deductions</strong> (~255) and <strong>Net Pay</strong> (~260) last.
        </p>
        <p className="text-xs text-slate-500 mt-2 leading-relaxed">
          If a rule uses another column (e.g. 10% of Basic), that column must have a <em>lower</em> order number.
          Use gaps of 10 (200, 210, 220…) so you can insert new columns in between without renumbering everything.
        </p>
      </Card>

      {renderTable("Earnings", earnings, "text-emerald-700")}
      {renderTable("Deductions", deductions, "text-rose-700")}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add salary column</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div className="space-y-1">
              <Label>Display name</Label>
              <Input
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="Special Allowance"
              />
            </div>
            <div className="space-y-1">
              <Label>Identifier (optional)</Label>
              <Input
                value={columnIdentifier}
                onChange={(e) => setColumnIdentifier(e.target.value)}
                placeholder="special_allowance"
                className="font-mono text-sm"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Category</Label>
                <Select value={category} onValueChange={(v) => setCategory(v as "EARNING" | "DEDUCTION")}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="EARNING">Earning</SelectItem>
                    <SelectItem value="DEDUCTION">Deduction</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label>Order (evaluation sequence)</Label>
                <Input
                  type="number"
                  value={evaluationOrder}
                  onChange={(e) => setEvaluationOrder(Number(e.target.value))}
                />
                <p className="text-[10px] text-slate-500 leading-snug">
                  Lower = calculated earlier. Must be before any column that references it, and before Gross / Total / Net totals.
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Switch checked={isRuleConfigurable} onCheckedChange={setIsRuleConfigurable} />
              <Label className="font-normal">Allow rule configuration in structures</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setOpen(false)}>Cancel</Button>
            <Button onClick={handleAdd} disabled={createColumn.isPending}>
              {createColumn.isPending ? "Adding…" : "Add"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
