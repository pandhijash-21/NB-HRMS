"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { familyMemberSchema, type FamilyMemberFormData } from "@/lib/validators/family.schema";
import { useFamilyMembers } from "@/lib/hooks/useFamilyMembers";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { MaskedInput } from "@/components/shared/MaskedInput";
import { Skeleton } from "@/components/ui/skeleton";

interface FamilyTabProps {
  employeeId: string;
  isAdmin?: boolean;
}

const RELATION_LABELS: Record<string, string> = {
  SPOUSE: "Spouse",
  CHILD: "Child",
  PARENT: "Parent",
  SIBLING: "Sibling",
  OTHER: "Other",
};

export function FamilyTab({ employeeId, isAdmin }: FamilyTabProps) {
  const { members, loading, saving, saveMember, deleteMember } = useFamilyMembers(employeeId);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingMember, setEditingMember] = useState<FamilyMemberFormData | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  const { register, handleSubmit, setValue, reset, formState: { errors } } = useForm<FamilyMemberFormData>({
    resolver: zodResolver(familyMemberSchema),
    defaultValues: {
      name: "",
      relation: "SPOUSE",
      dependent: false,
      employed: false,
    },
  });

  const openAdd = () => {
    reset({ name: "", relation: "SPOUSE", dependent: false, employed: false });
    setEditingMember(null);
    setDialogOpen(true);
  };

  const openEdit = (member: FamilyMemberFormData) => {
    reset(member);
    setEditingMember(member);
    setDialogOpen(true);
  };

  const onSubmit = async (data: FamilyMemberFormData) => {
    await saveMember({ ...data, id: editingMember?.id });
    setDialogOpen(false);
    reset();
  };

  const confirmDelete = async () => {
    if (deleteId) {
      await deleteMember(deleteId);
      setDeleteId(null);
    }
  };

  if (loading) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-3">
          {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-16 w-full" />)}
        </CardContent>
      </Card>
    );
  }

  return (
    <>
      <Card>
        <CardContent className="pt-5 space-y-4">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Family Members</h3>
            {isAdmin && (
              <Button
                size="sm"
                onClick={openAdd}
                style={{ backgroundColor: "#1d3459" }}
                className="text-white text-xs hover:opacity-90"
              >
                + Add Member
              </Button>
            )}
          </div>

          {members.length === 0 && (
            <div className="text-center py-8 text-sm text-slate-400 border border-dashed border-slate-200 rounded-lg">
              No family members added yet.
            </div>
          )}

          <div className="space-y-2">
            {members.map((m: Record<string, unknown>) => (
              <div
                key={m.id as string}
                className="flex items-start justify-between p-3 bg-slate-50 rounded-lg border border-slate-100"
              >
                <div className="flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="text-sm font-medium text-slate-800">{m.name as string}</p>
                    <Badge variant="outline" className="text-xs border-slate-300 text-slate-500">
                      {RELATION_LABELS[m.relation as string] ?? m.relation as string}
                    </Badge>
                    {m.dependent && (
                      <Badge className="text-xs bg-blue-100 text-blue-700">Dependent</Badge>
                    )}
                    {m.employed && (
                      <Badge className="text-xs bg-purple-100 text-purple-700">Employed</Badge>
                    )}
                  </div>
                  {m.dateOfBirth && (
                    <p className="text-xs text-slate-400 mt-1">
                      DOB: {new Date(m.dateOfBirth as string).toLocaleDateString("en-IN")}
                    </p>
                  )}
                  {m.aadhaarNoMasked && (
                    <div className="mt-1 flex items-center gap-2">
                      <p className="text-xs text-slate-400">Aadhaar:</p>
                      <MaskedInput maskedValue={m.aadhaarNoMasked as string} className="text-xs" />
                    </div>
                  )}
                  {m.employerName && (
                    <p className="text-xs text-slate-400 mt-1">Employer: {m.employerName as string}</p>
                  )}
                </div>

                {isAdmin && (
                  <div className="flex gap-1 ml-2 shrink-0">
                    <button
                      onClick={() => openEdit(m as FamilyMemberFormData)}
                      className="text-xs px-2 py-1 rounded border border-slate-200 text-slate-500 hover:bg-slate-100 transition-colors"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => setDeleteId(m.id as string)}
                      className="text-xs px-2 py-1 rounded border border-rose-200 text-rose-500 hover:bg-rose-50 transition-colors"
                    >
                      Remove
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Add/Edit Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>
              {editingMember ? "Edit Family Member" : "Add Family Member"}
            </DialogTitle>
          </DialogHeader>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 py-2">
            <div className="space-y-1">
              <Label>Name *</Label>
              <Input {...register("name")} />
              {errors.name && <p className="text-xs text-rose-500">{errors.name.message}</p>}
            </div>

            <div className="space-y-1">
              <Label>Relation *</Label>
              <Select
                defaultValue={editingMember?.relation ?? "SPOUSE"}
                onValueChange={(v) => setValue("relation", v as FamilyMemberFormData["relation"])}
              >
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {Object.entries(RELATION_LABELS).map(([v, l]) => (
                    <SelectItem key={v} value={v}>{l}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1">
              <Label>Date of Birth</Label>
              <Input type="date" {...register("dateOfBirth")} />
            </div>

            <div className="space-y-1">
              <Label>Aadhaar No <span className="text-xs text-slate-400">(sensitive)</span></Label>
              <MaskedInput isEditing {...register("aadhaarNo")} placeholder="12-digit" maxLength={12} />
              {errors.aadhaarNo && <p className="text-xs text-rose-500">{errors.aadhaarNo.message}</p>}
            </div>

            <div className="flex gap-6">
              <div className="flex items-center gap-2">
                <input type="checkbox" id="dep" {...register("dependent")} />
                <Label htmlFor="dep">Dependent</Label>
              </div>
              <div className="flex items-center gap-2">
                <input type="checkbox" id="emp" {...register("employed")} />
                <Label htmlFor="emp">Employed</Label>
              </div>
            </div>

            <div className="space-y-1">
              <Label>Employer Name</Label>
              <Input {...register("employerName")} />
            </div>

            <DialogFooter>
              <Button type="button" variant="ghost" size="sm" onClick={() => setDialogOpen(false)}>
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={saving}
                style={{ backgroundColor: "#1d3459" }}
                className="text-white hover:opacity-90"
              >
                {saving ? "Saving…" : "Save"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Delete Confirm */}
      <Dialog open={!!deleteId} onOpenChange={(o) => !o && setDeleteId(null)}>
        <DialogContent className="max-w-xs">
          <DialogHeader>
            <DialogTitle>Remove Member</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-slate-600 py-2">
            Are you sure you want to remove this family member?
          </p>
          <DialogFooter>
            <Button type="button" variant="ghost" size="sm" onClick={() => setDeleteId(null)}>
              Cancel
            </Button>
            <Button
              type="button"
              size="sm"
              className="bg-rose-600 text-white hover:bg-rose-700"
              onClick={confirmDelete}
              disabled={saving}
            >
              Remove
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
