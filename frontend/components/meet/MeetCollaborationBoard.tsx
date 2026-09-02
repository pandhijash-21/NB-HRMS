"use client";

import React, { useEffect, useRef, useState, useCallback } from "react";
import {
  Pencil,
  Highlighter,
  Eraser,
  Square,
  Circle as CircleIcon,
  Minus,
  Type,
  Trash2,
  Undo,
  Download,
  X,
  Maximize2,
  Minimize2,
  StickyNote,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { getCollabSocket } from "@/lib/socket";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

export type BoardTool = "pen" | "highlighter" | "eraser" | "rectangle" | "circle" | "line" | "text" | "note";

export interface BoardStroke {
  id: string;
  tool: BoardTool;
  color: string;
  size: number;
  points?: Array<{ x: number; y: number }>;
  startX?: number;
  startY?: number;
  endX?: number;
  endY?: number;
  text?: string;
  senderName?: string;
}

const BOARD_COLORS = [
  "#FFFFFF", // White
  "#FBBF24", // Amber / Gold
  "#34D399", // Emerald
  "#38BDF8", // Sky Blue
  "#F87171", // Rose / Red
  "#A855F7", // Purple
  "#FB923C", // Orange
  "#64748B", // Slate
];

const STROKE_SIZES = [
  { label: "S", size: 2 },
  { label: "M", size: 4 },
  { label: "L", size: 8 },
  { label: "XL", size: 14 },
];

interface MeetCollaborationBoardProps {
  meetingId: string;
  currentUserName: string;
  onClose: () => void;
  guestToken?: string;
  isOverlay?: boolean;
}

export function MeetCollaborationBoard({
  meetingId,
  currentUserName,
  onClose,
  guestToken,
  isOverlay = false,
}: MeetCollaborationBoardProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const [tool, setTool] = useState<BoardTool>("pen");
  const [color, setColor] = useState<string>("#FBBF24");
  const [strokeSize, setStrokeSize] = useState<number>(4);
  const [isDrawing, setIsDrawing] = useState<boolean>(false);
  const [strokes, setStrokes] = useState<BoardStroke[]>([]);
  const [isMaximized, setIsMaximized] = useState<boolean>(false);
  const [textInput, setTextInput] = useState<{ x: number; y: number; value: string; isNote: boolean } | null>(null);

  const currentStrokeRef = useRef<BoardStroke | null>(null);

  // Redraw entire canvas from strokes list
  const redrawCanvas = useCallback((strokeList: BoardStroke[]) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    for (const stroke of strokeList) {
      drawSingleStroke(ctx, stroke);
    }
  }, []);

  function drawSingleStroke(ctx: CanvasRenderingContext2D, stroke: BoardStroke) {
    ctx.save();
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    if (stroke.tool === "eraser") {
      ctx.globalCompositeOperation = "destination-out";
      ctx.lineWidth = stroke.size * 3;
    } else if (stroke.tool === "highlighter") {
      ctx.globalCompositeOperation = "source-over";
      ctx.globalAlpha = 0.35;
      ctx.strokeStyle = stroke.color;
      ctx.lineWidth = stroke.size * 2.5;
    } else {
      ctx.globalCompositeOperation = "source-over";
      ctx.strokeStyle = stroke.color;
      ctx.fillStyle = stroke.color;
      ctx.lineWidth = stroke.size;
    }

    if ((stroke.tool === "pen" || stroke.tool === "highlighter" || stroke.tool === "eraser") && stroke.points && stroke.points.length > 0) {
      ctx.beginPath();
      ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
      for (let i = 1; i < stroke.points.length; i++) {
        ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
      }
      ctx.stroke();
    } else if (stroke.tool === "line" && stroke.startX !== undefined && stroke.startY !== undefined && stroke.endX !== undefined && stroke.endY !== undefined) {
      ctx.beginPath();
      ctx.moveTo(stroke.startX, stroke.startY);
      ctx.lineTo(stroke.endX, stroke.endY);
      ctx.stroke();
    } else if (stroke.tool === "rectangle" && stroke.startX !== undefined && stroke.startY !== undefined && stroke.endX !== undefined && stroke.endY !== undefined) {
      const x = Math.min(stroke.startX, stroke.endX);
      const y = Math.min(stroke.startY, stroke.endY);
      const w = Math.abs(stroke.endX - stroke.startX);
      const h = Math.abs(stroke.endY - stroke.startY);
      ctx.beginPath();
      ctx.strokeRect(x, y, w, h);
    } else if (stroke.tool === "circle" && stroke.startX !== undefined && stroke.startY !== undefined && stroke.endX !== undefined && stroke.endY !== undefined) {
      const radiusX = Math.abs(stroke.endX - stroke.startX) / 2;
      const radiusY = Math.abs(stroke.endY - stroke.startY) / 2;
      const centerX = Math.min(stroke.startX, stroke.endX) + radiusX;
      const centerY = Math.min(stroke.startY, stroke.endY) + radiusY;
      ctx.beginPath();
      ctx.ellipse(centerX, centerY, radiusX, radiusY, 0, 0, Math.PI * 2);
      ctx.stroke();
    } else if (stroke.tool === "text" && stroke.text && stroke.startX !== undefined && stroke.startY !== undefined) {
      ctx.font = `${Math.max(14, stroke.size * 3.5)}px sans-serif`;
      ctx.fillText(stroke.text, stroke.startX, stroke.startY);
    } else if (stroke.tool === "note" && stroke.text && stroke.startX !== undefined && stroke.startY !== undefined) {
      const boxW = 160;
      const boxH = 90;
      ctx.fillStyle = stroke.color;
      ctx.fillRect(stroke.startX, stroke.startY, boxW, boxH);
      ctx.fillStyle = "#1E293B";
      ctx.font = "bold 13px sans-serif";
      const lines = stroke.text.split("\n");
      lines.forEach((line, idx) => {
        ctx.fillText(line.slice(0, 20), stroke.startX! + 8, stroke.startY! + 22 + idx * 18);
      });
    }

    ctx.restore();
  }

  // Handle Resize and maintain resolution
  useEffect(() => {
    const handleResize = () => {
      const container = containerRef.current;
      const canvas = canvasRef.current;
      if (!container || !canvas) return;

      const rect = container.getBoundingClientRect();
      if (canvas.width !== rect.width || canvas.height !== rect.height) {
        canvas.width = rect.width;
        canvas.height = rect.height;
        redrawCanvas(strokes);
      }
    };

    handleResize();
    const ro = new ResizeObserver(handleResize);
    if (containerRef.current) ro.observe(containerRef.current);
    return () => ro.disconnect();
  }, [redrawCanvas, strokes]);

  // Socket sync setup
  useEffect(() => {
    let active = true;

    async function initSocket() {
      const socket = await getCollabSocket(guestToken);
      if (!active) return;

      socket.emit("meeting_board_get_history", { meetingId });

      socket.on("meeting_board_history", (payload: { meetingId: string; strokes: BoardStroke[] }) => {
        if (!active || payload.meetingId !== meetingId) return;
        setStrokes(payload.strokes || []);
        redrawCanvas(payload.strokes || []);
      });

      socket.on("meeting_board_draw", (payload: { meetingId: string; stroke: BoardStroke; sender?: { name: string } }) => {
        if (!active || payload.meetingId !== meetingId) return;
        setStrokes((prev) => {
          const next = [...prev, payload.stroke];
          redrawCanvas(next);
          return next;
        });
      });

      socket.on("meeting_board_clear", (payload: { meetingId: string; sender?: { name: string } }) => {
        if (!active || payload.meetingId !== meetingId) return;
        setStrokes([]);
        const canvas = canvasRef.current;
        if (canvas) {
          const ctx = canvas.getContext("2d");
          ctx?.clearRect(0, 0, canvas.width, canvas.height);
        }
        if (payload.sender?.name) {
          toast.info(`${payload.sender.name} cleared the whiteboard`);
        }
      });
    }

    void initSocket();

    return () => {
      active = false;
      void getCollabSocket(guestToken).then((sock: { off: (event: string) => void }) => {
        sock.off("meeting_board_history");
        sock.off("meeting_board_draw");
        sock.off("meeting_board_clear");
      });
    };
  }, [meetingId, guestToken, redrawCanvas]);

  function getCanvasCoordinates(e: React.MouseEvent<HTMLCanvasElement> | React.TouchEvent<HTMLCanvasElement>) {
    const canvas = canvasRef.current;
    if (!canvas) return { x: 0, y: 0 };
    const rect = canvas.getBoundingClientRect();
    if ("touches" in e && e.touches.length > 0) {
      return {
        x: e.touches[0].clientX - rect.left,
        y: e.touches[0].clientY - rect.top,
      };
    }
    const mouse = e as React.MouseEvent<HTMLCanvasElement>;
    return {
      x: mouse.clientX - rect.left,
      y: mouse.clientY - rect.top,
    };
  }

  function startDrawing(e: React.MouseEvent<HTMLCanvasElement> | React.TouchEvent<HTMLCanvasElement>) {
    const coords = getCanvasCoordinates(e);

    if (tool === "text" || tool === "note") {
      setTextInput({
        x: coords.x,
        y: coords.y,
        value: "",
        isNote: tool === "note",
      });
      return;
    }

    setIsDrawing(true);
    const newStroke: BoardStroke = {
      id: `${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
      tool,
      color: tool === "eraser" ? "#000000" : color,
      size: strokeSize,
      startX: coords.x,
      startY: coords.y,
      endX: coords.x,
      endY: coords.y,
      points: [coords],
      senderName: currentUserName,
    };

    currentStrokeRef.current = newStroke;
  }

  function draw(e: React.MouseEvent<HTMLCanvasElement> | React.TouchEvent<HTMLCanvasElement>) {
    if (!isDrawing || !currentStrokeRef.current) return;
    const coords = getCanvasCoordinates(e);
    const current = currentStrokeRef.current;

    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!ctx) return;

    if (tool === "pen" || tool === "highlighter" || tool === "eraser") {
      current.points?.push(coords);
      // Fast incremental draw
      drawSingleStroke(ctx, {
        ...current,
        points: [current.points![current.points!.length - 2], coords],
      });
    } else {
      // Shape tools: redraw full canvas + preview current stroke
      current.endX = coords.x;
      current.endY = coords.y;
      redrawCanvas(strokes);
      drawSingleStroke(ctx, current);
    }
  }

  async function stopDrawing() {
    if (!isDrawing || !currentStrokeRef.current) {
      setIsDrawing(false);
      return;
    }
    setIsDrawing(false);
    const stroke = currentStrokeRef.current;
    currentStrokeRef.current = null;

    setStrokes((prev) => [...prev, stroke]);

    // Broadcast stroke
    try {
      const sock = await getCollabSocket(guestToken);
      sock.emit("meeting_board_draw", { meetingId, stroke });
    } catch {
      /* ignore */
    }
  }

  async function handleAddTextOrNote() {
    if (!textInput || !textInput.value.trim()) {
      setTextInput(null);
      return;
    }

    const stroke: BoardStroke = {
      id: `${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
      tool: textInput.isNote ? "note" : "text",
      color: textInput.isNote ? color : color,
      size: strokeSize,
      startX: textInput.x,
      startY: textInput.y,
      text: textInput.value.trim(),
      senderName: currentUserName,
    };

    setTextInput(null);
    setStrokes((prev) => {
      const next = [...prev, stroke];
      redrawCanvas(next);
      return next;
    });

    try {
      const sock = await getCollabSocket(guestToken);
      sock.emit("meeting_board_draw", { meetingId, stroke });
    } catch {
      /* ignore */
    }
  }

  async function handleClear() {
    if (!window.confirm("Clear the entire whiteboard for everyone in the call?")) return;
    setStrokes([]);
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext("2d");
      ctx?.clearRect(0, 0, canvas.width, canvas.height);
    }
    try {
      const sock = await getCollabSocket(guestToken);
      sock.emit("meeting_board_clear", { meetingId });
    } catch {
      /* ignore */
    }
  }

  function handleUndo() {
    setStrokes((prev) => {
      if (prev.length === 0) return prev;
      const next = prev.slice(0, -1);
      redrawCanvas(next);
      return next;
    });
  }

  function handleExport() {
    const canvas = canvasRef.current;
    if (!canvas) return;

    // Create temp canvas with dark background
    const exportCanvas = document.createElement("canvas");
    exportCanvas.width = canvas.width;
    exportCanvas.height = canvas.height;
    const ctx = exportCanvas.getContext("2d");
    if (!ctx) return;

    ctx.fillStyle = "#0F172A";
    ctx.fillRect(0, 0, exportCanvas.width, exportCanvas.height);
    ctx.drawImage(canvas, 0, 0);

    const link = document.createElement("a");
    link.download = `whiteboard-${meetingId}-${Date.now()}.png`;
    link.href = exportCanvas.toDataURL("image/png");
    link.click();
    toast.success("Whiteboard image saved");
  }

  return (
    <div
      className={cn(
        "flex flex-col rounded-2xl bg-slate-900/95 border border-white/10 shadow-2xl backdrop-blur overflow-hidden transition-all duration-300",
        isMaximized
          ? "fixed inset-3 z-50"
          : isOverlay
          ? "w-full h-full"
          : "h-full w-full min-h-[360px]",
      )}
    >
      {/* Top Header Controls */}
      <div className="flex items-center justify-between px-3 py-2 border-b border-white/10 bg-slate-800/80 shrink-0 gap-2">
        <div className="flex items-center gap-2">
          <div className="flex size-7 items-center justify-center rounded-lg bg-amber-400 text-slate-900 font-extrabold text-xs">
            🎨
          </div>
          <div>
            <h3 className="text-xs sm:text-sm font-bold text-white flex items-center gap-1.5">
              Teams Collaboration Board
              <span className="hidden sm:inline text-[10px] bg-amber-400/20 text-amber-300 px-1.5 py-0.5 rounded font-medium">
                Live
              </span>
            </h3>
          </div>
        </div>

        <div className="flex items-center gap-1">
          <Button
            size="icon"
            variant="ghost"
            className="size-7 text-white/70 hover:text-white"
            onClick={handleExport}
            title="Download Whiteboard (PNG)"
          >
            <Download className="size-3.5" />
          </Button>
          <Button
            size="icon"
            variant="ghost"
            className="size-7 text-white/70 hover:text-white"
            onClick={() => setIsMaximized((v) => !v)}
            title={isMaximized ? "Restore view" : "Maximize view"}
          >
            {isMaximized ? <Minimize2 className="size-3.5" /> : <Maximize2 className="size-3.5" />}
          </Button>
          <Button
            size="icon"
            variant="ghost"
            className="size-7 text-white/70 hover:text-white hover:bg-rose-500/20"
            onClick={onClose}
            title="Close board"
          >
            <X className="size-4" />
          </Button>
        </div>
      </div>

      {/* Main Board Canvas & Tool Floating Palettes */}
      <div ref={containerRef} className="flex-1 min-h-0 relative bg-[#0B0F19] overflow-hidden">
        <canvas
          ref={canvasRef}
          className="absolute inset-0 w-full h-full cursor-crosshair touch-none"
          onMouseDown={startDrawing}
          onMouseMove={draw}
          onMouseUp={stopDrawing}
          onMouseLeave={stopDrawing}
          onTouchStart={startDrawing}
          onTouchMove={draw}
          onTouchEnd={stopDrawing}
        />

        {/* Text Input Modal / Overlay when adding Text / Sticky Note */}
        {textInput && (
          <div
            className="absolute z-20 p-2 rounded-xl bg-slate-800 border border-white/20 shadow-2xl flex flex-col gap-2"
            style={{
              left: Math.min(textInput.x, (containerRef.current?.clientWidth || 400) - 220),
              top: Math.min(textInput.y, (containerRef.current?.clientHeight || 400) - 130),
            }}
          >
            <p className="text-[11px] font-semibold text-white/80">
              {textInput.isNote ? "Add Sticky Note" : "Add Text"}
            </p>
            <textarea
              autoFocus
              rows={textInput.isNote ? 3 : 2}
              className="w-48 bg-slate-900 text-xs text-white p-2 rounded-lg border border-white/10 outline-none resize-none"
              placeholder="Type message here…"
              value={textInput.value}
              onChange={(e) => setTextInput({ ...textInput, value: e.target.value })}
              onKeyDown={(e) => {
                if (e.key === "Escape") {
                  setTextInput(null);
                } else if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  void handleAddTextOrNote();
                }
              }}
            />
            <div className="flex items-center justify-between gap-1.5">
              <span className="text-[10px] text-white/40">Press Enter ↵ to place</span>
              <div className="flex items-center gap-1">
                <Button size="sm" variant="ghost" className="h-6 px-2 text-[11px]" onClick={() => setTextInput(null)}>
                  Cancel
                </Button>
                <Button size="sm" className="h-6 px-2 text-[11px] bg-amber-400 text-slate-900 font-bold" onClick={handleAddTextOrNote}>
                  Place
                </Button>
              </div>
            </div>
          </div>
        )}

        {/* Floating Drawing Toolbar (Google Meet Style) */}
        <div className="absolute left-3 top-3 z-10 flex flex-col gap-1 p-1.5 rounded-2xl bg-slate-900/90 border border-white/15 backdrop-blur-md shadow-2xl">
          <Button
            size="icon"
            variant={tool === "pen" ? "default" : "ghost"}
            className={cn("size-8 rounded-xl", tool === "pen" && "bg-amber-400 text-slate-900 hover:bg-amber-300")}
            onClick={() => setTool("pen")}
            title="Pen"
          >
            <Pencil className="size-4" />
          </Button>
          <Button
            size="icon"
            variant={tool === "highlighter" ? "default" : "ghost"}
            className={cn("size-8 rounded-xl", tool === "highlighter" && "bg-amber-400 text-slate-900 hover:bg-amber-300")}
            onClick={() => setTool("highlighter")}
            title="Highlighter"
          >
            <Highlighter className="size-4" />
          </Button>
          <Button
            size="icon"
            variant={tool === "rectangle" ? "default" : "ghost"}
            className={cn("size-8 rounded-xl", tool === "rectangle" && "bg-amber-400 text-slate-900 hover:bg-amber-300")}
            onClick={() => setTool("rectangle")}
            title="Rectangle"
          >
            <Square className="size-4" />
          </Button>
          <Button
            size="icon"
            variant={tool === "circle" ? "default" : "ghost"}
            className={cn("size-8 rounded-xl", tool === "circle" && "bg-amber-400 text-slate-900 hover:bg-amber-300")}
            onClick={() => setTool("circle")}
            title="Circle / Ellipse"
          >
            <CircleIcon className="size-4" />
          </Button>
          <Button
            size="icon"
            variant={tool === "line" ? "default" : "ghost"}
            className={cn("size-8 rounded-xl", tool === "line" && "bg-amber-400 text-slate-900 hover:bg-amber-300")}
            onClick={() => setTool("line")}
            title="Line"
          >
            <Minus className="size-4" />
          </Button>
          <Button
            size="icon"
            variant={tool === "text" ? "default" : "ghost"}
            className={cn("size-8 rounded-xl", tool === "text" && "bg-amber-400 text-slate-900 hover:bg-amber-300")}
            onClick={() => setTool("text")}
            title="Text"
          >
            <Type className="size-4" />
          </Button>
          <Button
            size="icon"
            variant={tool === "note" ? "default" : "ghost"}
            className={cn("size-8 rounded-xl", tool === "note" && "bg-amber-400 text-slate-900 hover:bg-amber-300")}
            onClick={() => setTool("note")}
            title="Sticky Note"
          >
            <StickyNote className="size-4" />
          </Button>
          <Button
            size="icon"
            variant={tool === "eraser" ? "default" : "ghost"}
            className={cn("size-8 rounded-xl", tool === "eraser" && "bg-amber-400 text-slate-900 hover:bg-amber-300")}
            onClick={() => setTool("eraser")}
            title="Eraser"
          >
            <Eraser className="size-4" />
          </Button>
          <div className="h-px bg-white/10 my-0.5" />
          <Button
            size="icon"
            variant="ghost"
            className="size-8 rounded-xl text-white/70 hover:text-white"
            onClick={handleUndo}
            title="Undo"
          >
            <Undo className="size-4" />
          </Button>
          <Button
            size="icon"
            variant="ghost"
            className="size-8 rounded-xl text-rose-400 hover:text-rose-300 hover:bg-rose-500/20"
            onClick={handleClear}
            title="Clear board"
          >
            <Trash2 className="size-4" />
          </Button>
        </div>

        {/* Floating Color & Size Selector */}
        <div className="absolute bottom-3 left-1/2 -translate-x-1/2 z-10 flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-900/90 border border-white/15 backdrop-blur-md shadow-2xl max-w-[95%] overflow-x-auto">
          {/* Colors */}
          <div className="flex items-center gap-1">
            {BOARD_COLORS.map((c) => (
              <button
                key={c}
                type="button"
                className={cn(
                  "size-5 rounded-full border border-black/40 transition-transform hover:scale-125 shrink-0",
                  color === c && "ring-2 ring-white ring-offset-2 ring-offset-slate-900 scale-110",
                )}
                style={{ backgroundColor: c }}
                onClick={() => setColor(c)}
                title={c}
              />
            ))}
          </div>

          <div className="h-4 w-px bg-white/15 mx-1 shrink-0" />

          {/* Stroke Widths */}
          <div className="flex items-center gap-1 shrink-0">
            {STROKE_SIZES.map((s) => (
              <button
                key={s.label}
                type="button"
                className={cn(
                  "px-2 py-0.5 text-[10px] font-bold rounded-md transition-colors",
                  strokeSize === s.size
                    ? "bg-amber-400 text-slate-900"
                    : "text-white/60 hover:text-white hover:bg-white/10",
                )}
                onClick={() => setStrokeSize(s.size)}
              >
                {s.label}
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
