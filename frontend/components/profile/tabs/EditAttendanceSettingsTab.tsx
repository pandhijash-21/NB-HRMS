"use client";

import { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import { Clock } from "lucide-react";
import {
  useEmployeeAttendanceSettings,
  useUpdateEmployeeAttendanceSettings,
} from "@/lib/hooks/useAttendance";

interface Props {
  employeeId: number;
}

export function EditAttendanceSettingsTab({ employeeId }: Props) {
  const settingsQ = useEmployeeAttendanceSettings(employeeId);
  const updateSettings = useUpdateEmployeeAttendanceSettings(employeeId);

  const [useGlobal, setUseGlobal] = useState(true);
  const [punchIn, setPunchIn] = useState("09:00");
  const [punchOut, setPunchOut] = useState("15:30");
  const [inBuffer, setInBuffer] = useState("10");
  const [outBuffer, setOutBuffer] = useState("10");
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    const s = settingsQ.data;
    if (!s) return;
    setUseGlobal(s.useGlobalPolicy);
    setPunchIn(s.punchInTime ?? s.effective.punchInTime ?? "09:00");
    setPunchOut(s.punchOutTime ?? s.effective.punchOutTime ?? "15:30");
    setInBuffer(String(s.punchInBufferMinutes ?? s.effective.punchInBufferMinutes ?? 10));
    setOutBuffer(String(s.punchOutBufferMinutes ?? s.effective.punchOutBufferMinutes ?? 10));
    setDirty(false);
  }, [settingsQ.data]);

  const handleSave = async () => {
    await updateSettings.mutateAsync({
      useGlobalPolicy: useGlobal,
      ...(useGlobal
        ? {}
        : {
            punchInTime: punchIn.trim(),
            punchOutTime: punchOut.trim(),
            punchInBufferMinutes: Number(inBuffer) || 10,
            punchOutBufferMinutes: Number(outBuffer) || 10,
          }),
    });
    setDirty(false);
  };

  if (settingsQ.isLoading) {
    return <Skeleton className="h-48 w-full rounded-xl" />;
  }

  if (settingsQ.isError) {
    return (
      <Card>
        <CardContent className="pt-6 text-sm text-rose-600">
          Could not load attendance settings.
        </CardContent>
      </Card>
    );
  }

  const effective = settingsQ.data?.effective;

  return (
    <Card className="border-slate-200/60 shadow-sm">
      <CardHeader className="pb-3">
        <div className="flex items-center gap-2">
          <Clock className="w-4 h-4 text-[#c5a059]" />
          <CardTitle className="text-sm font-bold text-slate-800">Punch window</CardTitle>
        </div>
        <p className="text-xs text-slate-500 mt-1">
          Override global attendance policy for this employee. Used for late marking, half-day rules, and salary calculations.
        </p>
      </CardHeader>
      <CardContent className="space-y-5">
        <div className="rounded-xl border border-slate-100 bg-slate-50/60 px-4 py-3 text-sm">
          <p className="text-xs font-bold uppercase tracking-widest text-slate-400 mb-2">Currently applied</p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <span className="text-slate-500">Punch in: </span>
              <span className="font-semibold text-slate-800">
                {effective?.punchInTime} (+{effective?.punchInBufferMinutes}m)
              </span>
            </div>
            <div>
              <span className="text-slate-500">Punch out: </span>
              <span className="font-semibold text-slate-800">
                {effective?.punchOutTime} (+{effective?.punchOutBufferMinutes}m)
              </span>
            </div>
          </div>
          <p className="text-xs text-slate-400 mt-2">
            Source: {effective?.source === "EMPLOYEE" ? "Custom for this employee" : "Global policy"}
          </p>
        </div>

        <div className="flex items-center justify-between gap-3 rounded-xl border border-slate-200 px-4 py-3">
          <div>
            <Label htmlFor="use-global-edit" className="font-semibold">Use global policy</Label>
            <p className="text-xs text-slate-500">When on, institution default punch times apply.</p>
          </div>
          <Switch
            id="use-global-edit"
            checked={useGlobal}
            onCheckedChange={(v) => {
              setUseGlobal(v);
              setDirty(true);
            }}
          />
        </div>

        {!useGlobal && (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label>Punch in (HH:MM)</Label>
              <Input
                value={punchIn}
                onChange={(e) => {
                  setPunchIn(e.target.value);
                  setDirty(true);
                }}
                placeholder="09:00"
              />
            </div>
            <div className="space-y-1.5">
              <Label>Punch out (HH:MM)</Label>
              <Input
                value={punchOut}
                onChange={(e) => {
                  setPunchOut(e.target.value);
                  setDirty(true);
                }}
                placeholder="15:30"
              />
            </div>
            <div className="space-y-1.5">
              <Label>In buffer (minutes)</Label>
              <Input
                type="number"
                min={0}
                max={240}
                value={inBuffer}
                onChange={(e) => {
                  setInBuffer(e.target.value);
                  setDirty(true);
                }}
              />
            </div>
            <div className="space-y-1.5">
              <Label>Out buffer (minutes)</Label>
              <Input
                type="number"
                min={0}
                max={240}
                value={outBuffer}
                onChange={(e) => {
                  setOutBuffer(e.target.value);
                  setDirty(true);
                }}
              />
            </div>
          </div>
        )}

        <div className="flex justify-end">
          <Button onClick={handleSave} disabled={!dirty || updateSettings.isPending}>
            {updateSettings.isPending ? "Saving…" : "Save punch settings"}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
