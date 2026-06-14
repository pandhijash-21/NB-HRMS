"use client";



import { useEffect, useMemo, useState } from "react";

import { Button } from "@/components/ui/button";

import { Input } from "@/components/ui/input";

import { Label } from "@/components/ui/label";

import {

  Select,

  SelectContent,

  SelectItem,

  SelectTrigger,

  SelectValue,

} from "@/components/ui/select";

import { Badge } from "@/components/ui/badge";

import Link from "next/link";

import { useCreatePositionSlot, useDesignations } from "@/lib/hooks/useDesignations";

import { useInstitutes } from "@/lib/hooks/useInstitutes";

import { AccountCredentialsDialog } from "@/components/admin/AccountCredentialsDialog";

import { toast } from "sonner";



type Props = {

  onCreated?: () => void;

};



/** Inline form for Designations → Alias accounts (pick position, create HOI-GIT, etc.) */

export function AliasAccountForm({ onCreated }: Props) {

  const positions = useDesignations(true);

  const institutes = useInstitutes({ activeOnly: true });

  const create = useCreatePositionSlot();



  const [designationId, setDesignationId] = useState("");

  const [instituteId, setInstituteId] = useState("");

  const [code, setCode] = useState("");

  const [name, setName] = useState("");

  const [password, setPassword] = useState("01011998");

  const [universityWide, setUniversityWide] = useState(false);

  const [grantUniversityAccess, setGrantUniversityAccess] = useState(false);

  const [createdCreds, setCreatedCreds] = useState<{

    userId: string;

    loginId: string;

    password: string;

  } | null>(null);



  const selectedPosition = useMemo(

    () => (positions.data ?? []).find((d) => d.id === designationId),

    [positions.data, designationId],

  );



  const roleLabel = selectedPosition?.linkedRole?.name ?? null;

  const institute = (institutes.data ?? []).find((i) => i.id === instituteId);



  useEffect(() => {

    if (!selectedPosition) return;

    if (universityWide) {

      if (roleLabel) {

        setCode(roleLabel);

        setName(selectedPosition.name ?? roleLabel);

      }

      return;

    }

    if (!institute) return;

    const loginCode = `${roleLabel ?? "POS"}-${institute.code}`;

    setCode(loginCode);

    setName(`${selectedPosition.name} — ${institute.code}`);

  }, [selectedPosition, institute, roleLabel, universityWide]);



  const handleCreate = async () => {

    if (!designationId || !code.trim() || !name.trim() || !password) return;

    if (!selectedPosition?.linkedRoleId) {

      toast.error("This position has no role. Create the position from Workforce first.");

      return;

    }



    try {

      const result = await create.mutateAsync({

        code: code.trim().toUpperCase(),

        name: name.trim(),

        designationId,

        instituteId: universityWide ? undefined : institute?.id,

        password,

        grantUniversityAccess: universityWide && grantUniversityAccess,

      });

      const loginId = result.credentials?.loginId ?? result.code;

      const plainPassword = result.credentials?.password ?? password;

      const userId = result.userId ?? result.user?.id;

      if (userId) {

        setCreatedCreds({ userId, loginId, password: plainPassword });

      }

      toast.success(`Alias account ${loginId} created — ready to log in`);

      setDesignationId("");

      setInstituteId("");

      setCode("");

      setName("");

      setUniversityWide(false);

      setGrantUniversityAccess(false);

      onCreated?.();

    } catch (err: unknown) {

      toast.error(err instanceof Error ? err.message : "Failed to create alias account");

    }

  };



  const canSubmit =

    !!designationId &&

    !!code.trim() &&

    !!name.trim() &&

    !!password &&

    !!selectedPosition?.linkedRoleId &&

    (universityWide || !!instituteId);



  const positionCount = (positions.data ?? []).length;



  return (

    <div className="space-y-4">

      {positionCount === 0 ? (

        <p className="text-sm text-amber-700 bg-amber-50 border border-amber-100 rounded-lg px-3 py-2">

          No positions yet. Create one from{" "}

          <Link href="/admin/employees" className="font-bold underline">Workforce → Create Position</Link>

          , then set permissions under Roles &amp; Permissions.

        </p>

      ) : (

        <>

          <div className="space-y-2">

            <Label className="text-xs font-bold text-slate-500 uppercase">Position</Label>

            <Select value={designationId} onValueChange={setDesignationId}>

              <SelectTrigger>

                <SelectValue placeholder="Which position is this alias for?" />

              </SelectTrigger>

              <SelectContent>

                {(positions.data ?? []).map((d) => (

                  <SelectItem key={d.id} value={d.id}>

                    {d.name}

                    {d.linkedRole ? ` (${d.linkedRole.name})` : ""}

                  </SelectItem>

                ))}

              </SelectContent>

            </Select>

            <p className="text-[10px] text-slate-400">

              Permissions come from the position&apos;s role.{" "}

              {selectedPosition?.linkedRole && (

                <Link href={`/admin/roles`} className="text-[#1d3459] underline">

                  Edit in Roles &amp; Permissions

                </Link>

              )}

            </p>

          </div>



          {selectedPosition && (

            <div className="rounded-lg border border-slate-100 bg-slate-50/80 px-3 py-2 text-xs text-slate-600">

              Inherits permissions:{" "}

              {roleLabel ? (

                <Badge variant="outline" className="ml-1 text-[10px] font-bold uppercase">

                  {roleLabel}

                </Badge>

              ) : (

                <span className="text-rose-600">No role linked</span>

              )}

            </div>

          )}



          <div className="rounded-lg border border-blue-100 bg-blue-50/50 p-3 space-y-3">

            <div className="flex items-start gap-2">

              <input

                type="checkbox"

                id="alias-university-wide"

                aria-label="University-wide alias without institute binding"

                checked={universityWide}

                onChange={(e) => {

                  setUniversityWide(e.target.checked);

                  if (e.target.checked) {

                    setInstituteId("");

                  } else {

                    setGrantUniversityAccess(false);

                  }

                }}

                className="rounded border-slate-300 mt-0.5"

              />

              <div>

                <Label htmlFor="alias-university-wide" className="text-xs text-slate-700 cursor-pointer font-semibold">

                  University-wide (no institute binding)

                </Label>

                <p className="text-[10px] text-slate-500 mt-0.5">

                  For IT Admin, VC, Registrar, etc. — not tied to a single institute.

                </p>

              </div>

            </div>



            {universityWide && (

              <div className="flex items-start gap-2 pl-6 border-l-2 border-[#1d3459]/20">

                <input

                  type="checkbox"

                  id="alias-grant-university-access"

                  checked={grantUniversityAccess}

                  onChange={(e) => setGrantUniversityAccess(e.target.checked)}

                  className="rounded border-slate-300 mt-0.5"

                />

                <div>

                  <Label htmlFor="alias-grant-university-access" className="text-xs text-slate-700 cursor-pointer font-semibold">

                    Grant full university admin access

                  </Label>

                  <p className="text-[10px] text-slate-500 mt-0.5">

                    Auto-applies full permissions + view all employees to this position&apos;s role

                    (IT Admin, IT Engineer, …). Affects all aliases sharing this role.

                  </p>

                </div>

              </div>

            )}

          </div>



          {!universityWide && (

            <div className="space-y-2">

              <Label className="text-xs font-bold text-slate-500 uppercase">Institute</Label>

              <Select value={instituteId} onValueChange={setInstituteId} disabled={institutes.isLoading}>

                <SelectTrigger>

                  <SelectValue placeholder={institutes.isLoading ? "Loading…" : "Select institute"} />

                </SelectTrigger>

                <SelectContent>

                  {(institutes.data ?? []).map((i) => (

                    <SelectItem key={i.id} value={i.id}>

                      {i.name} ({i.code})

                    </SelectItem>

                  ))}

                </SelectContent>

              </Select>

              <p className="text-[10px] text-slate-400">

                Set workforce scope to <strong>Institute only</strong> on this role in Roles &amp; Permissions.

              </p>

            </div>

          )}



          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">

            <div className="space-y-2">

              <Label className="text-xs font-bold text-slate-500 uppercase">Login code</Label>

              <Input value={code} onChange={(e) => setCode(e.target.value.toUpperCase())} placeholder="HOI-GIT" />

            </div>

            <div className="space-y-2">

              <Label className="text-xs font-bold text-slate-500 uppercase">Display name</Label>

              <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Head of Institute — GIT" />

            </div>

          </div>



          <div className="space-y-2">

            <Label className="text-xs font-bold text-slate-500 uppercase">Initial password</Label>

            <Input type="password" value={password} onChange={(e) => setPassword(e.target.value)} />

          </div>



          <Button

            onClick={handleCreate}

            disabled={!canSubmit || create.isPending}

            className="bg-[#1d3459] hover:bg-[#2a4a7f] text-white font-bold"

          >

            {create.isPending ? "Creating…" : "Create alias account"}

          </Button>

        </>

      )}



      <AccountCredentialsDialog

        userId={createdCreds?.userId ?? null}

        title={createdCreds ? `Alias created — ${createdCreds.loginId}` : "Login credentials"}

        open={!!createdCreds}

        onOpenChange={(open) => { if (!open) setCreatedCreds(null); }}

        initialCredentials={

          createdCreds

            ? { loginId: createdCreds.loginId, password: createdCreds.password }

            : null

        }

      />

    </div>

  );

}


