"use client";

import { useMemo, useState } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useSession } from "next-auth/react";
import { canManageLetters } from "@/lib/auth/permissions";
import {
  downloadLetterPdf,
  useCreateCustomLetterDraft,
  useCreateLetterDraft,
  useDeleteLetterDocument,
  useEmployeeLetterDocuments,
  useFinalizeLetterDraft,
  useLetterTemplates,
  useUpdateLetterDraft,
  type LetterDocument,
} from "@/lib/hooks/useLetters";
import { LetterEditorDialog } from "@/components/letters/LetterEditorDialog";
import { Plus } from "lucide-react";

interface DocumentsTabProps {
  profile: Record<string, unknown> | null | undefined;
  canManageLetters?: boolean;
}

type DocEntry = {
  label: string;
  url?: string | null;
  note?: string | null;
};

function DocTile({ label, url, note }: DocEntry) {
  const hasUrl = !!url;
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4">
      <p className="text-xs font-semibold text-slate-500">{label}</p>
      {note ? <p className="mt-1 text-[11px] text-slate-400">{note}</p> : null}
      <div className="mt-3">
        {hasUrl ? (
          <a
            href={url!}
            target="_blank"
            rel="noreferrer"
            className="text-sm font-semibold text-[#1d3459] underline underline-offset-2"
          >
            View document
          </a>
        ) : (
          <span className="text-sm text-slate-400">Not uploaded</span>
        )}
      </div>
    </div>
  );
}

function Section({
  title,
  items,
}: {
  title: string;
  items: DocEntry[];
}) {
  if (items.length === 0) return null;
  return (
    <Card className="border-slate-200/60 shadow-sm">
      <CardContent className="pt-5 space-y-4">
        <h3 className="text-sm font-semibold text-slate-800">{title}</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {items.map((item) => (
            <DocTile
              key={`${title}-${item.label}-${item.url ?? "none"}`}
              label={item.label}
              url={item.url}
              note={item.note}
            />
          ))}
        </div>
      </CardContent>
    </Card>
  );
}

type QualificationDoc = Record<string, unknown>;

function qualTitle(q: QualificationDoc) {
  const degreeType = String(q.degreeType ?? "").trim();
  const degreeName = String(q.degreeName ?? "").trim();
  const passingYear = q.passingYear ? ` (${String(q.passingYear)})` : "";
  return `${degreeName || degreeType || "Qualification"}${passingYear}`;
}

function qualificationDocs(q: QualificationDoc): DocEntry[] {
  const items: DocEntry[] = [];
  if (typeof q.certificateUrl === "string" && q.certificateUrl) {
    items.push({
      label: `${qualTitle(q)} Certificate`,
      url: q.certificateUrl,
    });
  }
  for (let i = 1; i <= 8; i += 1) {
    const key = `sem${i}MarksheetUrl`;
    const value = q[key];
    if (typeof value === "string" && value) {
      items.push({
        label: `${qualTitle(q)} Marksheet`,
        url: value,
        note: `Semester ${i}`,
      });
    }
  }
  return items;
}

function stripHtml(html: string) {
  return html.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
}

const LETTER_PLACEHOLDERS = [
  "fullName",
  "employeeCode",
  "designation",
  "department",
  "organization",
  "instituteName",
  "subOrganization",
  "joiningDate",
  "birthDate",
  "aadhaarNo",
  "panNo",
  "passportNo",
  "passportIssueDate",
  "passportExpiryDate",
  "todayDate",
];

