"use client";

import { useMemo, useRef, useState, useCallback } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useLetterTemplates, useUpsertLetterTemplate, type LetterTemplate } from "@/lib/hooks/useLetters";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const PLACEHOLDERS = [
  "fullName", "employeeCode", "designation", "department",
  "organization", "instituteName", "subOrganization",
  "joiningDate", "birthDate", "aadhaarNo", "panNo",
  "passportNo", "passportIssueDate", "passportExpiryDate", "todayDate",
];

const FONT_FAMILIES = ["Arial", "Times New Roman", "Georgia", "Courier New", "Verdana"];
const FONT_SIZES = [10, 12, 14, 16, 18, 20, 24, 28, 32];

const PAPER_SIZES: Record<string, { width: number; height: number }> = {
  A4: { width: 595, height: 842 },
  A3: { width: 842, height: 1191 },
  A2: { width: 1191, height: 1684 },
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type ElementType = "text" | "image";

interface CanvasElement {
  id: string;
  type: ElementType;
  x: number;
  y: number;
  width: number;
  height: number;
  // text fields
  text?: string;
  fontFamily?: string;
  fontSize?: number;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  align?: "left" | "center" | "right";
  // image fields
  imageUrl?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function stripHtml(html: string) {
  return html.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
}

function escapeHtml(s: string) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function elementsToHtml(elements: CanvasElement[], paperSize: string) {
  const { width, height } = PAPER_SIZES[paperSize] ?? PAPER_SIZES.A4;
  const parts: string[] = [
    `<div style="position:relative;width:${width}px;height:${height}px;background:#fff;">`,
  ];
  for (const el of elements) {
    if (el.type === "image" && el.imageUrl) {
      parts.push(
        `<img src="${el.imageUrl}" style="position:absolute;left:${el.x}px;top:${el.y}px;width:${el.width}px;height:${el.height}px;object-fit:contain;" />`
      );
    } else if (el.type === "text" && el.text) {
      const safe = escapeHtml(el.text).replace(/\n/g, "<br/>");
      parts.push(
        `<div style="position:absolute;left:${el.x}px;top:${el.y}px;width:${el.width}px;font-family:${el.fontFamily ?? "Arial"};font-size:${el.fontSize ?? 14}px;font-weight:${el.bold ? 700 : 400};font-style:${el.italic ? "italic" : "normal"};text-decoration:${el.underline ? "underline" : "none"};text-align:${el.align ?? "left"};white-space:pre-wrap;">${safe}</div>`
      );
    }
  }
  parts.push("</div>");
  return parts.join("");
}

function extractPlaceholders(html: string) {
  const matches = Array.from(html.matchAll(/{{\s*([a-zA-Z0-9_]+)\s*}}/g));
  return Array.from(new Set(matches.map((m) => m[1]).filter(Boolean)));
}

function uid() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
}

// ---------------------------------------------------------------------------
// TextEditDialog
// ---------------------------------------------------------------------------

interface TextEditDialogProps {
  element: CanvasElement | null;
  onClose: () => void;
  onApply: (updated: Partial<CanvasElement>) => void;
}

function TextEditDialog({ element, onClose, onApply }: TextEditDialogProps) {
  const [text, setText] = useState(element?.text ?? "");
  const [fontFamily, setFontFamily] = useState(element?.fontFamily ?? "Arial");
  const [fontSize, setFontSize] = useState<number>(element?.fontSize ?? 14);
  const [bold, setBold] = useState(element?.bold ?? false);
  const [italic, setItalic] = useState(element?.italic ?? false);
  const [underline, setUnderline] = useState(element?.underline ?? false);
  const [align, setAlign] = useState<"left" | "center" | "right">(element?.align ?? "left");
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const insertPlaceholder = (p: string) => {
    const ta = textareaRef.current;
    if (!ta) { setText((v) => `${v}{{${p}}}`); return; }
    const start = ta.selectionStart;
    const end = ta.selectionEnd;
    const token = `{{${p}}}`;
    setText((v) => v.slice(0, start) + token + v.slice(end));
    setTimeout(() => ta.setSelectionRange(start + token.length, start + token.length), 0);
  };

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Edit text block</DialogTitle>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="flex flex-wrap gap-1.5">
            {PLACEHOLDERS.map((p) => (
              <button
                key={p}
                type="button"
                onClick={() => insertPlaceholder(p)}
                className="rounded-full border border-slate-200 bg-slate-50 px-2.5 py-0.5 text-[11px] font-semibold text-blue-700 hover:bg-blue-50"
              >
                {`{{${p}}}`}
              </button>
            ))}
          </div>
          <Textarea
            ref={textareaRef}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Type your text here. Use the chips above to insert placeholders like {{fullName}}."
            className="min-h-[160px]"
          />
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label>Font</Label>
              <Select value={fontFamily} onValueChange={setFontFamily}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {FONT_FAMILIES.map((f) => (
                    <SelectItem key={f} value={f}>{f}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Font size</Label>
              <Select value={String(fontSize)} onValueChange={(v) => setFontSize(Number(v))}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {FONT_SIZES.map((s) => (
                    <SelectItem key={s} value={String(s)}>{s}px</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            {(["Bold", "Italic", "Underline"] as const).map((style) => {
              const active =
                style === "Bold" ? bold : style === "Italic" ? italic : underline;
              const toggle = () => {
                if (style === "Bold") setBold((v) => !v);
                else if (style === "Italic") setItalic((v) => !v);
                else setUnderline((v) => !v);
              };
              return (
                <button
                  key={style}
                  type="button"
                  onClick={toggle}
                  className={`rounded border px-3 py-1 text-sm font-semibold transition ${active ? "border-blue-600 bg-blue-600 text-white" : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"}`}
                >
                  {style}
                </button>
              );
            })}
            <span className="mx-2 text-slate-300">|</span>
            {(["left", "center", "right"] as const).map((a) => (
              <button
                key={a}
                type="button"
                onClick={() => setAlign(a)}
                className={`rounded border px-3 py-1 text-sm capitalize transition ${align === a ? "border-blue-600 bg-blue-600 text-white" : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"}`}
              >
                {a}
              </button>
            ))}
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button onClick={() => onApply({ text, fontFamily, fontSize, bold, italic, underline, align })}>
            Apply
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ---------------------------------------------------------------------------
// Canvas
// ---------------------------------------------------------------------------

interface LetterCanvasProps {
  elements: CanvasElement[];
  paperSize: string;
  activeId: string | null;
  onSelect: (id: string) => void;
  onMove: (id: string, dx: number, dy: number) => void;
  onResize: (id: string, dw: number, dh: number) => void;
  onDoubleClick: (id: string) => void;
}

function LetterCanvas({ elements, paperSize, activeId, onSelect, onMove, onResize, onDoubleClick }: LetterCanvasProps) {
  const { width, height } = PAPER_SIZES[paperSize] ?? PAPER_SIZES.A4;
  const dragState = useRef<{ id: string; startX: number; startY: number } | null>(null);
  const resizeState = useRef<{ id: string; startX: number; startY: number } | null>(null);

  const handleMouseDown = (e: React.MouseEvent, id: string) => {
    if ((e.target as HTMLElement).dataset.resizeHandle === "true") return;
    e.stopPropagation();
    onSelect(id);
    dragState.current = { id, startX: e.clientX, startY: e.clientY };
    const onMove2 = (ev: MouseEvent) => {
      if (!dragState.current) return;
      onMove(dragState.current.id, ev.clientX - dragState.current.startX, ev.clientY - dragState.current.startY);
      dragState.current = { id: dragState.current.id, startX: ev.clientX, startY: ev.clientY };
    };
    const onUp = () => {
      dragState.current = null;
      window.removeEventListener("mousemove", onMove2);
      window.removeEventListener("mouseup", onUp);
    };
    window.addEventListener("mousemove", onMove2);
    window.addEventListener("mouseup", onUp);
  };

  const handleResizeMouseDown = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    onSelect(id);
    resizeState.current = { id, startX: e.clientX, startY: e.clientY };
    const onMove2 = (ev: MouseEvent) => {
      if (!resizeState.current) return;
      onResize(
        resizeState.current.id,
        ev.clientX - resizeState.current.startX,
        ev.clientY - resizeState.current.startY
      );
      resizeState.current = { id: resizeState.current.id, startX: ev.clientX, startY: ev.clientY };
    };
    const onUp = () => {
      resizeState.current = null;
      window.removeEventListener("mousemove", onMove2);
      window.removeEventListener("mouseup", onUp);
    };
    window.addEventListener("mousemove", onMove2);
    window.addEventListener("mouseup", onUp);
  };

  return (
    <div
      className="relative overflow-hidden rounded-lg border border-slate-200 bg-white shadow"
      style={{ width, height, minWidth: width, flexShrink: 0 }}
      onClick={() => onSelect("")}
    >
      {elements.map((el) => {
        const isActive = el.id === activeId;
        return (
          <div
            key={el.id}
            className={`absolute select-none rounded ${isActive ? "ring-2 ring-blue-500" : "ring-1 ring-transparent hover:ring-slate-300"}`}
            style={{ left: el.x, top: el.y, width: el.width, height: el.height, cursor: "move" }}
            onMouseDown={(e) => handleMouseDown(e, el.id)}
            onDoubleClick={(e) => { e.stopPropagation(); onDoubleClick(el.id); }}
          >
            {el.type === "image" && el.imageUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={el.imageUrl} alt="logo" className="pointer-events-none h-full w-full object-contain" />
            ) : (
              <div
                style={{
                  fontFamily: el.fontFamily ?? "Arial",
                  fontSize: el.fontSize ?? 14,
                  fontWeight: el.bold ? 700 : 400,
                  fontStyle: el.italic ? "italic" : "normal",
                  textDecoration: el.underline ? "underline" : "none",
                  textAlign: el.align ?? "left",
                  whiteSpace: "pre-wrap",
                  lineHeight: 1.4,
                }}
                className="pointer-events-none h-full w-full overflow-hidden p-1"
              >
                {el.text}
              </div>
            )}
            {isActive && (
              <div
                data-resize-handle="true"
                className="absolute -bottom-1.5 -right-1.5 h-4 w-4 cursor-se-resize rounded-sm border-2 border-white bg-blue-600"
                onMouseDown={(e) => handleResizeMouseDown(e, el.id)}
              />
            )}
          </div>
        );
      })}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main Page
// ---------------------------------------------------------------------------

export default function AdminLettersPage() {
  const { data: templates = [], isLoading } = useLetterTemplates();
  const saveTemplate = useUpsertLetterTemplate();

  const [selected, setSelected] = useState<LetterTemplate | null>(null);
  const [templateKey, setTemplateKey] = useState("offer_letter");
  const [name, setName] = useState("Offer Letter");
  const [description, setDescription] = useState("");
  const [logoUrl, setLogoUrl] = useState("");
  const [paperSize, setPaperSize] = useState("A4");
  const [elements, setElements] = useState<CanvasElement[]>(() => [
    {
      id: uid(),
      type: "text",
      x: 60,
      y: 120,
      width: (PAPER_SIZES.A4.width - 120),
      height: 400,
      text: "Dear {{fullName}},\n\nWe are pleased to offer you the position of {{designation}} in {{department}}, {{organization}}.\n\nJoining date: {{joiningDate}}\n\nSincerely,\nHR Department\n{{todayDate}}",
      fontFamily: "Arial",
      fontSize: 14,
      bold: false,
      italic: false,
      underline: false,
      align: "left",
    },
  ]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [editingEl, setEditingEl] = useState<CanvasElement | null>(null);
  const [localLogoDataUrl, setLocalLogoDataUrl] = useState<string | null>(null);
  const [localLogoFileName, setLocalLogoFileName] = useState<string | null>(null);
  const logoFileInputRef = useRef<HTMLInputElement>(null);

  const activeElement = useMemo(
    () => elements.find((el) => el.id === activeId) ?? null,
    [elements, activeId]
  );

  const effectiveLogoUrl = localLogoDataUrl?.trim() || logoUrl.trim() || null;

  const templateHtml = useMemo(() => elementsToHtml(elements, paperSize), [elements, paperSize]);
  const activePlaceholders = useMemo(() => extractPlaceholders(templateHtml), [templateHtml]);

  const updateElement = (id: string, patch: Partial<CanvasElement>) => {
    setElements((prev) => prev.map((el) => (el.id === id ? { ...el, ...patch } : el)));
  };

  const handleMove = useCallback((id: string, dx: number, dy: number) => {
    setElements((prev) =>
      prev.map((el) => {
        if (el.id !== id) return el;
        const { width, height } = PAPER_SIZES[paperSize] ?? PAPER_SIZES.A4;
        return {
          ...el,
          x: Math.max(0, Math.min(el.x + dx, width - el.width)),
          y: Math.max(0, Math.min(el.y + dy, height - el.height)),
        };
      })
    );
  }, [paperSize]);

  const handleResize = useCallback((id: string, dw: number, dh: number) => {
    setElements((prev) =>
      prev.map((el) => {
        if (el.id !== id) return el;
        const { width, height } = PAPER_SIZES[paperSize] ?? PAPER_SIZES.A4;
        const minW = el.type === "image" ? 40 : 80;
        const minH = el.type === "image" ? 24 : 32;
        const maxW = width - el.x;
        const maxH = height - el.y;
        return {
          ...el,
          width: Math.max(minW, Math.min(el.width + dw, maxW)),
          height: Math.max(minH, Math.min(el.height + dh, maxH)),
        };
      })
    );
  }, [paperSize]);

  const nudgeActive = (dx: number, dy: number) => {
    if (!activeId) return;
    handleMove(activeId, dx, dy);
  };

  const deleteActive = () => {
    if (!activeId) return;
    setElements((prev) => prev.filter((el) => el.id !== activeId));
    if (activeId === "logo") {
      setLocalLogoDataUrl(null);
      setLocalLogoFileName(null);
      setLogoUrl("");
    }
    setActiveId(null);
  };

  const placeLogoOnCanvas = (url: string) => {
    setElements((prev) => {
      const existing = prev.find((e) => e.id === "logo");
      if (existing) {
        return prev.map((e) => (e.id === "logo" ? { ...e, imageUrl: url } : e));
      }
      return [
        { id: "logo", type: "image", x: 60, y: 20, width: 200, height: 72, imageUrl: url },
        ...prev,
      ];
    });
    setActiveId("logo");
  };

  const handleLogoFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = typeof reader.result === "string" ? reader.result : null;
      if (!dataUrl) return;
      setLocalLogoDataUrl(dataUrl);
      setLocalLogoFileName(file.name);
      setLogoUrl("");
      placeLogoOnCanvas(dataUrl);
    };
    reader.readAsDataURL(file);
    e.target.value = "";
  };

  const loadTemplate = (tpl: LetterTemplate) => {
    setSelected(tpl);
    setTemplateKey(tpl.key);
    setName(tpl.name);
    setDescription(tpl.description ?? "");
    setLogoUrl(tpl.logoUrl ?? "");
    setLocalLogoDataUrl(tpl.logoUrl?.startsWith("data:") ? tpl.logoUrl : null);
    setLocalLogoFileName(tpl.logoUrl?.startsWith("data:") ? "Uploaded logo" : null);
    // Convert stored template back to a single canvas text block.
    const bodyText = stripHtml(tpl.templateHtml);
    const ps = "A4";
    setPaperSize(ps);
    const newElements: CanvasElement[] = [];
    if (tpl.logoUrl) {
      newElements.push({
        id: "logo",
        type: "image",
        x: 60,
        y: 20,
        width: 200,
        height: 72,
        imageUrl: tpl.logoUrl,
      });
    }
    newElements.push({
      id: uid(),
      type: "text",
      x: 60,
      y: 120,
      width: PAPER_SIZES[ps].width - 120,
      height: 400,
      text: bodyText,
      fontFamily: "Arial",
      fontSize: 14,
    });
    setElements(newElements);
    setActiveId(null);
  };

  const resetForm = () => {
    setSelected(null);
    setTemplateKey("");
    setName("");
    setDescription("");
    setLogoUrl("");
    setLocalLogoDataUrl(null);
    setLocalLogoFileName(null);
    setPaperSize("A4");
    setElements([
      {
        id: uid(),
        type: "text",
        x: 60,
        y: 120,
        width: PAPER_SIZES.A4.width - 120,
        height: 400,
        text: "Dear {{fullName}},\n\nType your letter here...",
        fontFamily: "Arial",
        fontSize: 14,
      },
    ]);
    setActiveId(null);
  };

  const addTextBlock = () => {
    const { width } = PAPER_SIZES[paperSize] ?? PAPER_SIZES.A4;
    const id = uid();
    const el: CanvasElement = {
      id,
      type: "text",
      x: 60,
      y: 120 + elements.length * 60,
      width: width - 120,
      height: 80,
      text: "New text block — double-click to edit",
      fontFamily: "Arial",
      fontSize: 14,
    };
    setElements((prev) => [...prev, el]);
    setActiveId(id);
    setEditingEl(el);
  };

  const addLogo = () => {
    if (!effectiveLogoUrl) {
      alert("Paste a Logo URL or upload a local image first.");
      return;
    }
    placeLogoOnCanvas(effectiveLogoUrl);
  };

  const handlePaperSizeChange = (ps: string) => {
    const { width } = PAPER_SIZES[ps] ?? PAPER_SIZES.A4;
    setPaperSize(ps);
    setElements((prev) =>
      prev.map((el) =>
        el.type === "text" ? { ...el, width: width - 120 } : el
      )
    );
  };

  const handleSave = () => {
    saveTemplate.mutate({
      id: selected?.id,
      key: templateKey.trim(),
      name: name.trim(),
      description: description.trim() || null,
      logoUrl: effectiveLogoUrl,
      templateHtml,
      placeholders: activePlaceholders,
    });
  };

  return (
    <div className="max-w-[1600px] mx-auto space-y-6 p-4 md:p-8">
      <div className="space-y-2">
        <Badge variant="outline" className="text-[10px] font-bold uppercase tracking-widest">
          Configurations
        </Badge>
        <h1 className="text-3xl font-extrabold tracking-tight text-slate-800">Letters</h1>
        <p className="text-sm text-slate-500">
          Design letter templates with a visual canvas editor. Drag logo &amp; text blocks, pick paper size, insert placeholders.
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-[20rem_minmax(0,1fr)]">
        {/* Template list */}
        <Card className="border-slate-200/60 shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <div>
              <CardTitle className="text-base">Templates</CardTitle>
              <CardDescription className="text-xs">Click to load or edit</CardDescription>
            </div>
            <Button type="button" size="sm" variant="outline" onClick={resetForm}>
              + New
            </Button>
          </CardHeader>
          <CardContent className="space-y-2">
            {isLoading ? (
              <p className="text-sm text-slate-500">Loading…</p>
            ) : templates.length === 0 ? (
              <p className="text-sm text-slate-500">No templates yet.</p>
            ) : (
              templates.map((tpl) => (
                <button
                  key={tpl.id}
                  type="button"
                  onClick={() => loadTemplate(tpl)}
                  className={`w-full rounded-xl border p-3 text-left transition ${
                    selected?.id === tpl.id
                      ? "border-blue-600 bg-blue-50"
                      : "border-slate-200 bg-white hover:bg-slate-50"
                  }`}
                >
                  <p className="text-sm font-bold text-slate-800">{tpl.name}</p>
                  <p className="mt-0.5 text-[11px] text-slate-500">{tpl.key}</p>
                </button>
              ))
            )}
          </CardContent>
        </Card>

        {/* Editor */}
        <div className="space-y-5">
          {/* Meta fields */}
          <Card className="border-slate-200/60 shadow-sm">
            <CardContent className="pt-5 space-y-4">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-1.5">
                  <Label>Template Key</Label>
                  <Input value={templateKey} onChange={(e) => setTemplateKey(e.target.value)} disabled={!!selected?.id} placeholder="offer_letter" />
                </div>
                <div className="space-y-1.5">
                  <Label>Template Name</Label>
                  <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Offer Letter" />
                </div>
              </div>
              <div className="space-y-1.5">
                <Label>Description (optional)</Label>
                <Input value={description} onChange={(e) => setDescription(e.target.value)} />
              </div>
              <div className="space-y-1.5">
                <Label>Logo URL (optional)</Label>
                <div className="flex flex-wrap gap-2">
                  <Input
                    value={logoUrl}
                    onChange={(e) => {
                      setLogoUrl(e.target.value);
                      setLocalLogoDataUrl(null);
                      setLocalLogoFileName(null);
                    }}
                    placeholder={localLogoFileName ?? "https://your-cdn.com/logo.png or upload local file"}
                  />
                  <input
                    ref={logoFileInputRef}
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={handleLogoFileChange}
                  />
                  <Button type="button" variant="outline" onClick={() => logoFileInputRef.current?.click()}>
                    Upload
                  </Button>
                  <Button type="button" variant="outline" onClick={addLogo}>
                    Add to canvas
                  </Button>
                </div>
                {localLogoFileName && (
                  <p className="text-xs text-emerald-600">Uploaded: {localLogoFileName}</p>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Canvas toolbar */}
          <Card className="border-slate-200/60 shadow-sm">
            <CardContent className="pt-5 space-y-4">
              <div className="flex flex-wrap items-center gap-3">
                <div className="flex items-center gap-2">
                  <Label className="shrink-0">Paper size</Label>
                  <Select value={paperSize} onValueChange={handlePaperSizeChange}>
                    <SelectTrigger className="w-24"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {Object.keys(PAPER_SIZES).map((s) => (
                        <SelectItem key={s} value={s}>{s}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <Button type="button" variant="outline" onClick={addTextBlock}>
                  + Add text block
                </Button>
                <p className="ml-auto text-xs text-slate-400">
                  Drag to move • corner handle to resize • double-click text to edit
                </p>
              </div>

              {activeId && (
                <div className="flex flex-wrap items-center gap-2 rounded-lg border border-slate-200 bg-slate-50 p-2">
                  <Button type="button" variant="outline" size="sm" className="text-red-600" onClick={deleteActive}>
                    Delete
                  </Button>
                  {activeElement?.type === "text" && (
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => activeElement && setEditingEl(activeElement)}
                    >
                      Edit text
                    </Button>
                  )}
                  <span className="text-xs text-slate-500">Move:</span>
                  <Button type="button" variant="outline" size="sm" onClick={() => nudgeActive(0, -10)}>↑</Button>
                  <Button type="button" variant="outline" size="sm" onClick={() => nudgeActive(0, 10)}>↓</Button>
                  <Button type="button" variant="outline" size="sm" onClick={() => nudgeActive(-10, 0)}>←</Button>
                  <Button type="button" variant="outline" size="sm" onClick={() => nudgeActive(10, 0)}>→</Button>
                </div>
              )}

              {/* Paper canvas */}
              <div className="overflow-auto rounded-xl bg-slate-100 p-6">
                <LetterCanvas
                  elements={elements}
                  paperSize={paperSize}
                  activeId={activeId}
                  onSelect={setActiveId}
                  onMove={handleMove}
                  onResize={handleResize}
                  onDoubleClick={(id) => {
                    const el = elements.find((e) => e.id === id);
                    if (el?.type === "text") setEditingEl(el);
                  }}
                />
              </div>

              {/* Active placeholders */}
              {activePlaceholders.length > 0 && (
                <div className="flex flex-wrap gap-1.5">
                  {activePlaceholders.map((p) => (
                    <Badge key={p} variant="outline" className="text-xs">{p}</Badge>
                  ))}
                </div>
              )}

              <div className="flex justify-end">
                <Button
                  type="button"
                  disabled={saveTemplate.isPending || !templateKey.trim() || !name.trim()}
                  onClick={handleSave}
                >
                  {saveTemplate.isPending ? "Saving…" : "Save Template"}
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Text edit dialog */}
      {editingEl && (
        <TextEditDialog
          element={editingEl}
          onClose={() => setEditingEl(null)}
          onApply={(patch) => {
            updateElement(editingEl.id, patch);
            setEditingEl(null);
          }}
        />
      )}
    </div>
  );
}
