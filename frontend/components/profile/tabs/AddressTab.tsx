"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { useAddress } from "@/lib/hooks/useAddress";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { MapPin, Clock, Trash2 } from "lucide-react";
import { useRequestChange, usePendingRequest } from "@/lib/hooks/useApprovals";
import { toast } from "sonner";
import { useQueryClient } from "@tanstack/react-query";

interface AddressTabProps {
  employeeId: string;
  isAdmin?: boolean;
}

function Field({ label, value }: { label: string; value?: string | null }) {
  return (
    <div>
      <p className="text-[10px] font-semibold text-slate-400 uppercase tracking-widest mb-0.5">
        {label}
      </p>
      <p className="text-sm text-slate-700">{value || <span className="text-slate-300 italic">—</span>}</p>
    </div>
  );
}

function AddressCard({ title, address }: { title: string; address: any }) {
  if (!address) {
    return (
      <div className="p-4 bg-slate-50 rounded-xl border border-dashed border-slate-200 flex items-center gap-3">
        <MapPin className="w-4 h-4 text-slate-300" />
        <p className="text-xs text-slate-400">{title}: Not filled yet</p>
      </div>
    );
  }
  return (
    <div className="p-4 bg-white/40 backdrop-blur-md rounded-xl border border-white/50 shadow-sm space-y-2">
      <p className="text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-3">{title}</p>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <Field label="Flat / Block No" value={address.flatBlockNo} />
        <Field label="Building / Society" value={address.buildingSociety} />
        <Field label="Area" value={address.area} />
        <Field label="City" value={address.city} />
        <Field label="State" value={address.state} />
        <Field label="Pincode" value={address.zipPostalCode} />
        <Field label="Country" value={address.country} />
        {address.personalEmail && <Field label="Personal Email" value={address.personalEmail} />}
        {address.instituteEmail && <Field label="Institutional Email" value={address.instituteEmail} />}
        {address.phoneNo && <Field label="Phone" value={address.phoneNo} />}
        {address.mobileNo && <Field label="Mobile" value={address.mobileNo} />}
      </div>
    </div>
  );
}

function AddressFields({ prefix }: { prefix: "local" | "permanent" }) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <div className="space-y-1">
        <Label>Flat / Block No</Label>
        <Input name={`${prefix}.flatBlockNo`} />
      </div>
      <div className="space-y-1">
        <Label>Building / Society</Label>
        <Input name={`${prefix}.buildingSociety`} />
      </div>
      <div className="sm:col-span-2 space-y-1">
        <Label>Area / Street *</Label>
        <Input name={`${prefix}.area`} />
      </div>
      <div className="space-y-1">
        <Label>City *</Label>
        <Input name={`${prefix}.city`} />
      </div>
      <div className="space-y-1">
        <Label>State *</Label>
        <Input name={`${prefix}.state`} />
      </div>
      <div className="space-y-1">
        <Label>Pincode *</Label>
        <Input name={`${prefix}.zipPostalCode`} maxLength={6} />
      </div>
      <div className="space-y-1">
        <Label>Country</Label>
        <Input name={`${prefix}.country`} defaultValue="India" />
      </div>
      <div className="space-y-1">
        <Label>Phone No</Label>
        <Input name={`${prefix}.phoneNo`} />
      </div>
      <div className="space-y-1">
        <Label>Mobile No</Label>
        <Input name={`${prefix}.mobileNo`} />
      </div>
      <div className="sm:col-span-2 space-y-1">
        <Label>Personal Email</Label>
        <Input name={`${prefix}.personalEmail`} type="email" />
      </div>
      <div className="sm:col-span-2 space-y-1">
        <Label>Institutional Email</Label>
        <Input name={`${prefix}.instituteEmail`} type="email" placeholder="firstname.lastname@gandhinagaruni.ac.in" />
      </div>
    </div>
  );
}

