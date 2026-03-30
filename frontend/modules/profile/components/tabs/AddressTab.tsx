"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAddresses, useUpsertAddress } from "../../hooks/useProfile";
import { Address } from "../../types";
import { Skeleton } from "@/components/ui/skeleton";
import { MapPin, Edit3, Save, X, Mail, Phone, Smartphone, Globe } from "lucide-react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

const addressSchema = z.object({
  addressType: z.enum(["LOCAL", "PERMANENT"]),
  flatBlockNo: z.string().min(1, "Required"),
  buildingSociety: z.string().min(1, "Required"),
  area: z.string().min(1, "Required"),
  city: z.string().min(1, "Required"),
  state: z.string().min(1, "Required"),
  country: z.string().min(1, "Required"),
  zipPostalCode: z.string().min(6, "Invalid Pincode"),
  phoneNo: z.string().optional().nullable(),
  mobileNo: z.string().optional().nullable(),
  personalEmail: z.string().email().optional().nullable(),
  instituteEmail: z.string().email().optional().nullable(),
});

type AddressFormData = z.infer<typeof addressSchema>;

interface AddressTabProps {
  employeeId: string | number;
}

function AddressDisplay({ address }: { address: Address }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-8 py-2">
      <div className="space-y-4">
        <div className="flex items-start gap-3">
          <MapPin className="w-4 h-4 mt-1 text-[#1d3459]/60" />
          <div className="space-y-1">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest leading-none">Postal Address</p>
            <p className="text-sm font-semibold text-slate-700 leading-relaxed">
              {address.flatBlockNo}, {address.buildingSociety},<br />
              {address.area}, {address.city},<br />
              {address.state}, {address.country} - {address.zipPostalCode}
            </p>
          </div>
        </div>
      </div>
      
      <div className="grid grid-cols-1 gap-4">
        <div className="flex items-center gap-3 p-3 rounded-xl bg-slate-50/50 border border-slate-100/50">
          <Smartphone className="w-4 h-4 text-slate-400" />
          <div>
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest leading-none">Mobile</p>
            <p className="text-sm font-semibold text-slate-700">{address.mobileNo || "—"}</p>
          </div>
        </div>
        <div className="flex items-center gap-3 p-3 rounded-xl bg-slate-50/50 border border-slate-100/50">
          <Mail className="w-4 h-4 text-slate-400" />
          <div className="truncate">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest leading-none">Email (Work)</p>
            <p className="text-sm font-semibold text-slate-700 truncate">{address.instituteEmail || "—"}</p>
          </div>
        </div>
      </div>
    </div>
  );
}

