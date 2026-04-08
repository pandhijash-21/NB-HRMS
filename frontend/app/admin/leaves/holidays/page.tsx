"use client";

import { useState } from "react";
import { usePublicHolidays, useAddHoliday, useDeleteHoliday } from "@/lib/hooks/useLeave";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Plus, Trash2, ArrowLeft, Calendar } from "lucide-react";
import Link from "next/link";
import { formatDate } from "@/lib/utils";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent,
  AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger,
} from "@/components/ui/alert-dialog";

const CY = new Date().getFullYear();

export default function HolidaysPage() {
  const [year, setYear] = useState(CY);
  const { data: holidays = [], isLoading } = usePublicHolidays(year);
  const { mutate: addHoliday, isPending: adding } = useAddHoliday();
  const { mutate: deleteHoliday } = useDeleteHoliday();

  const [form, setForm] = useState({ name: "", date: "", isOptional: false });

  const handleAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name || !form.date) return;
    addHoliday({ name: form.name, date: form.date, year, isOptional: form.isOptional });
    setForm({ name: "", date: "", isOptional: false });
  };

  return (
    <div className="max-w-3xl space-y-6 animate-in fade-in duration-500">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/admin/leaves"><ArrowLeft className="w-4 h-4" /></Link>
        </Button>
        <div>
          <h1 className="text-xl font-bold text-slate-900">Public Holidays</h1>
          <p className="text-xs text-slate-500">Manage public holidays for leave calculation</p>
        </div>
        <Select value={String(year)} onValueChange={(v) => setYear(Number(v))} >
          <SelectTrigger className="w-24 ml-auto">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {[CY, CY + 1, CY - 1].map((y) => (
              <SelectItem key={y} value={String(y)}>{y}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Add form */}
      <Card className="border-none shadow-sm">
        <CardHeader>
          <CardTitle className="text-sm flex items-center gap-2">
            <Plus className="w-4 h-4" /> Add Holiday
          </CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleAdd} className="flex flex-wrap gap-3 items-end">
            <div className="space-y-1.5 flex-1 min-w-40">
              <Label className="text-xs">Holiday Name</Label>
              <Input
                placeholder="e.g. Diwali"
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                required
              />
            </div>
            <div className="space-y-1.5">
              <Label className="text-xs">Date</Label>
              <Input
                type="date"
                value={form.date}
                onChange={(e) => setForm((f) => ({ ...f, date: e.target.value }))}
                required
              />
            </div>
            <div className="flex items-center gap-2 pb-1">
              <Switch
                id="optional"
                checked={form.isOptional}
                onCheckedChange={(v) => setForm((f) => ({ ...f, isOptional: v }))}
              />
              <Label htmlFor="optional" className="text-xs cursor-pointer">Optional</Label>
            </div>
            <Button type="submit" disabled={adding} style={{ background: "#1d3459" }}>
              {adding ? "Adding…" : "Add"}
            </Button>
          </form>
        </CardContent>
      </Card>

      {/* List */}
      {isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-12 rounded-lg" />)}
        </div>
      ) : !holidays.length ? (
        <div className="text-center py-10 text-slate-400">
          <Calendar className="w-8 h-8 mx-auto mb-2 opacity-30" />
          <p className="text-sm">No holidays for {year}.</p>
        </div>
      ) : (
        <div className="space-y-2">
          {holidays.map((h) => (
            <Card key={h.id} className="border-none shadow-sm">
              <CardContent className="py-3 px-5 flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="text-center min-w-[48px]">
                    <p className="text-lg font-bold text-slate-700 leading-none">
                      {new Date(h.date).getUTCDate()}
                    </p>
                    <p className="text-[10px] text-slate-400 uppercase tracking-wide">
                      {new Date(h.date).toLocaleString("default", { month: "short", timeZone: "UTC" })}
                    </p>
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-slate-800">{h.name}</p>
                    <p className="text-xs text-slate-400">{formatDate(h.date)}</p>
                  </div>
                  {h.isOptional && (
                    <Badge variant="outline" className="text-[10px] border-slate-200 text-slate-500">Optional</Badge>
                  )}
                </div>
                <AlertDialog>
                  <AlertDialogTrigger asChild>
                    <Button variant="ghost" size="icon" className="text-rose-400 hover:text-rose-600">
                      <Trash2 className="w-4 h-4" />
                    </Button>
                  </AlertDialogTrigger>
                  <AlertDialogContent>
                    <AlertDialogHeader>
                      <AlertDialogTitle>Delete holiday?</AlertDialogTitle>
                      <AlertDialogDescription>
                        Remove <strong>{h.name}</strong> from public holidays? This affects leave calculation.
                      </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                      <AlertDialogCancel>Cancel</AlertDialogCancel>
                      <AlertDialogAction className="bg-rose-600" onClick={() => deleteHoliday(h.id)}>
                        Delete
                      </AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