export function AddressTab({ employeeId, isAdmin }: AddressTabProps) {
  const [editing, setEditing] = useState(false);
  const [sameAsLocal, setSameAsLocal] = useState(false);
  const [requestSent, setRequestSent] = useState(false);
  const queryClient = useQueryClient();

  const { localAddress, permanentAddress, loading, saving, saveAddresses } =
    useAddress(employeeId);

  // Approval hooks for employee
  const requestChange = useRequestChange();
  const { data: pendingLocal } = usePendingRequest("ADDRESS_LOCAL");
  const { data: pendingPermanent } = usePendingRequest("ADDRESS_PERMANENT");
  
  const hasPending = (!isAdmin && (pendingLocal?.status === "PENDING" || pendingPermanent?.status === "PENDING"));
  const hasRejected = (!isAdmin && (pendingLocal?.status === "REJECTED" || pendingPermanent?.status === "REJECTED"));

  const { register, handleSubmit, watch, setValue } = useForm({
    defaultValues: {
      local: {
        flatBlockNo: localAddress?.flatBlockNo ?? "",
        buildingSociety: localAddress?.buildingSociety ?? "",
        area: localAddress?.area ?? "",
        city: localAddress?.city ?? "",
        state: localAddress?.state ?? "",
        zipPostalCode: localAddress?.zipPostalCode ?? "",
        country: localAddress?.country ?? "India",
        phoneNo: localAddress?.phoneNo ?? "",
        mobileNo: localAddress?.mobileNo ?? "",
        personalEmail: localAddress?.personalEmail ?? "",
        instituteEmail: localAddress?.instituteEmail ?? "",
      },
      permanent: {
        flatBlockNo: permanentAddress?.flatBlockNo ?? "",
        buildingSociety: permanentAddress?.buildingSociety ?? "",
        area: permanentAddress?.area ?? "",
        city: permanentAddress?.city ?? "",
        state: permanentAddress?.state ?? "",
        zipPostalCode: permanentAddress?.zipPostalCode ?? "",
        country: permanentAddress?.country ?? "India",
        phoneNo: permanentAddress?.phoneNo ?? "",
        mobileNo: permanentAddress?.mobileNo ?? "",
        personalEmail: permanentAddress?.personalEmail ?? "",
        instituteEmail: permanentAddress?.instituteEmail ?? "",
      },
    },
  });

  const localValues = watch("local");

  const onSubmit = async (data: any) => {
    if (isAdmin) {
      // Admin: Direct REST save
      await saveAddresses(
        data.local,
        sameAsLocal ? data.local : data.permanent
      );
      setEditing(false);
    } else {
      // Employee: Submit change requests
      try {
        const localData = data.local;
        const permanentData = sameAsLocal ? data.local : data.permanent;

        // We fire both requests. The backend handles them as separate change requests.
        await Promise.all([
          requestChange.mutateAsync({ module: "ADDRESS_LOCAL", newData: localData }),
          requestChange.mutateAsync({ module: "ADDRESS_PERMANENT", newData: permanentData }),
        ]);

        setEditing(false);
        setRequestSent(true);
        toast.success("Address change requests submitted for HR approval");
      } catch (err) {
        // Error toast handled by useRequestChange
      }
    }
  };

  if (loading) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-10 w-full" />
          ))}
        </CardContent>
      </Card>
    );
  }

  if (!editing) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-4">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Address Information</h3>
            {(!hasPending || isAdmin) && (
              <Button
                size="sm"
                variant="outline"
                onClick={() => setEditing(true)}
                className="text-xs border-[#1d3459] text-[#1d3459] hover:bg-[#1d3459] hover:text-white"
              >
                Edit
              </Button>
            )}
          </div>

          {/* Status banners — employee only */}
          {!isAdmin && hasPending && (
            <div className="flex items-start gap-3 p-3 rounded-xl bg-amber-50 border border-amber-200 text-xs shadow-sm">
              <Clock className="w-4 h-4 text-amber-500 mt-0.5 shrink-0" />
              <div>
                <p className="font-bold text-amber-700">Address Update Pending HR Approval</p>
                <p className="text-amber-600 mt-0.5 leading-relaxed">
                  Your request has been submitted. The address will be updated once HR approves.
                </p>
              </div>
            </div>
          )}

          {!isAdmin && hasRejected && !hasPending && (
            <div className="flex items-start gap-3 p-3 rounded-xl bg-rose-50 border border-rose-200 text-xs shadow-sm">
              <Trash2 className="w-4 h-4 text-rose-500 mt-0.5 shrink-0" />
              <div className="flex-1">
                <p className="font-bold text-rose-700">Address Update Not Approved</p>
                <p className="text-rose-600 mt-0.5 leading-relaxed">
                  Your recent address update request was not approved. Please contact HR.
                </p>
                <Button 
                  variant="link" 
                  size="sm" 
                  className="h-auto p-0 mt-2 text-rose-600 font-bold hover:text-rose-700 text-[10px] uppercase tracking-wider"
                  onClick={() => setEditing(true)}
                >
                  Edit & Resubmit →
                </Button>
              </div>
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <AddressCard title="Local / Current Address" address={localAddress} />
            <AddressCard title="Permanent Address" address={permanentAddress} />
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardContent className="pt-5">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Edit Address</h3>
            <div className="flex gap-2">
              <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(false)}>
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
            </div>
          </div>

          {/* Local Address */}
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">
              Local / Current Address
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 bg-white/40 backdrop-blur-md p-4 rounded-xl border border-white/40">
              <div className="space-y-1">
                <Label>Flat / Block No</Label>
                <Input {...register("local.flatBlockNo")} />
              </div>
              <div className="space-y-1">
                <Label>Building / Society</Label>
                <Input {...register("local.buildingSociety")} />
              </div>
              <div className="sm:col-span-2 space-y-1">
                <Label>Area / Street</Label>
                <Input {...register("local.area")} />
              </div>
              <div className="space-y-1">
                <Label>City *</Label>
                <Input {...register("local.city")} />
              </div>
              <div className="space-y-1">
                <Label>State *</Label>
                <Input {...register("local.state")} />
              </div>
              <div className="space-y-1">
                <Label>Pincode</Label>
                <Input {...register("local.zipPostalCode")} maxLength={6} />
              </div>
              <div className="space-y-1">
                <Label>Country</Label>
                <Input {...register("local.country")} />
              </div>
              <div className="space-y-1">
                <Label>Phone</Label>
                <Input {...register("local.phoneNo")} />
              </div>
              <div className="space-y-1">
                <Label>Mobile</Label>
                <Input {...register("local.mobileNo")} />
              </div>
              <div className="sm:col-span-2 space-y-1">
                <Label>Personal Email</Label>
                <Input {...register("local.personalEmail")} type="email" />
              </div>
              <div className="sm:col-span-2 space-y-1">
                <Label>Institutional Email</Label>
                <Input {...register("local.instituteEmail")} type="email" placeholder="firstname.lastname@gandhinagaruni.ac.in" />
              </div>
            </div>
          </div>

          <Separator />

          {/* Same as local checkbox */}
          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              id="sameAsLocal"
              checked={sameAsLocal}
              onChange={(e) => setSameAsLocal(e.target.checked)}
              className="rounded"
            />
            <Label htmlFor="sameAsLocal" className="cursor-pointer text-sm">
              Permanent address same as local address
            </Label>
          </div>

          {/* Permanent Address */}
          {!sameAsLocal && (
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">
                Permanent Address
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 bg-white/40 backdrop-blur-md p-4 rounded-xl border border-white/40">
                <div className="space-y-1">
                  <Label>Flat / Block No</Label>
                  <Input {...register("permanent.flatBlockNo")} />
                </div>
                <div className="space-y-1">
                  <Label>Building / Society</Label>
                  <Input {...register("permanent.buildingSociety")} />
                </div>
                <div className="sm:col-span-2 space-y-1">
                  <Label>Area / Street</Label>
                  <Input {...register("permanent.area")} />
                </div>
                <div className="space-y-1">
                  <Label>City *</Label>
                  <Input {...register("permanent.city")} />
                </div>
                <div className="space-y-1">
                  <Label>State *</Label>
                  <Input {...register("permanent.state")} />
                </div>
                <div className="space-y-1">
                  <Label>Pincode</Label>
                  <Input {...register("permanent.zipPostalCode")} maxLength={6} />
                </div>
                <div className="space-y-1">
                  <Label>Country</Label>
                  <Input {...register("permanent.country")} />
                </div>
                <div className="space-y-1">
                  <Label>Phone</Label>
                  <Input {...register("permanent.phoneNo")} />
                </div>
                <div className="space-y-1">
                  <Label>Mobile</Label>
                  <Input {...register("permanent.mobileNo")} />
                </div>
                <div className="sm:col-span-2 space-y-1">
                  <Label>Personal Email</Label>
                  <Input {...register("permanent.personalEmail")} type="email" />
                </div>
                <div className="sm:col-span-2 space-y-1">
                  <Label>Institutional Email</Label>
                  <Input {...register("permanent.instituteEmail")} type="email" placeholder="firstname.lastname@gandhinagaruni.ac.in" />
                </div>
              </div>
            </div>
          )}
        </form>
      </CardContent>
    </Card>
  );
}
