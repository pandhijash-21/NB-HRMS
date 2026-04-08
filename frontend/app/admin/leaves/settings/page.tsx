"use client";

import { useState } from "react";
import {
  useLeaveSettings,
  useUpdateLeaveSetting,
  useYearEndTrigger,
  useAdminLeaveTypes,
  useUpsertLeaveType,
  useDeleteLeaveType,
} from "@/lib/hooks/useLeave";
import type { LeaveType } from "@/lib/hooks/useLeave";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent,
  AlertDialogDescription, AlertDialogFooter, AlertDialogHeader,
  AlertDialogTitle, AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import {
  Settings, Save, RotateCcw, ArrowLeft, Info, Clock, CalendarDays,
  ChevronDown, ChevronUp, Plus, Trash2,
} from "lucide-react";
import Link from "next/link";

const CY = new Date().getFullYear();

// ─── helpers ──────────────────────────────────────────────────────────────────

function creditDays(schedule: unknown, month: number): number {
  const credits = (schedule as any)?.credits as Array<{ month: number; day: number; days: number }> | undefined;
  return credits?.find((c) => c.month === month)?.days ?? 0;
}

function buildCreditSchedule(credits: Array<{ month: number; day: number; days: number }>): unknown {
  return { credits };
}

/** Format "MM-DD" setting value → readable label like "Jan 1" */
function fmtCreditDate(mmdd: string): string {
  if (!mmdd) return "";
  const [mm, dd] = mmdd.split("-");
  const d = new Date(2000, Number(mm) - 1, Number(dd));
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function applicableLabel(applicableTo: string): string {
  if (applicableTo === "BOTH")         return "Teaching & Non-Teaching";
  if (applicableTo === "TEACHING")     return "Teaching only";
  if (applicableTo === "NON_TEACHING") return "Non-Teaching only";
  return applicableTo;
}

// ─── sub-components ───────────────────────────────────────────────────────────

function InfoTip({ text }: { text: string }) {
  return (
    <span title={text} className="cursor-help shrink-0">
      <Info className="w-3.5 h-3.5 text-slate-400" />
    </span>
  );
}

function SettingRow({
  label, description, tooltip, settingKey,
  getValue, isDirty, onChange, onSave, saving,
  type = "text", selectOptions,
}: {
  label: string; description: string; tooltip?: string; settingKey: string;
  getValue: (k: string) => string; isDirty: (k: string) => boolean;
  onChange: (k: string, v: string) => void; onSave: (k: string) => void;
  saving: boolean; type?: "text" | "number";
  selectOptions?: { value: string; label: string; hint?: string }[];
}) {
  const val = getValue(settingKey);
  const dirty = isDirty(settingKey);
  return (
    <div className="flex items-center gap-4 py-3 border-b border-slate-50 last:border-0">
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5">
          <p className="text-sm font-medium text-slate-700">{label}</p>
          {tooltip && <InfoTip text={tooltip} />}
        </div>
        <p className="text-xs text-slate-400 mt-0.5">{description}</p>
      </div>
      <div className="flex items-center gap-2 shrink-0">
        {selectOptions ? (
          <Select value={val} onValueChange={(v) => onChange(settingKey, v)}>
            <SelectTrigger className="w-36 h-8 text-xs"><SelectValue /></SelectTrigger>
            <SelectContent>
              {selectOptions.map((o) => (
                <SelectItem key={o.value} value={o.value}>
                  <span>{o.label}</span>
                  {o.hint && <span className="ml-2 text-[10px] text-slate-400">{o.hint}</span>}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        ) : (
          <Input type={type} className="w-28 h-8 text-sm text-right" value={val}
            onChange={(e) => onChange(settingKey, e.target.value)} />
        )}
        <Button size="icon" variant="ghost"
          className="h-8 w-8 text-emerald-600 hover:text-emerald-700 disabled:opacity-30"
          disabled={!dirty || saving} onClick={() => onSave(settingKey)}>
          <Save className="w-3.5 h-3.5" />
        </Button>
        {dirty && (
          <Badge className="text-[10px] bg-amber-100 text-amber-600 border-amber-200 whitespace-nowrap">
            Modified
          </Badge>
        )}
      </div>
    </div>
  );
}

// ─── ApplicableTo checkboxes ──────────────────────────────────────────────────

function ApplicableCheckboxes({
  value, onChange,
}: {
  value: "TEACHING" | "NON_TEACHING" | "BOTH";
  onChange: (v: "TEACHING" | "NON_TEACHING" | "BOTH") => void;
}) {
  const teaching    = value === "TEACHING"     || value === "BOTH";
  const nonTeaching = value === "NON_TEACHING" || value === "BOTH";

  function toggle(type: "teaching" | "non_teaching") {
    let t = type === "teaching"     ? !teaching    : teaching;
    let n = type === "non_teaching" ? !nonTeaching : nonTeaching;
    if (!t && !n) { t = type !== "teaching"; n = type !== "non_teaching"; }
    if (t && n)   onChange("BOTH");
    else if (t)   onChange("TEACHING");
    else          onChange("NON_TEACHING");
  }

  return (
    <div className="flex flex-col gap-1.5">
      <label className="flex items-center gap-2 cursor-pointer select-none">
        <input
          type="checkbox"
          checked={teaching}
          onChange={() => toggle("teaching")}
          className="w-3.5 h-3.5 accent-[#1d3459]"
        />
        <span className="text-xs text-slate-700">Teaching</span>
      </label>
      <label className="flex items-center gap-2 cursor-pointer select-none">
        <input
          type="checkbox"
          checked={nonTeaching}
          onChange={() => toggle("non_teaching")}
          className="w-3.5 h-3.5 accent-[#1d3459]"
        />
        <span className="text-xs text-slate-700">Non-Teaching</span>
      </label>
    </div>
  );
}

// ─── LeaveTypeRow ─────────────────────────────────────────────────────────────

function LeaveTypeRow({
  lt, onSave, onDelete, newYearDate, midYearDate,
}: {
  lt: LeaveType;
  onSave: (updated: LeaveType & { janDays?: number; julDays?: number }) => void;
  onDelete: (code: string) => void;
  newYearDate: string;
  midYearDate: string;
}) {
  const [expanded, setExpanded]             = useState(false);
  const [name, setName]                     = useState(lt.name);
  const [daysPerYear, setDaysPerYear]       = useState<string>(String(lt.defaultDaysPerYear ?? ""));
  const [applicableTo, setApplicableTo]     = useState<"TEACHING" | "NON_TEACHING" | "BOTH">(lt.applicableTo);
  const [isCarryForward, setIsCarryForward] = useState(lt.isCarryForward);
  const [requiresDocument, setRequiresDocument] = useState(lt.requiresDocument);
  const [isActive, setIsActive]             = useState(lt.isActive);
  const [employeeCanApply, setEmployeeCanApply] = useState(lt.employeeCanApply);
  const [janDays, setJanDays]               = useState<string>(String(creditDays(lt.creditSchedule, 1)));
  const [julDays, setJulDays]               = useState<string>(String(creditDays(lt.creditSchedule, 7)));

  // Show split credits whenever carry forward is on
  const splitCredits = isCarryForward;

  const janLabel = newYearDate ? `${fmtCreditDate(newYearDate)} Credit (days)` : "Jan 1 Credit (days)";
  const julLabel = midYearDate ? `${fmtCreditDate(midYearDate)} Credit (days)` : "Jul 1 Credit (days)";

  return (
    <div className="border border-slate-100 rounded-xl overflow-hidden">
      {/* Header */}
      <div
        className="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-50 transition-colors"
        onClick={() => setExpanded((e) => !e)}
      >
        <span className="text-xs font-bold px-2 py-0.5 rounded-md shrink-0"
          style={{ background: "#1d3459", color: "#d9b557" }}>
          {lt.code}
        </span>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-slate-800">{lt.name}</p>
          <p className="text-xs text-slate-400">{applicableLabel(applicableTo)}</p>
        </div>
        <div className="flex items-center gap-3 shrink-0 text-xs text-slate-500">
          <span>
            {splitCredits
              ? `${Number(janDays) + Number(julDays)} days/yr`
              : daysPerYear ? `${daysPerYear} days/yr` : "No fixed limit"}
          </span>
          {!employeeCanApply && (
            <Badge className="bg-orange-50 text-orange-500 border-orange-200 text-[10px]">Admin only</Badge>
          )}
          {!isActive && (
            <Badge className="bg-slate-100 text-slate-400 border-slate-200 text-[10px]">Inactive</Badge>
          )}
          {expanded ? <ChevronUp className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
        </div>
      </div>

      {/* Expanded editor */}
      {expanded && (
        <div className="px-4 pb-4 bg-slate-50 border-t border-slate-100 pt-4 space-y-4">
          {/* Name */}
          <div className="space-y-1">
            <p className="text-xs font-medium text-slate-600">Leave Type Name</p>
            <Input className="h-8 text-sm max-w-xs" value={name} onChange={(e) => setName(e.target.value)} />
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
            {/* Days per year */}
            {!splitCredits && (
              <div className="space-y-1">
                <p className="text-xs font-medium text-slate-600">Days per Year</p>
                <Input type="number" className="h-8 text-sm" placeholder="Unlimited"
                  value={daysPerYear} onChange={(e) => setDaysPerYear(e.target.value)} />
                <p className="text-[11px] text-slate-400">Leave blank for unlimited</p>
              </div>
            )}

            {/* Split credit schedule — shown whenever carry forward is on */}
            {splitCredits && (
              <>
                <div className="space-y-1">
                  <p className="text-xs font-medium text-slate-600">{janLabel}</p>
                  <Input type="number" className="h-8 text-sm"
                    value={janDays} onChange={(e) => setJanDays(e.target.value)} />
                </div>
                <div className="space-y-1">
                  <p className="text-xs font-medium text-slate-600">{julLabel}</p>
                  <Input type="number" className="h-8 text-sm"
                    value={julDays} onChange={(e) => setJulDays(e.target.value)} />
                </div>
                <div className="space-y-1">
                  <p className="text-xs font-medium text-slate-600">Total / Year</p>
                  <div className="h-8 flex items-center px-3 rounded-md border border-slate-200 bg-white text-sm font-semibold text-slate-700">
                    {(Number(janDays) || 0) + (Number(julDays) || 0)} days
                  </div>
                </div>
              </>
            )}

            {/* Applicable To */}
            <div className="space-y-1">
              <p className="text-xs font-medium text-slate-600">Applicable To</p>
              <ApplicableCheckboxes value={applicableTo} onChange={setApplicableTo} />
            </div>

            {/* Carry Forward */}
            <div className="space-y-1">
              <p className="text-xs font-medium text-slate-600">Carry Forward</p>
              <Select value={isCarryForward ? "yes" : "no"} onValueChange={(v) => setIsCarryForward(v === "yes")}>
                <SelectTrigger className="h-8 text-xs"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="yes">Yes</SelectItem>
                  <SelectItem value="no">No</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Requires Document */}
            <div className="space-y-1">
              <p className="text-xs font-medium text-slate-600">Requires Document</p>
              <Select value={requiresDocument ? "yes" : "no"} onValueChange={(v) => setRequiresDocument(v === "yes")}>
                <SelectTrigger className="h-8 text-xs"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="yes">Yes</SelectItem>
                  <SelectItem value="no">No</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Employee Can Apply */}
            <div className="space-y-1">
              <p className="text-xs font-medium text-slate-600">Employee Can Apply</p>
              <Select value={employeeCanApply ? "yes" : "no"} onValueChange={(v) => setEmployeeCanApply(v === "yes")}>
                <SelectTrigger className="h-8 text-xs"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="yes">Yes — self-service</SelectItem>
                  <SelectItem value="no">No — admin/HR only</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Status */}
            <div className="space-y-1">
              <p className="text-xs font-medium text-slate-600">Status</p>
              <Select value={isActive ? "active" : "inactive"} onValueChange={(v) => setIsActive(v === "active")}>
                <SelectTrigger className="h-8 text-xs"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="active">Active</SelectItem>
                  <SelectItem value="inactive">Inactive</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="flex items-center justify-between pt-1">
            {/* Delete */}
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <Button size="sm" variant="ghost"
                  className="h-8 text-xs text-red-500 hover:text-red-600 hover:bg-red-50">
                  <Trash2 className="w-3.5 h-3.5 mr-1" /> Remove Type
                </Button>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Remove "{lt.name}"?</AlertDialogTitle>
                  <AlertDialogDescription>
                    This will deactivate the leave type. Existing applications and balances will
                    not be affected. You can re-activate it at any time.
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancel</AlertDialogCancel>
                  <AlertDialogAction
                    className="bg-red-600 hover:bg-red-700"
                    onClick={() => { onDelete(lt.code); setExpanded(false); }}>
                    Remove
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>

            {/* Save */}
            <Button size="sm" className="h-8 text-xs text-white" style={{ background: "#1d3459" }}
              onClick={() => {
                onSave({
                  ...lt,
                  name,
                  applicableTo,
                  defaultDaysPerYear: splitCredits
                    ? (Number(janDays) || 0) + (Number(julDays) || 0)
                    : daysPerYear !== "" ? Number(daysPerYear) : null,
                  isCarryForward,
                  requiresDocument,
                  isActive,
                  employeeCanApply,
                  janDays: splitCredits ? Number(janDays) : undefined,
                  julDays: splitCredits ? Number(julDays) : undefined,
                });
                setExpanded(false);
              }}>
              <Save className="w-3.5 h-3.5 mr-1" /> Save Changes
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

// ─── AddLeaveTypeForm ─────────────────────────────────────────────────────────

const EMPTY_NEW = {
  code: "", name: "", applicableTo: "BOTH" as "TEACHING" | "NON_TEACHING" | "BOTH",
  daysPerYear: "", isCarryForward: false, requiresDocument: false, employeeCanApply: true,
  janDays: "0", julDays: "0",
};
type NewFormState = typeof EMPTY_NEW;

function AddLeaveTypeForm({
  onSave, onCancel, newYearDate, midYearDate,
}: {
  onSave: (data: NewFormState) => void;
  onCancel: () => void;
  newYearDate: string;
  midYearDate: string;
}) {
  const [form, setForm] = useState<NewFormState>({ ...EMPTY_NEW_WITH_CREDITS });

  const janLabel = newYearDate ? `${fmtCreditDate(newYearDate)} Credit (days)` : "Jan 1 Credit (days)";
  const julLabel = midYearDate ? `${fmtCreditDate(midYearDate)} Credit (days)` : "Jul 1 Credit (days)";

  return (
    <div className="border-2 border-dashed border-[#1d3459]/30 rounded-xl p-4 bg-slate-50 space-y-4">
      <p className="text-sm font-semibold text-slate-700">New Leave Type</p>
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
        <div className="space-y-1">
          <p className="text-xs font-medium text-slate-600">Code <span className="text-red-500">*</span></p>
          <Input className="h-8 text-sm uppercase" maxLength={6} placeholder="e.g. ML"
            value={form.code}
            onChange={(e) => setForm((f) => ({ ...f, code: e.target.value.toUpperCase() }))} />
        </div>
        <div className="space-y-1 col-span-2">
          <p className="text-xs font-medium text-slate-600">Name <span className="text-red-500">*</span></p>
          <Input className="h-8 text-sm" placeholder="e.g. Maternity Leave"
            value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
        </div>

        {/* Carry Forward first so toggling it shows/hides credit fields */}
        <div className="space-y-1">
          <p className="text-xs font-medium text-slate-600">Carry Forward</p>
          <Select value={form.isCarryForward ? "yes" : "no"} onValueChange={(v) => setForm((f) => ({ ...f, isCarryForward: v === "yes" }))}>
            <SelectTrigger className="h-8 text-xs"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="yes">Yes</SelectItem>
              <SelectItem value="no">No</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {/* Single days — only when carry forward is off */}
        {!form.isCarryForward && (
          <div className="space-y-1">
            <p className="text-xs font-medium text-slate-600">Days per Year</p>
            <Input type="number" className="h-8 text-sm" placeholder="Unlimited"
              value={form.daysPerYear} onChange={(e) => setForm((f) => ({ ...f, daysPerYear: e.target.value }))} />
            <p className="text-[11px] text-slate-400">Leave blank for unlimited</p>
          </div>
        )}

        {/* Split credits — when carry forward is on */}
        {form.isCarryForward && (
          <>
            <div className="space-y-1">
              <p className="text-xs font-medium text-slate-600">{janLabel}</p>
              <Input type="number" className="h-8 text-sm"
                value={form.janDays} onChange={(e) => setForm((f) => ({ ...f, janDays: e.target.value }))} />
            </div>
            <div className="space-y-1">
              <p className="text-xs font-medium text-slate-600">{julLabel}</p>
              <Input type="number" className="h-8 text-sm"
                value={form.julDays} onChange={(e) => setForm((f) => ({ ...f, julDays: e.target.value }))} />
            </div>
            <div className="space-y-1">
              <p className="text-xs font-medium text-slate-600">Total / Year</p>
              <div className="h-8 flex items-center px-3 rounded-md border border-slate-200 bg-white text-sm font-semibold text-slate-700">
                {(Number(form.janDays) || 0) + (Number(form.julDays) || 0)} days
              </div>
            </div>
          </>
        )}

        <div className="space-y-1">
          <p className="text-xs font-medium text-slate-600">Applicable To</p>
          <ApplicableCheckboxes value={form.applicableTo} onChange={(v) => setForm((f) => ({ ...f, applicableTo: v }))} />
        </div>
        <div className="space-y-1">
          <p className="text-xs font-medium text-slate-600">Requires Document</p>
          <Select value={form.requiresDocument ? "yes" : "no"} onValueChange={(v) => setForm((f) => ({ ...f, requiresDocument: v === "yes" }))}>
            <SelectTrigger className="h-8 text-xs"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="yes">Yes</SelectItem>
              <SelectItem value="no">No</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1">
          <p className="text-xs font-medium text-slate-600">Employee Can Apply</p>
          <Select value={form.employeeCanApply ? "yes" : "no"} onValueChange={(v) => setForm((f) => ({ ...f, employeeCanApply: v === "yes" }))}>
            <SelectTrigger className="h-8 text-xs"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="yes">Yes — self-service</SelectItem>
              <SelectItem value="no">No — admin/HR only</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>
      <div className="flex justify-end gap-2">
        <Button size="sm" variant="ghost" className="h-8 text-xs" onClick={onCancel}>Cancel</Button>
        <Button size="sm" className="h-8 text-xs text-white" style={{ background: "#1d3459" }}
          disabled={!form.code.trim() || !form.name.trim()}
          onClick={() => onSave(form)}>
          <Plus className="w-3.5 h-3.5 mr-1" /> Add Leave Type
        </Button>
      </div>
    </div>
  );
}

// ─── main page ────────────────────────────────────────────────────────────────

export default function LeaveSettingsPage() {
  const { data: settings = [], isLoading: settingsLoading } = useLeaveSettings();
  const { data: leaveTypes = [], isLoading: typesLoading }  = useAdminLeaveTypes();
  const { mutate: updateSetting, isPending: saving }        = useUpdateLeaveSetting();
  const { mutateAsync: runYearEnd, isPending: running }     = useYearEndTrigger();
  const { mutate: upsertType }                              = useUpsertLeaveType();
  const { mutate: deleteType }                              = useDeleteLeaveType();

  const [edits, setEdits]         = useState<Record<string, string>>({});
  const [showAddForm, setShowAddForm] = useState(false);

  const getValue = (key: string) =>
    edits[key] ?? settings.find((s) => s.key === key)?.value ?? "";
  const isDirty = (key: string) =>
    key in edits && edits[key] !== settings.find((s) => s.key === key)?.value;
  const onChange = (key: string, val: string) =>
    setEdits((e) => ({ ...e, [key]: val }));
  const onSave = (key: string) => {
    updateSetting({ key, value: edits[key] });
    setEdits((e) => { const n = { ...e }; delete n[key]; return n; });
  };

  const rowProps = { getValue, isDirty, onChange, onSave, saving };

  const handleSaveType = (lt: LeaveType & { janDays?: number; julDays?: number }) => {
    const creditSchedule = lt.janDays !== undefined
      ? buildCreditSchedule([
          { month: 1, day: 1, days: lt.janDays ?? 0 },
          { month: 7, day: 1, days: lt.julDays ?? 0 },
        ])
      : lt.creditSchedule;

    upsertType({
      code:               lt.code,
      name:               lt.name,
      applicableTo:       lt.applicableTo,
      defaultDaysPerYear: lt.defaultDaysPerYear,
      isCarryForward:     lt.isCarryForward,
      allowHalfDay:       lt.allowHalfDay,
      skipPublicHolidays: lt.skipPublicHolidays,
      skipWeekends:       lt.skipWeekends,
      requiresDocument:   lt.requiresDocument,
      requiresReason:     lt.requiresReason,
      creditSchedule,
      isActive:           lt.isActive,
      employeeCanApply:   lt.employeeCanApply,
    });
  };

  const handleAddType = (form: NewFormState) => {
    const splitCredits = form.isCarryForward;
    const creditSchedule = splitCredits
      ? buildCreditSchedule([
          { month: 1, day: 1, days: Number(form.janDays) || 0 },
          { month: 7, day: 1, days: Number(form.julDays) || 0 },
        ])
      : undefined;

    upsertType({
      code:               form.code,
      name:               form.name,
      applicableTo:       form.applicableTo,
      defaultDaysPerYear: splitCredits
        ? (Number(form.janDays) || 0) + (Number(form.julDays) || 0)
        : form.daysPerYear !== "" ? Number(form.daysPerYear) : null,
      isCarryForward:     form.isCarryForward,
      allowHalfDay:       true,
      skipPublicHolidays: true,
      skipWeekends:       true,
      requiresDocument:   form.requiresDocument,
      requiresReason:     true,
      isActive:           true,
      employeeCanApply:   form.employeeCanApply,
      creditSchedule,
    });
    setShowAddForm(false);
  };

  return (
    <div className="max-w-3xl space-y-6 animate-in fade-in duration-500">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/admin/leaves"><ArrowLeft className="w-4 h-4" /></Link>
        </Button>
        <div>
          <h1 className="text-xl font-bold text-slate-900">Leave Settings</h1>
          <p className="text-xs text-slate-500">Configure global leave module behaviour</p>
        </div>
      </div>

      {/* ── Section 1: General ────────────────────────────────────────────────── */}
      <Card className="border-none shadow-sm">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm flex items-center gap-2">
            <Settings className="w-4 h-4 text-slate-400" /> General
          </CardTitle>
        </CardHeader>
        <CardContent>
          {settingsLoading ? (
            <div className="space-y-3">
              {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-12 rounded-lg" />)}
            </div>
          ) : (
            <div>
              <SettingRow {...rowProps} settingKey="absence_window_hours" label="Absence Window (hours)"
                description="Hours an employee has to apply for leave after being marked absent"
                tooltip="If an employee is marked absent and doesn't apply within this window, the system auto-applies Leave Without Pay (LWP)."
                type="number" />
              <SettingRow {...rowProps} settingKey="lwp_auto_apply" label="Auto-apply LWP on Expiry"
                description="Automatically convert absence to LWP when the window expires"
                selectOptions={[{ value: "true", label: "Enabled" }, { value: "false", label: "Disabled" }]} />
              <SettingRow {...rowProps} settingKey="yearend_processing_date" label="Year-End Processing Date (MM-DD)"
                description="Date on which year-end carry-forward is calculated" type="text" />
              <SettingRow {...rowProps} settingKey="new_year_credit_date" label="New Year Credit Date (MM-DD)"
                description="Date on which leave credits are issued for the new year" type="text" />
              <SettingRow {...rowProps} settingKey="mid_year_credit_date" label="Mid-Year Credit Date (MM-DD)"
                description="Date on which mid-year credits (e.g. second SL instalment) are issued" type="text" />
            </div>
          )}
        </CardContent>
      </Card>

      {/* ── Section 2: Approval Timeouts ──────────────────────────────────────── */}
      <Card className="border-none shadow-sm">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm flex items-center gap-2">
            <Clock className="w-4 h-4 text-slate-400" /> Approval Timeouts
          </CardTitle>
        </CardHeader>
        <CardContent>
          {settingsLoading ? (
            <div className="space-y-3">
              {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-12 rounded-lg" />)}
            </div>
          ) : (
            <div>
              <SettingRow {...rowProps} settingKey="hod_window_hours" label="HOD Window (hours)"
                description="Hours the Head of Department has to recommend or reject"
                tooltip="After an employee applies, the HOD must act within this many hours. On expiry the 'Timeout Action' below applies."
                type="number" />
              <SettingRow {...rowProps} settingKey="hoi_window_hours" label="HOI Window (hours)"
                description="Hours the Head of Institution (Principal) has to recommend or reject"
                tooltip="After HOD recommends, the HOI must act within this many hours."
                type="number" />
              <SettingRow {...rowProps} settingKey="global_window_hours" label="Vice Chancellor / Registrar Window (hours)"
                description="Hours the final approver (VC or Registrar) has to approve or reject"
                tooltip="Either the Vice Chancellor or the Registrar can complete the final approval. Whichever acts first finalises the application."
                type="number" />
              <SettingRow {...rowProps} settingKey="approver_timeout_action" label="On Timeout"
                description="What happens when an approver does not act within their window"
                tooltip="Escalate — auto-recommend and move to next tier.\nReject — auto-reject the application."
                selectOptions={[
                  { value: "escalate", label: "Escalate", hint: "auto-recommend & move to next tier" },
                  { value: "reject",   label: "Reject",   hint: "auto-reject the application" },
                ]} />
            </div>
          )}
        </CardContent>
      </Card>

      {/* ── Section 3: Leave Types ────────────────────────────────────────────── */}
      <Card className="border-none shadow-sm">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm flex items-center gap-2">
            <CalendarDays className="w-4 h-4 text-slate-400" /> Leave Types
            <Button size="sm" variant="ghost" className="ml-auto h-7 text-xs text-[#1d3459] hover:text-[#1d3459] hover:bg-[#1d3459]/10"
              onClick={() => setShowAddForm((v) => !v)}>
              <Plus className="w-3.5 h-3.5 mr-1" />
              {showAddForm ? "Cancel" : "Add New"}
            </Button>
          </CardTitle>
        </CardHeader>
        <CardContent>
          {typesLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-14 rounded-xl" />)}
            </div>
          ) : (
            <div className="space-y-2">
              {showAddForm && (
                <AddLeaveTypeForm
                  onSave={handleAddType}
                  onCancel={() => setShowAddForm(false)}
                  newYearDate={getValue("new_year_credit_date")}
                  midYearDate={getValue("mid_year_credit_date")}
                />
              )}
              {leaveTypes.map((lt) => (
                <LeaveTypeRow
                  key={lt.code}
                  lt={lt}
                  onSave={handleSaveType}
                  onDelete={deleteType}
                  newYearDate={getValue("new_year_credit_date")}
                  midYearDate={getValue("mid_year_credit_date")}
                />
              ))}
            </div>
          )}
          <p className="text-[11px] text-slate-400 mt-3 leading-relaxed">
            Leave types with a split credit schedule issue credits in two instalments (Jan 1 and Jul 1).
            All other types with a fixed yearly allowance issue all credits on the New Year Credit Date.
            <span className="ml-1 text-orange-500 font-medium">Admin only</span> types can only be applied by HR/Admin on behalf of employees.
          </p>
        </CardContent>
      </Card>

      {/* ── Section 4: Year-End ───────────────────────────────────────────────── */}
      <Card className="border-none shadow-sm">
        <CardContent className="py-5 px-5">
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="font-semibold text-slate-800">Year-End Processing</p>
              <p className="text-xs text-slate-500 mt-1 leading-relaxed">
                Runs carry-forward balances for all eligible employees for{" "}
                <strong>{CY}</strong> → <strong>{CY + 1}</strong>. Safe to run
                multiple times (idempotent). Also triggered automatically by the
                scheduler on the Year-End Date above.
              </p>
            </div>
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <Button variant="outline" size="sm" className="shrink-0">
                  <RotateCcw className="w-4 h-4 mr-2" /> Run Year-End
                </Button>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Run Year-End Processing?</AlertDialogTitle>
                  <AlertDialogDescription>
                    This will process carry-forward balances for {CY}. It is safe to run multiple times. Continue?
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancel</AlertDialogCancel>
                  <AlertDialogAction style={{ background: "#1d3459" }} disabled={running} onClick={() => runYearEnd(CY)}>
                    {running ? "Running…" : "Run Now"}
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
