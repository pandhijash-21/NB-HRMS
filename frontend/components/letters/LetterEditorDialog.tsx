"use client";

import { useMemo, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";

type LetterEditorDialogProps = {
  open: boolean;
  title: string;
  description?: string;
  initialHtml: string;
  placeholders?: string[];
  saving?: boolean;
  onOpenChange: (open: boolean) => void;
  onSaveGenerate: (html: string) => Promise<void> | void;
};

function escapeHtml(s: string) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

/** Convert stored HTML into plain English for editing. */
export function htmlToPlainText(html: string) {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|div|h[1-6]|li|tr)>/gi, "\n")
    .replace(/<li[^>]*>/gi, "• ")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/** Convert plain English back into simple HTML for storage / preview. */
export function plainTextToHtml(text: string) {
  const paragraphs = text
    .replace(/\r\n/g, "\n")
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .filter(Boolean);

  if (!paragraphs.length) {
    return "<div></div>";
  }

  return `<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.6;color:#111;">${paragraphs
    .map((block) => {
      const withBreaks = escapeHtml(block).replace(/\n/g, "<br/>");
      return `<p style="margin:0 0 12px;">${withBreaks}</p>`;
    })
    .join("")}</div>`;
}

export function LetterEditorDialog({
  open,
  title,
  description,
  initialHtml,
  placeholders = [],
  saving = false,
  onOpenChange,
  onSaveGenerate,
}: LetterEditorDialogProps) {
  const [plainText, setPlainText] = useState(() => htmlToPlainText(initialHtml));

  const previewHtml = useMemo(() => plainTextToHtml(plainText), [plainText]);

  const normalizedPlaceholders = useMemo(
    () => Array.from(new Set(placeholders.filter(Boolean))),
    [placeholders],
  );

  const insertAtCursor = (token: string) => {
    const el = document.activeElement as HTMLTextAreaElement | null;
    if (!el || el.tagName !== "TEXTAREA") {
      setPlainText((prev) => `${prev}${token}`);
      return;
    }
    const start = el.selectionStart ?? plainText.length;
    const end = el.selectionEnd ?? plainText.length;
    const next = `${plainText.slice(0, start)}${token}${plainText.slice(end)}`;
    setPlainText(next);
    queueMicrotask(() => {
      el.focus();
      const cursor = start + token.length;
      el.setSelectionRange(cursor, cursor);
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[min(96vw,72rem)] max-h-[92vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          {description ? (
            <DialogDescription>{description}</DialogDescription>
          ) : (
            <DialogDescription>
              Edit in simple English. Preview updates live. Generate saves the final letter for the employee.
            </DialogDescription>
          )}
        </DialogHeader>

        <div className="space-y-4">
          {normalizedPlaceholders.length ? (
            <div className="space-y-2">
              <p className="text-xs font-semibold text-slate-500">Insert placeholders (optional)</p>
              <div className="flex flex-wrap gap-2">
                {normalizedPlaceholders.map((key) => (
                  <button
                    key={key}
                    type="button"
                    onClick={() => insertAtCursor(`{{${key}}}`)}
                    className="rounded-full border border-slate-200 bg-slate-50 px-3 py-1 text-xs font-semibold text-[#1d3459] hover:bg-slate-100"
                  >
                    {`{{${key}}}`}
                  </button>
                ))}
              </div>
            </div>
          ) : null}

          <div className="grid gap-4 lg:grid-cols-2">
            <div className="space-y-2">
              <p className="text-xs font-semibold text-slate-500">Edit (simple English)</p>
              <Textarea
                value={plainText}
                onChange={(e) => setPlainText(e.target.value)}
                className="min-h-[26rem] text-sm leading-relaxed"
                placeholder="Type the letter in plain English..."
              />
            </div>
            <div className="space-y-2">
              <div className="flex items-center justify-between gap-2">
                <p className="text-xs font-semibold text-slate-500">Live Preview</p>
                <Badge variant="outline" className="text-[10px]">
                  How the letter will look
                </Badge>
              </div>
              <div className="min-h-[26rem] rounded-xl border border-slate-200 bg-white p-6 shadow-sm overflow-auto">
                <div
                  className="prose prose-sm max-w-none"
                  dangerouslySetInnerHTML={{ __html: previewHtml }}
                />
              </div>
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            type="button"
            onClick={() => onSaveGenerate(previewHtml)}
            disabled={saving || !plainText.trim()}
          >
            {saving ? "Saving..." : "Generate Final"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