export function AddressTab({ employeeId }: AddressTabProps) {
  const [editingType, setEditingType] = useState<"LOCAL" | "PERMANENT" | null>(null);
  const { data: addresses, isLoading } = useAddresses(employeeId);
  const upsertMutation = useUpsertAddress(employeeId);

  const localAddress = addresses?.find(a => a.addressType === "LOCAL");
  const permanentAddress = addresses?.find(a => a.addressType === "PERMANENT");

  const { register, handleSubmit, reset, formState: { errors } } = useForm<AddressFormData>({
    resolver: zodResolver(addressSchema),
  });

  const onEdit = (type: "LOCAL" | "PERMANENT") => {
    const data = type === "LOCAL" ? localAddress : permanentAddress;
    reset({
      addressType: type,
      flatBlockNo: data?.flatBlockNo || "",
      buildingSociety: data?.buildingSociety || "",
      area: data?.area || "",
      city: data?.city || "",
      state: data?.state || "",
      country: data?.country || "INDIA",
      zipPostalCode: data?.zipPostalCode || "",
      phoneNo: data?.phoneNo || "",
      mobileNo: data?.mobileNo || "",
      personalEmail: data?.personalEmail || "",
      instituteEmail: data?.instituteEmail || "",
    });
    setEditingType(type);
  };

  const onSubmit = (data: AddressFormData) => {
    upsertMutation.mutate(data, {
      onSuccess: () => setEditingType(null),
    });
  };

  if (isLoading) return <Skeleton className="h-[400px] rounded-2xl" />;

  return (
    <div className="space-y-6">
      <Tabs defaultValue="LOCAL" className="w-full">
        <div className="flex items-center justify-between mb-4 px-1">
          <TabsList className="bg-slate-100/50 p-1 h-9 rounded-xl border border-slate-200/50">
            <TabsTrigger value="LOCAL" className="rounded-lg text-[10px] font-bold uppercase px-6 data-[state=active]:bg-white data-[state=active]:text-[#1d3459] data-[state=active]:shadow-sm">Current</TabsTrigger>
            <TabsTrigger value="PERMANENT" className="rounded-lg text-[10px] font-bold uppercase px-6 data-[state=active]:bg-white data-[state=active]:text-[#1d3459] data-[state=active]:shadow-sm">Permanent</TabsTrigger>
          </TabsList>
          
           {!editingType ? (
            <Button 
               variant="ghost" 
               size="sm" 
               className="text-[#1d3459] font-bold text-[10px] uppercase gap-2"
               onClick={() => onEdit(document.querySelector('[data-state="active"][role="tab"]')?.getAttribute('data-value') as any || "LOCAL")}
            >
              <Edit3 className="w-3 h-3" /> Update Address
            </Button>
          ) : (
             <div className="flex gap-2">
                <Button variant="ghost" size="sm" className="text-slate-500 font-bold text-[10px] uppercase" onClick={() => setEditingType(null)}>Cancel</Button>
                <Button 
                  size="sm" 
                  className="bg-[#d9b557] hover:bg-[#c9a547] text-[#1d3459] font-bold text-[10px] uppercase shadow-lg shadow-[#d9b557]/20 rounded-xl"
                  onClick={handleSubmit(onSubmit)}
                  disabled={upsertMutation.isPending}
                >
                  {upsertMutation.isPending ? "Saving..." : "Save Address"}
                </Button>
             </div>
          )}
        </div>

        <TabsContent value="LOCAL" className="mt-0 ring-0 focus-visible:ring-0">
          <Card className="border-none shadow-none bg-transparent">
            <CardContent className="px-0 pt-2">
              {editingType === "LOCAL" ? (
                <AddressForm register={register} errors={errors} />
              ) : (
                localAddress ? <AddressDisplay address={localAddress} /> : <div className="py-12 text-center bg-slate-50 rounded-2xl border border-dashed border-slate-200 text-sm text-slate-400 font-medium">No local address found.</div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="PERMANENT" className="mt-0 ring-0 focus-visible:ring-0">
          <Card className="border-none shadow-none bg-transparent">
            <CardContent className="px-0 pt-2">
              {editingType === "PERMANENT" ? (
                <AddressForm register={register} errors={errors} />
              ) : (
                permanentAddress ? <AddressDisplay address={permanentAddress} /> : <div className="py-12 text-center bg-slate-50 rounded-2xl border border-dashed border-slate-200 text-sm text-slate-400 font-medium">No permanent address found.</div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}

function AddressForm({ register, errors }: { register: any, errors: any }) {
  return (
    <div className="bg-white/50 border border-slate-100 rounded-2xl p-6 shadow-sm space-y-6 animate-in fade-in slide-in-from-top-2 duration-300">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        <div className="space-y-1.5">
          <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Flat / Block / House No *</Label>
          <Input {...register("flatBlockNo")} className="h-10 rounded-xl" placeholder="e.g. A-102" />
          {errors.flatBlockNo && <p className="text-[10px] text-rose-500 mt-1">{errors.flatBlockNo.message}</p>}
        </div>
        <div className="space-y-1.5">
          <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Building / Society *</Label>
          <Input {...register("buildingSociety")} className="h-10 rounded-xl" placeholder="e.g. Green Valley" />
          {errors.buildingSociety && <p className="text-[10px] text-rose-500 mt-1">{errors.buildingSociety.message}</p>}
        </div>
        <div className="space-y-1.5 md:col-span-2">
          <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Area / Street *</Label>
          <Input {...register("area")} className="h-10 rounded-xl" placeholder="e.g. Sector 24" />
        </div>
        <div className="space-y-1.5">
          <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">City / Village *</Label>
          <Input {...register("city")} className="h-10 rounded-xl" placeholder="e.g. Gandhinagar" />
        </div>
        <div className="space-y-1.5">
          <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">State *</Label>
          <Input {...register("state")} className="h-10 rounded-xl" placeholder="e.g. Gujarat" />
        </div>
        <div className="space-y-1.5">
          <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Country *</Label>
          <Input {...register("country")} className="h-10 rounded-xl" />
        </div>
        <div className="space-y-1.5">
          <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Pincode *</Label>
          <Input {...register("zipPostalCode")} className="h-10 rounded-xl" placeholder="382421" />
        </div>
      </div>
      
      <div className="pt-6 border-t border-slate-100 grid grid-cols-1 md:grid-cols-2 gap-5">
        <div className="space-y-1.5">
          <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1 text-emerald-600">Mobile No</Label>
          <div className="relative">
            <Smartphone className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-400" />
            <Input {...register("mobileNo")} className="h-10 rounded-xl pl-9" placeholder="+91..." />
          </div>
        </div>
        <div className="space-y-1.5">
          <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1 text-emerald-600">Work Email</Label>
          <div className="relative">
            <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-400" />
            <Input {...register("instituteEmail")} className="h-10 rounded-xl pl-9" placeholder="user@university.edu" />
          </div>
        </div>
      </div>
    </div>
  );
}
