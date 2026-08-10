"use client";

import { useState, useMemo } from "react";
import {
  ColumnDef,
  flexRender,
  getCoreRowModel,
  useReactTable,
} from "@tanstack/react-table";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useFamilyMembers, useFamilyActions } from "../../hooks/useProfile";
import { FamilyMember } from "../../types";
import { Skeleton } from "@/components/ui/skeleton";
import { Users, Plus, Trash2, ShieldCheck, Mail, Phone, Calendar, MapPin, Eye, EyeOff } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";

const familySchema = z.object({
  relation: z.enum(['FATHER', 'MOTHER', 'SPOUSE', 'SON', 'DAUGHTER', 'BROTHER', 'SISTER', 'GUARDIAN', 'OTHER']),
  name: z.string().min(2, "Name is too short"),
  city: z.string().optional().nullable(),
  mobileNo: z.string().optional().nullable(),
  personalEmail: z.string().email().optional().nullable().or(z.literal('')),
  dateOfBirth: z.string().optional().nullable(),
  aadhaarNo: z.string().optional().nullable(),
  isNominee: z.boolean().default(false),
});

type FamilyFormData = z.infer<typeof familySchema>;

interface FamilyTabProps {
  employeeId: string | number;
}

export function FamilyTab({ employeeId }: FamilyTabProps) {
  const [open, setOpen] = useState(false);
  const { data: members, isLoading } = useFamilyMembers(employeeId);
  const { addMutation, deleteMutation } = useFamilyActions(employeeId);

  const { register, handleSubmit, setValue, watch, reset, formState: { errors } } = useForm<FamilyFormData>({
    resolver: zodResolver(familySchema) as any,
    defaultValues: {
      isNominee: false,
    }
  });

  const columns = useMemo<ColumnDef<FamilyMember>[]>(() => [
    {
      accessorKey: "name",
      header: "Member Name",
      cell: ({ row }) => (
        <div className="flex flex-col">
          <span className="font-bold text-slate-800 text-sm">{row.original.name}</span>
          <span className="text-[10px] uppercase tracking-wider text-slate-400 font-bold">{row.original.relationship}</span>
        </div>
      ),
    },
    {
        accessorKey: "details",
        header: "Contact & Info",
        cell: ({ row }) => (
          <div className="space-y-1 py-1">
            <div className="flex items-center gap-1.5 text-xs text-slate-500">
                <Phone className="w-3 h-3" /> {row.original.contactNo || "—"}
            </div>
            <div className="flex items-center gap-1.5 text-[10px] text-slate-400 font-medium">
                <Calendar className="w-3 h-3" /> {row.original.birthDate ? new Date(row.original.birthDate).toLocaleDateString() : "—"}
            </div>
          </div>
        ),
      },
    {
      accessorKey: "isNominee",
      header: "Status",
      cell: ({ row }) => (
        <div className="flex gap-2">
            {row.original.isDependent && (
                 <Badge variant="outline" className="bg-emerald-50 text-emerald-600 border-emerald-100 text-[9px] font-bold uppercase">Dependent</Badge>
            )}
            {/* The REST API uses isNominee instead of isDependent in some controllers, checking consistency */}
            {row.original.isDependent && (
               <Badge className="bg-[#1d3459] text-white border-none text-[9px] font-bold uppercase">NOMINEE</Badge>
            )}
        </div>
      ),
    },
    {
      id: "actions",
      cell: ({ row }) => (
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8 text-rose-400 hover:text-rose-600 hover:bg-rose-50"
          onClick={() => {
            if (confirm("Are you sure you want to remove this family member?")) {
              deleteMutation.mutate(row.original.id);
            }
          }}
        >
          <Trash2 className="w-4 h-4" />
        </Button>
      ),
    },
  ], [deleteMutation]);

  const table = useReactTable({
    data: members || [],
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  const onSubmit = (data: FamilyFormData) => {
    addMutation.mutate(data, {
      onSuccess: () => {
        setOpen(false);
        reset();
      },
    });
  };

  if (isLoading) return <Skeleton className="h-[300px] rounded-2xl" />;

  return (
    <Card className="border-none shadow-none bg-transparent">
      <CardHeader className="px-0 pt-0 pb-6 flex flex-row items-center justify-between space-y-0">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <Users className="w-4 h-4 text-[#1d3459]" />
            <CardTitle className="text-sm font-bold text-slate-800 uppercase tracking-tight">
              Family Records
            </CardTitle>
          </div>
          <p className="text-[11px] text-slate-500 font-medium">
            List of dependents and nominees associated with your profile.
          </p>
        </div>
        
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button size="sm" className="bg-[#1d3459] hover:bg-[#1d3459]/90 text-white rounded-xl px-4 gap-2 font-bold text-[10px] uppercase">
                <Plus className="w-3 h-3" /> Add Member
            </Button>
          </DialogTrigger>
          <DialogContent className="w-full rounded-2xl border-none shadow-2xl sm:max-w-[min(98vw,88rem)]">
            <DialogHeader>
              <DialogTitle className="text-lg font-bold text-slate-800">New Family Member</DialogTitle>
            </DialogHeader>
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 py-2">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5 col-span-2">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Full Name *</Label>
                  <Input {...register("name")} className="rounded-xl h-10" />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Relationship *</Label>
                  <Select onValueChange={(v) => setValue("relation", v as any)}>
                    <SelectTrigger className="rounded-xl h-10">
                        <SelectValue placeholder="Select..." />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="FATHER">Father</SelectItem>
                        <SelectItem value="MOTHER">Mother</SelectItem>
                        <SelectItem value="SPOUSE">Spouse</SelectItem>
                        <SelectItem value="SON">Son</SelectItem>
                        <SelectItem value="DAUGHTER">Daughter</SelectItem>
                        <SelectItem value="OTHER">Other</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">DOB</Label>
                  <Input type="date" {...register("dateOfBirth")} className="rounded-xl h-10" />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                 <div className="space-y-1.5">
                    <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Mobile No</Label>
                    <Input {...register("mobileNo")} className="rounded-xl h-10" />
                 </div>
                 <div className="space-y-1.5">
                    <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">City</Label>
                    <Input {...register("city")} className="rounded-xl h-10" />
                 </div>
              </div>

              <div className="flex items-center space-x-2 pt-2">
                <Checkbox 
                    id="isNominee" 
                    checked={watch("isNominee")} 
                    onCheckedChange={(c) => setValue("isNominee", !!c)} 
                />
                <label htmlFor="isNominee" className="text-xs font-semibold text-slate-700">Set as primary nominee</label>
              </div>

              <DialogFooter className="pt-4">
                <Button type="submit" disabled={addMutation.isPending} className="w-full bg-[#d9b557] hover:bg-[#c9a547] text-[#1d3459] font-bold uppercase text-[10px] h-10 rounded-xl">
                    {addMutation.isPending ? "Adding..." : "Confirm Addition"}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </CardHeader>

      <CardContent className="px-0">
        <div className="bg-white/50 border border-slate-100 rounded-2xl overflow-hidden shadow-sm">
          <table className="w-full">
            <thead className="bg-slate-50/50 border-b border-slate-100">
              {table.getHeaderGroups().map((headerGroup) => (
                <tr key={headerGroup.id}>
                  {headerGroup.headers.map((header) => (
                    <th key={header.id} className="text-left px-6 py-4 text-[10px] font-bold text-slate-400 uppercase tracking-widest">
                      {header.isPlaceholder ? null : flexRender(header.column.columnDef.header, header.getContext())}
                    </th>
                  ))}
                </tr>
              ))}
            </thead>
            <tbody className="divide-y divide-slate-50">
              {table.getRowModel().rows.length > 0 ? (
                table.getRowModel().rows.map((row) => (
                  <tr key={row.id} className="hover:bg-slate-50/30 transition-colors">
                    {row.getVisibleCells().map((cell) => (
                      <td key={cell.id} className="px-6 py-4">
                        {flexRender(cell.column.columnDef.cell, cell.getContext())}
                      </td>
                    ))}
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={columns.length} className="px-6 py-12 text-center text-slate-400 font-medium text-sm">
                    No family records found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  );
}