export function DocumentsTab({ profile, canManageLetters: canManageLettersProp }: DocumentsTabProps) {
  const { data: session } = useSession();
  const perms = (session?.user as { permissions?: Record<string, string[]> } | undefined)?.permissions;
  const role = (session?.user as { role?: string } | undefined)?.role;
  const employeeId = Number(profile?.id);
  const canManage =
    typeof canManageLettersProp === "boolean"
      ? canManageLettersProp
      : canManageLetters(perms, role);

  const personal = (profile?.personalInfo as Record<string, unknown> | undefined) ?? {};
  const other = (profile?.otherInfo as Record<string, unknown> | undefined) ?? {};
  const bank = (profile?.bankInfo as Record<string, unknown> | undefined) ?? {};
  const academicQuals = Array.isArray(profile?.academicQuals)
    ? (profile?.academicQuals as QualificationDoc[])
    : [];
  const { data: templates = [] } = useLetterTemplates();
  const { data: letterDocs = [] } = useEmployeeLetterDocuments(employeeId);
  const createDraft = useCreateLetterDraft();
  const createCustomDraft = useCreateCustomLetterDraft();
  const updateDraft = useUpdateLetterDraft();
  const finalizeDraft = useFinalizeLetterDraft();
  const deleteLetter = useDeleteLetterDocument();
  const [editorOpen, setEditorOpen] = useState(false);
  const [activeDraft, setActiveDraft] = useState<LetterDocument | null>(null);

  const identityMedia: DocEntry[] = [
    { label: "Profile Photo", url: profile?.photoUrl as string | undefined },
    { label: "Digital Signature", url: profile?.signatureUrl as string | undefined },
  ];

  const statutoryDocs: DocEntry[] = [
    { label: "Aadhaar Card", url: personal?.aadhaarCardUrl as string | undefined },
    { label: "PAN Card", url: personal?.panCardUrl as string | undefined },
    { label: "Passport Document", url: other?.passportUrl as string | undefined },
    { label: "Other Personal Document", url: personal?.otherDocumentUrl as string | undefined },
  ];

  const academicDocs = academicQuals.flatMap(qualificationDocs);

  const bankDocs: DocEntry[] = [
    { label: "Cancelled Cheque", url: bank?.cancelledChequeUrl as string | undefined },
    { label: "Passbook", url: bank?.passbookUrl as string | undefined },
  ];

  const finalLetters = useMemo(
    () => letterDocs.filter((doc) => doc.status === "FINAL"),
    [letterDocs],
  );
  // Drafts only matter for admins; backend already hides them from employees.
  const draftLetters = useMemo(
    () => (canManage ? letterDocs.filter((doc) => doc.status === "DRAFT") : []),
    [letterDocs, canManage],
  );

  const openDraftEditor = async (document: LetterDocument) => {
    setActiveDraft(document);
    setEditorOpen(true);
  };

  const handleGenerateTemplate = async (templateId: string) => {
    const draft = await createDraft.mutateAsync({ employeeId, templateId });
    setActiveDraft(draft);
    setEditorOpen(true);
  };

  const handleCreateCustom = async () => {
    const title = window.prompt("Letter title (e.g. Experience Certificate, NOC, Warning Letter)", "Custom Letter");
    if (title === null) return;
    const draft = await createCustomDraft.mutateAsync({
      employeeId,
      title: title.trim() || "Custom Letter",
    });
    setActiveDraft(draft);
    setEditorOpen(true);
  };

  const handleDelete = async (doc: LetterDocument) => {
    const name = doc.template?.name ?? "this letter";
    if (!window.confirm(`Delete ${name}? This cannot be undone.`)) return;
    try {
      await deleteLetter.mutateAsync({ documentId: doc.id, employeeId });
    } catch {
      // toast already shown by mutation
    }
  };

  return (
    <div className="space-y-4">
      <Section title="Identity & Media" items={identityMedia} />
      <Section title="KYC & Passport" items={statutoryDocs} />
      <Section title="Academic Records" items={academicDocs.length ? academicDocs : [{ label: "Academic documents", note: "No marksheets or certificates uploaded yet." }]} />
      <Section title="Bank Documents" items={bankDocs} />

      <Card className="border-slate-200/60 shadow-sm">
        <CardContent className="pt-5 space-y-4">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h3 className="text-sm font-semibold text-slate-800">Letters</h3>
              <p className="mt-1 text-xs text-slate-500">
                {canManage
                  ? "Generate, edit drafts, then finalize. Employees only see letters after you generate the final version."
                  : "Your finalized letters (offer, LOR, exit, etc.)."}
              </p>
            </div>
            {canManage ? (
              <Button
                type="button"
                size="sm"
                onClick={handleCreateCustom}
                disabled={createCustomDraft.isPending}
                className="shrink-0"
              >
                <Plus className="mr-1 h-4 w-4" />
                New letter
              </Button>
            ) : null}
          </div>

          {canManage ? (
            <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 space-y-3">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Generate from template
              </p>
              <div className="flex flex-wrap gap-2">
                {templates.length ? (
                  templates.map((template) => (
                    <Button
                      key={template.id}
                      type="button"
                      variant="outline"
                      size="sm"
                      disabled={createDraft.isPending}
                      onClick={() => handleGenerateTemplate(template.id)}
                    >
                      {template.name}
                    </Button>
                  ))
                ) : (
                  <p className="text-xs text-slate-500">
                    No templates yet. Use <strong>+ New letter</strong> for a free-form letter, or add templates in Letters config.
                  </p>
                )}
              </div>
            </div>
          ) : null}

          {canManage && draftLetters.length ? (
            <div className="space-y-3">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Drafts (admin only — not visible to employee)
              </p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {draftLetters.map((doc) => (
                  <div key={doc.id} className="rounded-xl border border-amber-200 bg-amber-50/60 p-4">
                    <p className="text-xs font-semibold text-amber-800">
                      {doc.template?.name ?? "Letter Draft"}
                    </p>
                    <p className="mt-2 text-sm text-slate-600">
                      {stripHtml(doc.contentHtml).slice(0, 180) || "Draft ready for editing"}
                    </p>
                    <div className="mt-3 flex flex-wrap gap-2">
                      <Button type="button" size="sm" onClick={() => openDraftEditor(doc)}>
                        Edit & Generate
                      </Button>
                      <Button
                        type="button"
                        size="sm"
                        variant="outline"
                        className="text-rose-600"
                        disabled={deleteLetter.isPending}
                        onClick={() => handleDelete(doc)}
                      >
                        Delete
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : null}

          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            {finalLetters.length ? (
              finalLetters.map((doc) => {
                const title = doc.template?.name ?? "Generated Letter";
                return (
                  <div key={doc.id} className="rounded-xl border border-slate-200 bg-white p-4">
                    <p className="text-xs font-semibold text-slate-500">{title}</p>
                    <p className="mt-2 text-sm text-slate-700">
                      {stripHtml(doc.contentHtml).slice(0, 200) || "Generated letter"}
                    </p>
                    <div className="mt-3 rounded-lg border border-slate-100 bg-slate-50 p-3">
                      <div
                        className="prose prose-sm max-w-none line-clamp-6"
                        dangerouslySetInnerHTML={{ __html: doc.contentHtml }}
                      />
                    </div>
                    <div className="mt-3 flex flex-wrap gap-2">
                      <Button
                        type="button"
                        size="sm"
                        variant="outline"
                        onClick={() => downloadLetterPdf(title, doc.contentHtml)}
                      >
                        Download PDF
                      </Button>
                      {canManage ? (
                        <Button
                          type="button"
                          size="sm"
                          variant="outline"
                          className="text-rose-600"
                          disabled={deleteLetter.isPending}
                          onClick={() => handleDelete(doc)}
                        >
                          Delete
                        </Button>
                      ) : null}
                    </div>
                  </div>
                );
              })
            ) : (
              <DocTile
                label="Letters"
                note={
                  canManage
                    ? "No finalized letters yet. Generate a draft, then click Generate Final."
                    : "No letters available yet. They appear here after HR finalizes them."
                }
              />
            )}
          </div>
        </CardContent>
      </Card>

      <LetterEditorDialog
        key={activeDraft?.id ?? "no-draft"}
        open={editorOpen}
        onOpenChange={(open) => {
          setEditorOpen(open);
          if (!open) setActiveDraft(null);
        }}
        title={activeDraft?.template?.name ? `Edit Draft — ${activeDraft.template.name}` : "Edit Draft"}
        description="Write in simple English. Preview on the right. Generate Final stores it for the employee."
        initialHtml={activeDraft?.contentHtml ?? ""}
        placeholders={
          Array.isArray(activeDraft?.template?.placeholders) && activeDraft?.template?.placeholders?.length
            ? (activeDraft.template.placeholders as string[])
            : LETTER_PLACEHOLDERS
        }
        saving={updateDraft.isPending || finalizeDraft.isPending}
        onSaveGenerate={async (html) => {
          if (!activeDraft) return;
          await updateDraft.mutateAsync({
            documentId: activeDraft.id,
            contentHtml: html,
            employeeId,
          });
          await finalizeDraft.mutateAsync({ draftId: activeDraft.id, employeeId });
          setEditorOpen(false);
          setActiveDraft(null);
        }}
      />
    </div>
  );
}
