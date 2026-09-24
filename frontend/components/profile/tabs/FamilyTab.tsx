"use client";

import { useEffect, useState } from "react";
import { useForm, type Resolver } from "react-hook-form";
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
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { AlertCircle, Phone } from "lucide-react";

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

function apiRelationToForm(r: string): FamilyMemberFormData["relation"] {
  const map: Record<string, FamilyMemberFormData["relation"]> = {
    SPOUSE: "SPOUSE",
    SON: "CHILD",
    DAUGHTER: "CHILD",
    FATHER: "PARENT",
    MOTHER: "PARENT",
    BROTHER: "SIBLING",
    SISTER: "SIBLING",
    OTHER: "OTHER",
    GUARDIAN: "OTHER",
  };
  return map[r] ?? "OTHER";
}

export function FamilyTab({ employeeId, isAdmin }: FamilyTabProps) {
  const { members, loading, saving, saveMember, deleteMember } = useFamilyMembers(employeeId);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingMember, setEditingMember] = useState<FamilyMemberFormData | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [emergencyPromptOpen, setEmergencyPromptOpen] = useState(false);
  const [emergencyPromptDismissed, setEmergencyPromptDismissed] = useState(false);

  const { register, handleSubmit, setValue, reset, watch, formState: { errors } } = useForm<FamilyMemberFormData>({
    resolver: zodResolver(familyMemberSchema) as Resolver<FamilyMemberFormData>,
    defaultValues: {
      name: "",
      relation: "SPOUSE",
      dependent: false,
      employed: false,
      isNominee: false,
      isEmergencyContact: false,
      city: "",
      phoneNo: "",
      personalEmail: "",
    },
  });

  const relation = watch("relation");
  const isEmergencyContact = watch("isEmergencyContact");

  const hasEmergencyContact = members.some(
    (m: Record<string, unknown>) => Boolean(m.isEmergencyContact)
  );

  useEffect(() => {
    if (isAdmin || loading || emergencyPromptDismissed) return;
    if (!hasEmergencyContact) {
      setEmergencyPromptOpen(true);
    } else {
      setEmergencyPromptOpen(false);
    }
  }, [isAdmin, loading, hasEmergencyContact, emergencyPromptDismissed, members]);

  const openAdd = (asEmergency = false) => {
    reset({
      id: crypto.randomUUID(),
      name: "",
      relation: "SPOUSE",
      dependent: false,
      employed: false,
      isNominee: false,
      isEmergencyContact: asEmergency,
      city: "",
      phoneNo: "",
      personalEmail: "",
    });
    setEditingMember(null);
    setDialogOpen(true);
  };

  const openEdit = (member: FamilyMemberFormData, forceEmergency = false) => {
    const rel = typeof (member as { relation?: string }).relation === "string"
      ? apiRelationToForm((member as { relation: string }).relation)
      : member.relation;
    reset({
      ...member,
      relation: rel,
      isEmergencyContact: forceEmergency
        || Boolean((member as { isEmergencyContact?: boolean }).isEmergencyContact),
    });
    setEditingMember(member);
    setDialogOpen(true);
  };

  const onSubmit = async (data: FamilyMemberFormData) => {
    await saveMember({ ...data, id: editingMember?.id ?? data.id });
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
            <div>
              <h3 className="text-sm font-semibold text-slate-700">Family Members</h3>
              {members.length === 0 && (
                <p className="text-xs text-rose-500 mt-1 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  At least 1 family member is required
                </p>
              )}
              {members.length > 0 && !hasEmergencyContact && (
                <p className="text-xs text-amber-600 mt-1 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  Emergency contact is required — mark one family member
                </p>
              )}
              {members.length > 0 && hasEmergencyContact && (
                <p className="text-xs text-emerald-600 mt-1">
                  {members.length} member{members.length > 1 ? "s" : ""} added
                </p>
              )}
            </div>
            <Button
              size="sm"
              onClick={() => openAdd(false)}
              style={{ backgroundColor: "#1d3459" }}
              className="text-white text-xs hover:opacity-90"
            >
              + Add Member
            </Button>
          </div>

          {members.length === 0 && (
            <div className="text-center py-8 text-sm text-slate-400 border border-dashed border-slate-200 rounded-lg">
              No family members added yet. Please add at least one family member.
            </div>
          )}

          <div className="space-y-2">
            {members.map((m: Record<string, unknown>) => (
              <div
                key={m.id as string}
                className="p-3 bg-slate-50 rounded-lg border border-slate-100"
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <p className="text-sm font-medium text-slate-800">{m.name as string}</p>
                      <Badge variant="outline" className="text-xs border-slate-300 text-slate-500">
                        {RELATION_LABELS[apiRelationToForm(String(m.relation))] ?? String(m.relation)}
                      </Badge>
                      {Boolean(m.dependent) && (
                        <Badge className="text-xs bg-blue-100 text-blue-700">Dependent</Badge>
                      )}
                      {Boolean(m.employed) && (
                        <Badge className="text-xs bg-purple-100 text-purple-700">Employed</Badge>
                      )}
                      {Boolean(m.isNominee) && (
                        <Badge className="text-xs bg-amber-100 text-amber-700">Nominee</Badge>
                      )}
                      {Boolean(m.isEmergencyContact) && (
                        <Badge className="text-xs bg-rose-100 text-rose-700">
                          <Phone className="w-3 h-3 mr-0.5 inline" />
                          Emergency
                        </Badge>
                      )}
                    </div>
                    <div className="flex flex-wrap gap-x-4 gap-y-1 mt-1 text-xs text-slate-400">
                      {Boolean(m.city) && (
                        <span>City: <strong className="text-slate-600">{m.city as string}</strong></span>
                      )}
                      {Boolean(m.phoneNo) && (
                        <span>Phone: <strong className="text-slate-600">{m.phoneNo as string}</strong></span>
                      )}
                      {Boolean(m.personalEmail) && (
                        <span>Email: <strong className="text-slate-600">{m.personalEmail as string}</strong></span>
                      )}
                    </div>
                    {Boolean(m.dateOfBirth) && (
                      <p className="text-xs text-slate-400 mt-1">
                        DOB: {new Date(m.dateOfBirth as string).toLocaleDateString("en-IN")}
                      </p>
                    )}
                    {Boolean(m.employerName) && (
                      <p className="text-xs text-slate-400 mt-1">Employer: {m.employerName as string}</p>
                    )}
                  </div>

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
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Emergency contact required prompt — dismissible but clearly required */}
      <Dialog
        open={emergencyPromptOpen}
        onOpenChange={(open) => {
          if (!open) {
            setEmergencyPromptDismissed(true);
            setEmergencyPromptOpen(false);
          }
        }}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <AlertCircle className="w-5 h-5 text-amber-500" />
              Emergency contact required
            </DialogTitle>
            <DialogDescription className="text-sm text-slate-600 pt-1">
              At least one family member must be marked as an emergency contact.
              You can dismiss this for now, but please add or mark one before finishing your profile.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="flex-col sm:flex-row gap-2">
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => {
                setEmergencyPromptDismissed(true);
                setEmergencyPromptOpen(false);
              }}
            >
              Remind me later
            </Button>
            {members.length > 0 ? (
              <Button
                type="button"
                size="sm"
                style={{ backgroundColor: "#1d3459" }}
                className="text-white hover:opacity-90"
                onClick={() => {
                  setEmergencyPromptOpen(false);
                  openEdit(members[0] as FamilyMemberFormData, true);
                }}
              >
                Mark a contact
              </Button>
            ) : (
              <Button
                type="button"
                size="sm"
                style={{ backgroundColor: "#1d3459" }}
                className="text-white hover:opacity-90"
                onClick={() => {
                  setEmergencyPromptOpen(false);
                  openAdd(true);
                }}
              >
                Add emergency contact
              </Button>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="w-full max-h-[90vh] overflow-y-auto p-6 sm:max-w-[min(98vw,88rem)] sm:p-8">
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

            {relation === "OTHER" && (
              <div className="space-y-1">
                <Label>Specify Relation *</Label>
                <Input {...register("otherRelation")} placeholder="e.g., Uncle, Cousin" />
              </div>
            )}

            <div className="space-y-1">
              <Label>Date of Birth</Label>
              <Input type="date" {...register("dateOfBirth")} />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <Label>City *</Label>
                <Input {...register("city")} placeholder="e.g., Gandhinagar" />
                {errors.city && <p className="text-xs text-rose-500">{errors.city.message}</p>}
              </div>

              <div className="space-y-1">
                <Label>Phone Number *</Label>
                <Input {...register("phoneNo")} placeholder="10-digit phone" maxLength={10} />
                {errors.phoneNo && <p className="text-xs text-rose-500">{errors.phoneNo.message}</p>}
              </div>
            </div>

            <div className="space-y-1">
              <Label>Personal Email *</Label>
              <Input {...register("personalEmail")} type="email" placeholder="email@example.com" />
              {errors.personalEmail && <p className="text-xs text-rose-500">{errors.personalEmail.message}</p>}
            </div>

            <div className="flex flex-wrap gap-6">
              <div className="flex items-center gap-2">
                <input type="checkbox" id="dep" {...register("dependent")} />
                <Label htmlFor="dep">Dependent</Label>
              </div>
              <div className="flex items-center gap-2">
                <input type="checkbox" id="emp" {...register("employed")} />
                <Label htmlFor="emp">Employed</Label>
              </div>
              <div className="flex items-center gap-2">
                <input type="checkbox" id="nom" {...register("isNominee")} />
                <Label htmlFor="nom">Is Nominee</Label>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="emergency"
                  checked={Boolean(isEmergencyContact)}
                  onChange={(e) => setValue("isEmergencyContact", e.target.checked)}
                />
                <Label htmlFor="emergency">Emergency contact</Label>
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

      <Dialog open={!!deleteId} onOpenChange={(o) => !o && setDeleteId(null)}>
        <DialogContent className="sm:max-w-xs">
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
