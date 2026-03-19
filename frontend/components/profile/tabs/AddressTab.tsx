"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { addressSchema, type AddressFormData } from "@/lib/validators/address.schema";
import { useAddress } from "@/lib/hooks/useAddress";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";

interface AddressTabProps {
  employeeId: string;
  isAdmin?: boolean;
}

function AddressCard({ title, address }: { title: string; address: Record<string, unknown> | null }) {
  if (!address) {
    return (
      <div className="p-4 bg-slate-50 rounded-lg border border-dashed border-slate-200">
        <p className="text-xs text-slate-400">{title}: Not filled yet</p>
      </div>
    );
  }
  return (
    <div className="p-4 bg-slate-50 rounded-lg">
      <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">{title}</p>
      <p className="text-sm text-slate-700">{address.addressLine1 as string}</p>
      {address.addressLine2 && <p className="text-sm text-slate-700">{address.addressLine2 as string}</p>}
      <p className="text-sm text-slate-700">
        {address.city as string}, {address.state as string} – {address.pincode as string}
      </p>
      {address.district && <p className="text-xs text-slate-400">{address.district as string}</p>}
      <p className="text-xs text-slate-400">{(address.country as string) ?? "India"}</p>
    </div>
  );
}

export function AddressTab({ employeeId, isAdmin }: AddressTabProps) {
  const [editing, setEditing] = useState(false);
  const { localAddress, permanentAddress, loading, saving, saveAddresses } = useAddress(employeeId);

  const { register, handleSubmit, watch, setValue, formState: { errors } } = useForm<AddressFormData>({
    resolver: zodResolver(addressSchema),
    defaultValues: {
      local: {
        addressLine1: (localAddress?.addressLine1 as string) ?? "",
        addressLine2: (localAddress?.addressLine2 as string) ?? "",
        city: (localAddress?.city as string) ?? "",
        district: (localAddress?.district as string) ?? "",
        state: (localAddress?.state as string) ?? "",
        pincode: (localAddress?.pincode as string) ?? "",
        country: (localAddress?.country as string) ?? "India",
      },
      permanent: {
        addressLine1: (permanentAddress?.addressLine1 as string) ?? "",
        addressLine2: (permanentAddress?.addressLine2 as string) ?? "",
        city: (permanentAddress?.city as string) ?? "",
        district: (permanentAddress?.district as string) ?? "",
        state: (permanentAddress?.state as string) ?? "",
        pincode: (permanentAddress?.pincode as string) ?? "",
        country: (permanentAddress?.country as string) ?? "India",
      },
      sameAsLocal: false,
    },
  });

  const sameAsLocal = watch("sameAsLocal");
  const localValues = watch("local");

  const handleSameAsLocal = (checked: boolean) => {
    setValue("sameAsLocal", checked);
    if (checked) {
      setValue("permanent", { ...localValues });
    }
  };

  const onSubmit = async (data: AddressFormData) => {
    await saveAddresses(
      data.local as Record<string, unknown>,
      data.sameAsLocal ? (data.local as Record<string, unknown>) : (data.permanent as Record<string, unknown>)
    );
    setEditing(false);
  };

  if (loading) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-3">
          {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-10 w-full" />)}
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
            {isAdmin && (
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
              <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(false)}>Cancel</Button>
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
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="sm:col-span-2 space-y-1">
                <Label>Address Line 1 *</Label>
                <Input {...register("local.addressLine1")} />
                {errors.local?.addressLine1 && <p className="text-xs text-rose-500">{errors.local.addressLine1.message}</p>}
              </div>
              <div className="sm:col-span-2 space-y-1">
                <Label>Address Line 2</Label>
                <Input {...register("local.addressLine2")} />
              </div>
              <div className="space-y-1">
                <Label>City *</Label>
                <Input {...register("local.city")} />
                {errors.local?.city && <p className="text-xs text-rose-500">{errors.local.city.message}</p>}
              </div>
              <div className="space-y-1">
                <Label>District</Label>
                <Input {...register("local.district")} />
              </div>
              <div className="space-y-1">
                <Label>State *</Label>
                <Input {...register("local.state")} />
                {errors.local?.state && <p className="text-xs text-rose-500">{errors.local.state.message}</p>}
              </div>
              <div className="space-y-1">
                <Label>Pincode *</Label>
                <Input {...register("local.pincode")} maxLength={6} />
                {errors.local?.pincode && <p className="text-xs text-rose-500">{errors.local.pincode.message}</p>}
              </div>
              <div className="space-y-1">
                <Label>Country</Label>
                <Input {...register("local.country")} defaultValue="India" />
              </div>
            </div>
          </div>

          <Separator />

          {/* Same as local */}
          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              id="sameAsLocal"
              checked={!!sameAsLocal}
              onChange={(e) => handleSameAsLocal(e.target.checked)}
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
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="sm:col-span-2 space-y-1">
                  <Label>Address Line 1 *</Label>
                  <Input {...register("permanent.addressLine1")} />
                  {errors.permanent?.addressLine1 && <p className="text-xs text-rose-500">{errors.permanent.addressLine1.message}</p>}
                </div>
                <div className="sm:col-span-2 space-y-1">
                  <Label>Address Line 2</Label>
                  <Input {...register("permanent.addressLine2")} />
                </div>
                <div className="space-y-1">
                  <Label>City *</Label>
                  <Input {...register("permanent.city")} />
                </div>
                <div className="space-y-1">
                  <Label>District</Label>
                  <Input {...register("permanent.district")} />
                </div>
                <div className="space-y-1">
                  <Label>State *</Label>
                  <Input {...register("permanent.state")} />
                </div>
                <div className="space-y-1">
                  <Label>Pincode *</Label>
                  <Input {...register("permanent.pincode")} maxLength={6} />
                </div>
                <div className="space-y-1">
                  <Label>Country</Label>
                  <Input {...register("permanent.country")} defaultValue="India" />
                </div>
              </div>
            </div>
          )}
        </form>
      </CardContent>
    </Card>
  );
}
