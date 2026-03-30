"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useEmployeeBase, usePersonalInfo } from "../../hooks/useProfile";
import { Skeleton } from "@/components/ui/skeleton";
import { FileCheck, ShieldCheck, Camera, PenTool, CheckCircle2, AlertCircle, ExternalLink, RefreshCw } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

interface DocumentsTabProps {
  employeeId: string | number;
}

function DocCard({ title, icon: Icon, url, required = true }: { title: string; icon: any; url?: string | null; required?: boolean }) {
  const isUploaded = !!url;

  return (
    <div className="bg-white/50 border border-slate-100 rounded-2xl p-5 shadow-sm flex items-center justify-between group transition-all hover:shadow-md">
      <div className="flex items-center gap-4">
        <div className={`w-12 h-12 rounded-xl flex items-center justify-center transition-colors ${isUploaded ? "bg-emerald-50 text-emerald-500" : "bg-slate-50 text-slate-300"}`}>
            <Icon className="w-6 h-6" />
        </div>
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <h4 className="font-bold text-slate-800 text-sm">{title}</h4>
            {required && <span className="text-rose-400 font-bold text-[8px] uppercase tracking-tighter">* Required</span>}
          </div>
          <div className="flex items-center gap-1.5">
            {isUploaded ? (
              <>
                <CheckCircle2 className="w-3 h-3 text-emerald-500" />
                <span className="text-xs font-bold text-emerald-600 uppercase tracking-widest text-[9px]">Verified / Uploaded</span>
              </>
            ) : (
              <>
                <AlertCircle className="w-3 h-3 text-amber-500" />
                <span className="text-xs font-bold text-amber-600 uppercase tracking-widest text-[9px]">Pending Upload</span>
              </>
            )}
          </div>
        </div>
      </div>

      <div className="flex items-center gap-2">
        {isUploaded ? (
          <a href={url} target="_blank" rel="noreferrer">
             <Button variant="ghost" size="sm" className="h-8 rounded-lg text-[#1d3459] hover:bg-[#1d3459]/5 font-bold text-[10px] uppercase gap-2 px-3">
                <ExternalLink className="w-3 h-3" /> View
             </Button>
          </a>
        ) : (
          <Button size="sm" className="h-8 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-600 font-bold text-[10px] uppercase px-3 shadow-none">
             Upload Now
          </Button>
        )}
      </div>
    </div>
  );
}

export function DocumentsTab({ employeeId }: DocumentsTabProps) {
  const { data: employee, isLoading: isEmpLoading } = useEmployeeBase(employeeId);
  const { data: personal, isLoading: isPersLoading } = usePersonalInfo(employeeId);

  if (isEmpLoading || isPersLoading) return <Skeleton className="h-[400px] rounded-2xl" />;

  return (
    <Card className="border-none shadow-none bg-transparent">
      <CardHeader className="px-0 pt-0 pb-6">
        <div className="flex items-center justify-between">
           <div className="space-y-1">
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-[#1d3459]" />
                <CardTitle className="text-sm font-bold text-slate-800 uppercase tracking-tight">
                  Document Repository
                </CardTitle>
              </div>
              <p className="text-[11px] text-slate-500 font-medium">
                Mandatory identity documents and profile assets for institucional verification.
              </p>
           </div>
           <Button variant="outline" size="sm" className="h-8 border-slate-200 text-slate-400 font-bold text-[9px] uppercase hover:text-slate-600">
               <RefreshCw className="w-3 h-3 mr-1.5" /> Force Refresh
           </Button>
        </div>
      </CardHeader>
      
      <CardContent className="px-0">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <DocCard 
            title="Passport Photo" 
            icon={Camera} 
            url={employee?.photoUrl} 
          />
          <DocCard 
            title="Official Signature" 
            icon={PenTool} 
            url={employee?.signatureUrl} 
          />
          <DocCard 
            title="Aadhaar Card (PDF)" 
            icon={FileCheck} 
            url={(personal as any)?.aadhaarCardUrl} 
          />
          <DocCard 
            title="PAN Card (PDF)" 
            icon={FileCheck} 
            url={(personal as any)?.panCardUrl} 
          />
        </div>

        <div className="mt-8 p-6 bg-[#1d3459] rounded-2xl text-white shadow-xl shadow-[#1d3459]/10 relative overflow-hidden">
             <div className="relative z-10 space-y-2">
                 <h4 className="text-lg font-extrabold tracking-tight">Compliance Status</h4>
                 <div className="flex items-center gap-3">
                     <Badge className="bg-white/20 hover:bg-white/30 text-white border-none text-[9px] font-bold uppercase tracking-widest px-3">Audited: Mar 2026</Badge>
                     <p className="text-xs font-medium text-white/70">Your profile is currently 75% complete. Please upload missing documents to achieve full compliance.</p>
                 </div>
             </div>
             <ShieldCheck className="absolute -right-8 -bottom-8 w-48 h-48 text-white/5 rotate-12" />
        </div>
      </CardContent>
    </Card>
  );
}
