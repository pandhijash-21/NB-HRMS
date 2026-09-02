"use client";

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import {
  Search,
  Plus,
  Send,
  Paperclip,
  Users,
  MessageSquare,
  Smile,
  Loader2,
  Download,
  X,
  Copy,
  Forward,
  Reply,
  Pencil,
  Trash2,
} from "lucide-react";
import { useChat, type ChatChannel, type ChatMessage, type CollabProfile } from "@/lib/hooks/useChat";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { PhotoLightbox } from "@/components/ui/photo-lightbox";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { useSession } from "next-auth/react";
import { CHAT_EMOJIS } from "@/lib/chat-emojis";

function clock(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function receiptsFor(message: ChatMessage, channel: ChatChannel) {
  const others = channel.members.filter((m) => m.userId !== message.senderId);
  const sent = message.createdAt ? new Date(message.createdAt).getTime() : 0;
  const seen = others.filter((m) => m.lastReadAt && new Date(m.lastReadAt).getTime() >= sent);
  const unseen = others.filter((m) => !m.lastReadAt || new Date(m.lastReadAt).getTime() < sent);
  return { seen, unseen };
}

function initials(name?: string | null) {
  return (name || "?")
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase())
    .join("");
}

function firstName(name?: string | null) {
  const t = (name || "").trim();
  if (!t) return "Someone";
  return t.split(/\s+/)[0];
}

function presenceSubtitle(channel: ChatChannel, myId?: string) {
  const others = channel.members.filter((m) => m.userId !== myId);
  if (channel.type !== "GROUP") {
    const other = others[0];
    if (!other) return "Saved messages";
    return other.online ? "Available" : "Away";
  }
  const online = others.filter((m) => m.online);
  if (online.length === 0) return `${channel.members.length} members`;
  if (online.length === 1) return `${firstName(online[0].name)} available`;
  if (online.length === 2) {
    return `${firstName(online[0].name)} and ${firstName(online[1].name)} available`;
  }
  return `${online.length} of ${others.length} available`;
}

function mentionQuery(draft: string) {
  const match = /(^|[\s])@([^\s@]*)$/.exec(draft);
  if (!match) return null;
  return match[2] ?? "";
}

function mentionChoices(channel: ChatChannel | null, myId?: string, q?: string | null) {
  if (!channel || channel.type !== "GROUP" || q == null) return [];
  const query = q.trim().toLowerCase();
  const rows: { label: string; insert: string; everyone?: boolean }[] = [];
  if (!query || "all".startsWith(query) || "everyone".startsWith(query)) {
    rows.push({ label: "Everyone", insert: "@all ", everyone: true });
  }
  for (const m of channel.members) {
    if (m.userId === myId) continue;
    const name = (m.name || "").trim();
    if (!name) continue;
    const hay = `${name} ${m.email || ""}`.toLowerCase();
    if (query && !hay.includes(query)) continue;
    rows.push({ label: name, insert: `@${name} ` });
  }
  return rows.slice(0, 8);
}

function highlightMentions(content: string, members: CollabProfile[]) {
  const tokens = ["all", ...members.map((m) => m.name.trim()).filter(Boolean)].sort(
    (a, b) => b.length - a.length,
  );
  const unique = Array.from(new Set(tokens.map((t) => t.toLowerCase()))).map(
    (key) => tokens.find((t) => t.toLowerCase() === key) as string,
  );
  if (!content.includes("@") || unique.length === 0) return content;
  const re = new RegExp(`(@(?:${unique.map((t) => t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|")}))(?=$|[\\s,.!?;:])`, "gi");
  const parts: ReactNode[] = [];
  let last = 0;
  let i = 0;
  for (const match of content.matchAll(re)) {
    const start = match.index ?? 0;
    if (start > last) parts.push(content.slice(last, start));
    parts.push(
      <span key={`m-${i++}`} className="font-semibold text-primary">
        {match[0]}
      </span>,
    );
    last = start + match[0].length;
  }
  if (last < content.length) parts.push(content.slice(last));
  return parts;
}

function isImageAttachment(fileName?: string | null, mimeType?: string | null) {
  const mime = (mimeType || "").toLowerCase();
  const name = (fileName || "").toLowerCase();
  return mime.startsWith("image/") || /\.(png|jpe?g|gif|webp|bmp)$/i.test(name);
}

function downloadBlob(blob: Blob, fileName: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = fileName || "file";
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 30_000);
}

const DRAFTS_KEY = "nb-hrms-chat-drafts";

function loadDrafts(): Record<string, string> {
  if (typeof window === "undefined") return {};
  try {
    const raw = localStorage.getItem(DRAFTS_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object") return {};
    return parsed as Record<string, string>;
  } catch {
    return {};
  }
}

function persistDrafts(map: Record<string, string>) {
  try {
    localStorage.setItem(DRAFTS_KEY, JSON.stringify(map));
  } catch {
    /* ignore quota */
  }
}

export function ChatApp() {
  const chat = useChat();
  const { data: session } = useSession();
  const myId = (session?.user as { id?: string })?.id;
  const [query, setQuery] = useState("");
  const [draft, setDraft] = useState("");
  const [files, setFiles] = useState<File[]>([]);
  const [replyTo, setReplyTo] = useState<ChatMessage | null>(null);
  const [actionFor, setActionFor] = useState<ChatMessage | null>(null);
  const [forwardFor, setForwardFor] = useState<ChatMessage | null>(null);
  const [editFor, setEditFor] = useState<ChatMessage | null>(null);
  const [editText, setEditText] = useState("");
  const [forwardQ, setForwardQ] = useState("");
  const [forwardIds, setForwardIds] = useState<string[]>([]);
  const [forwardSending, setForwardSending] = useState(false);
  const draftsRef = useRef<Record<string, string>>(loadDrafts());
  const [drafts, setDrafts] = useState<Record<string, string>>(() => draftsRef.current);
  const draftRef = useRef(draft);
  const filesRef = useRef(files);
  const replyRef = useRef<ChatMessage | null>(null);
  const filesByChannel = useRef<Record<string, File[]>>({});
  const replyByChannel = useRef<Record<string, ChatMessage | null>>({});
  const prevActiveRef = useRef<string | null>(null);
  const skipDraftSave = useRef(false);
  draftRef.current = draft;
  filesRef.current = files;
  replyRef.current = replyTo;
  const [showNew, setShowNew] = useState<"dm" | "group" | null>(null);
  const [peopleQ, setPeopleQ] = useState("");
  const [picked, setPicked] = useState<CollabProfile[]>([]);
  const [groupName, setGroupName] = useState("");
  const [mobilePane, setMobilePane] = useState<"list" | "thread">("list");
  const [emojiOpen, setEmojiOpen] = useState(false);
  const [reactFor, setReactFor] = useState<ChatMessage | null>(null);
  const [reactorsFor, setReactorsFor] = useState<{
    messageId: string;
    emoji: string;
    mine: boolean;
    users: { userId: string; name: string; photoUrl: string | null }[];
  } | null>(null);
  const [seenFor, setSeenFor] = useState<ChatMessage | null>(null);
  const [mentionSel, setMentionSel] = useState(0);
  const [attachmentBusy, setAttachmentBusy] = useState<string | null>(null);
  const [preview, setPreview] = useState<{ src: string; alt: string } | null>(null);
  const mentionQ = mentionQuery(draft);
  const mentionHits = mentionChoices(chat.active, myId, mentionQ);

  useEffect(() => {
    setMentionSel(0);
  }, [mentionQ, chat.active?.id]);

  useEffect(() => {
    const prev = prevActiveRef.current;
    const next = chat.activeId;
    if (prev && prev !== next) {
      const text = draftRef.current;
      if (text) draftsRef.current[prev] = text;
      else delete draftsRef.current[prev];
      persistDrafts(draftsRef.current);
      setDrafts({ ...draftsRef.current });
      filesByChannel.current[prev] = filesRef.current;
      replyByChannel.current[prev] = replyRef.current;
    }
    prevActiveRef.current = next;
    skipDraftSave.current = true;
    setDraft(next ? (draftsRef.current[next] ?? "") : "");
    setFiles(next ? (filesByChannel.current[next] ?? []) : []);
    setReplyTo(next ? (replyByChannel.current[next] ?? null) : null);
    setEmojiOpen(false);
  }, [chat.activeId]);

  useEffect(() => {
    if (!chat.activeId) return;
    if (skipDraftSave.current) return;
    if (draft) draftsRef.current[chat.activeId] = draft;
    else delete draftsRef.current[chat.activeId];
    persistDrafts(draftsRef.current);
    setDrafts({ ...draftsRef.current });
  }, [draft, chat.activeId]);

  useEffect(() => {
    skipDraftSave.current = false;
  }, [chat.activeId, draft]);

  function applyMention(insert: string) {
    setDraft((prev) => prev.replace(/@([^\s@]*)$/, insert));
  }

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key !== "Escape") return;
      if (actionFor || reactFor || seenFor || showNew || forwardFor || editFor) return;
      if (mentionHits.length) return;
      if (!chat.activeId) return;
      e.preventDefault();
      chat.setActiveId(null);
      setDraft("");
      setFiles([]);
      setEmojiOpen(false);
      setMobilePane("list");
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [chat.activeId, chat.setActiveId, actionFor, reactFor, seenFor, showNew, forwardFor, editFor, mentionHits.length]);

  async function openAttachment(
    id?: string,
    fallback?: string | null,
    fileName?: string,
    mimeType?: string,
  ) {
    const key = id || fileName || "file";
    setAttachmentBusy(`view:${key}`);
    try {
      if (id) {
        const blob = await chat.attachmentBlob(id);
        const url = URL.createObjectURL(blob);
        if (isImageAttachment(fileName, mimeType) || blob.type.startsWith("image/")) {
          setPreview((prev) => {
            if (prev?.src.startsWith("blob:")) URL.revokeObjectURL(prev.src);
            return { src: url, alt: fileName || "Photo" };
          });
          return;
        }
        window.open(url, "_blank", "noopener,noreferrer");
        window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
        return;
      }
      if (fallback) window.open(fallback, "_blank", "noopener,noreferrer");
    } catch {
      if (fallback) window.open(fallback, "_blank", "noopener,noreferrer");
    } finally {
      setAttachmentBusy(null);
    }
  }

  async function downloadAttachment(id?: string, fallback?: string | null, fileName?: string) {
    const key = id || fileName || "file";
    setAttachmentBusy(`dl:${key}`);
    try {
      if (id) {
        const blob = await chat.attachmentBlob(id, true);
        downloadBlob(blob, fileName || "file");
        return;
      }
      if (fallback) window.open(fallback, "_blank", "noopener,noreferrer");
    } catch {
      if (fallback) window.open(fallback, "_blank", "noopener,noreferrer");
    } finally {
      setAttachmentBusy(null);
    }
  }

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return chat.channels;
    return chat.channels.filter((c) =>
      (c.name || "").toLowerCase().includes(q) ||
      c.members.some((m) => m.name.toLowerCase().includes(q)),
    );
  }, [chat.channels, query]);

  async function onSearchPeople(v: string) {
    setPeopleQ(v);
    await chat.searchPeople(v);
  }

  async function submit() {
    const text = draft.trim();
    if (!text && files.length === 0) return;
    const replyId = replyTo?.id;
    await chat.send(text, files, { replyToId: replyId });
    if (chat.activeId) {
      delete draftsRef.current[chat.activeId];
      persistDrafts(draftsRef.current);
      setDrafts({ ...draftsRef.current });
      filesByChannel.current[chat.activeId] = [];
      replyByChannel.current[chat.activeId] = null;
    }
    skipDraftSave.current = true;
    setDraft("");
    setFiles([]);
    setReplyTo(null);
  }

  function copyMessage(m: ChatMessage) {
    const parts = [m.content?.trim() || "", ...m.attachments.map((a) => a.fileName)].filter(Boolean);
    if (!parts.length) return;
    void navigator.clipboard.writeText(parts.join("\n"));
  }

  function channelTitle(c: ChatChannel) {
    const other = c.members.find((m) => m.userId !== myId);
    const selfDm = c.type === "DIRECT" && !other;
    return c.type === "GROUP" ? c.name : selfDm ? c.name || "Note to self" : other?.name;
  }

  return (
    <div className="h-full min-h-0 overflow-hidden grid grid-cols-1 md:grid-cols-[minmax(0,320px)_minmax(0,1fr)]">
      <aside
        className={cn(
          "border-r border-border/60 bg-card/40 flex flex-col min-h-0",
          mobilePane === "thread" && "hidden md:flex",
        )}
      >
        <div className="p-3 border-b border-border/50 flex items-center gap-2">
          <div className="relative flex-1">
            <Search className="size-4 absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search chats"
              className="pl-8 h-9"
            />
          </div>
          <Button size="icon" variant="outline" className="h-9 w-9" onClick={() => { setShowNew("dm"); void chat.searchPeople(""); }} title="New chat">
            <Plus className="size-4" />
          </Button>
        </div>
        <div className="px-3 py-2 flex gap-2">
          <Button size="sm" variant="secondary" className="flex-1" onClick={() => { setShowNew("dm"); void chat.searchPeople(""); }}>
            New chat
          </Button>
          <Button size="sm" variant="secondary" className="flex-1" onClick={() => { setShowNew("group"); void chat.searchPeople(""); }}>
            <Users className="size-3.5 mr-1" /> Group
          </Button>
        </div>
        <div className="flex-1 overflow-y-auto">
          {chat.loading ? (
            <p className="p-4 text-sm text-muted-foreground">Loading conversations…</p>
          ) : visible.length === 0 ? (
            <p className="p-4 text-sm text-muted-foreground">No chats yet. Start a conversation.</p>
          ) : (
            visible.map((c) => {
              const other = c.members.find((m) => m.userId !== myId);
              const selfDm = c.type === "DIRECT" && !other;
              const title = c.type === "GROUP" ? c.name : selfDm ? c.name || "Note to self" : other?.name;
              const online = c.type === "DIRECT" && other?.online;
              return (
                <button
                  key={c.id}
                  onClick={() => {
                    chat.setActiveId(c.id);
                    setMobilePane("thread");
                  }}
                  className={cn(
                    "w-full flex items-center gap-3 px-3 py-2.5 text-left hover:bg-accent/50",
                    chat.activeId === c.id && "bg-accent",
                  )}
                >
                  <div className="relative">
                    <PhotoLightbox src={c.avatarUrl || other?.photoUrl} alt={title || ""}>
                    <Avatar>
                      <AvatarImage src={c.avatarUrl || other?.photoUrl || undefined} />
                      <AvatarFallback>{initials(title)}</AvatarFallback>
                    </Avatar>
                    </PhotoLightbox>
                    {online && (
                      <span className="absolute bottom-0 right-0 size-2.5 rounded-full bg-emerald-500 ring-2 ring-background" />
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between gap-2">
                      <p className="truncate text-sm font-semibold">{title}</p>
                      {c.unread > 0 && (
                        <span className="text-[10px] font-bold bg-primary text-primary-foreground rounded-full min-w-5 h-5 px-1 grid place-items-center">
                          {c.unread}
                        </span>
                      )}
                    </div>
                    <p className="truncate text-xs text-muted-foreground">
                      {drafts[c.id]?.trim() ? (
                        <>
                          <span className="font-semibold text-red-600 dark:text-red-400">Draft: </span>
                          {drafts[c.id]}
                        </>
                      ) : (
                        c.lastMessage?.content || (c.lastMessage?.hasAttachment ? "Attachment" : "No messages yet")
                      )}
                    </p>
                  </div>
                </button>
              );
            })
          )}
        </div>
      </aside>

      <section
        className={cn(
          "relative flex flex-col min-h-0 bg-background",
          mobilePane === "list" && "hidden md:flex",
        )}
      >
        {(chat.sending || attachmentBusy) && (
          <div className="absolute inset-x-0 top-0 z-20 h-0.5 overflow-hidden bg-primary/20">
            <div className="h-full w-full animate-pulse bg-primary" />
          </div>
        )}
        {chat.active ? (
          <>
            <div className="h-14 border-b border-border/60 px-4 flex items-center gap-3">
              <button className="md:hidden text-sm text-primary" onClick={() => setMobilePane("list")}>
                Back
              </button>
              <PhotoLightbox src={chat.active.avatarUrl} alt={chat.active.name || ""}>
              <Avatar>
                <AvatarImage src={chat.active.avatarUrl || undefined} />
                <AvatarFallback>{initials(chat.active.name)}</AvatarFallback>
              </Avatar>
              </PhotoLightbox>
              <div className="min-w-0">
                <p className="font-semibold truncate">{chat.active.name}</p>
                <p className="text-xs text-muted-foreground truncate">
                  {chat.typing
                    ? `${chat.typing.name} is typing…`
                    : presenceSubtitle(chat.active, myId)}
                </p>
              </div>
            </div>
            <div className="flex-1 overflow-y-auto p-4 space-y-3">
              {chat.messages.map((m) => {
                const mine = m.senderId === myId;
                const rec = chat.active ? receiptsFor(m, chat.active) : { seen: [], unseen: [] };
                const other = chat.active?.members.find((x) => x.userId !== myId);
                const selfDm = chat.active?.type === "DIRECT" && !other;
                return (
                  <div key={m.id} className={cn("flex gap-2", mine ? "justify-end" : "justify-start")}>
                    {!mine && (
                      <PhotoLightbox src={m.sender?.photoUrl} alt={m.sender?.name}>
                      <Avatar size="sm">
                        <AvatarImage src={m.sender?.photoUrl || undefined} />
                        <AvatarFallback>{initials(m.sender?.name)}</AvatarFallback>
                      </Avatar>
                      </PhotoLightbox>
                    )}
                    <div className={cn("max-w-[78%] sm:max-w-[62%]")}>
                      {!mine && (
                        <p className="text-[11px] text-muted-foreground mb-0.5 px-1">{m.sender?.name}</p>
                      )}
                      {m.replyTo && !m.deletedAt && (
                        <div className="mb-1 mx-1 px-2 py-1 rounded-md border-l-[3px] border-primary bg-black/5 text-[11px]">
                          <p className="font-semibold text-primary truncate">{m.replyTo.senderName}</p>
                          <p className="truncate text-muted-foreground">{m.replyTo.content || "Attachment"}</p>
                        </div>
                      )}
                      <div
                        onContextMenu={(e) => {
                          if (m.deletedAt) return;
                          e.preventDefault();
                          setActionFor(m);
                        }}
                        onPointerDown={(e) => {
                          if (m.deletedAt || e.pointerType !== "touch") return;
                          const node = e.currentTarget;
                          const t = window.setTimeout(() => setActionFor(m), 450);
                          const clear = () => window.clearTimeout(t);
                          node.addEventListener("pointerup", clear, { once: true });
                          node.addEventListener("pointercancel", clear, { once: true });
                        }}
                        className={cn(
                          "rounded-2xl px-3 py-2 text-sm shadow-sm",
                          mine
                            ? "bg-primary text-primary-foreground rounded-br-md"
                            : "bg-card border border-border/60 rounded-bl-md",
                          m.deletedAt && "italic opacity-70",
                        )}
                      >
                        {m.deletedAt ? "This message was deleted" : highlightMentions(m.content || "", chat.active?.members || [])}
                        {m.attachments.map((a) => {
                          const viewing = attachmentBusy === `view:${a.id}`;
                          const downloading = attachmentBusy === `dl:${a.id}`;
                          return (
                          <div key={a.id} className="mt-1 flex items-center gap-2 text-xs">
                            <button
                              type="button"
                              disabled={!!attachmentBusy}
                              onClick={() => void openAttachment(a.id, a.fileUrl, a.fileName, a.mimeType)}
                              className="flex items-center gap-2 underline disabled:opacity-60"
                            >
                              {viewing ? (
                                <Loader2 className="size-3 animate-spin" />
                              ) : (
                                <Paperclip className="size-3" />
                              )}
                              {a.fileName}
                            </button>
                            <button
                              type="button"
                              disabled={!!attachmentBusy}
                              title="Download"
                              onClick={() => void downloadAttachment(a.id, a.fileUrl, a.fileName)}
                              className="p-0.5 rounded hover:bg-black/10 disabled:opacity-60"
                            >
                              {downloading ? (
                                <Loader2 className="size-3 animate-spin" />
                              ) : (
                                <Download className="size-3" />
                              )}
                            </button>
                          </div>
                          );
                        })}
                      </div>
                      {m.reactions.length > 0 && (
                        <div className="flex flex-wrap gap-1 mt-1 px-1">
                          {m.reactions.map((r) => (
                            <button
                              key={r.emoji}
                              type="button"
                              onClick={() =>
                                setReactorsFor({
                                  messageId: m.id,
                                  emoji: r.emoji,
                                  mine: r.mine || (r.users ?? []).some((u) => u.userId === myId) || r.userIds.includes(myId || ""),
                                  users: r.users?.length
                                    ? r.users
                                    : r.userIds.map((userId) => ({
                                        userId,
                                        name: chat.active?.members.find((p) => p.userId === userId)?.name || "Member",
                                        photoUrl: chat.active?.members.find((p) => p.userId === userId)?.photoUrl ?? null,
                                      })),
                                })
                              }
                              className={cn(
                                "text-[11px] rounded-full border px-1.5 py-0.5",
                                r.mine ? "border-primary bg-primary/10" : "border-border",
                              )}
                            >
                              {r.emoji} {r.count}
                            </button>
                          ))}
                        </div>
                      )}
                      <div className="mt-0.5 px-1 text-[10px] text-muted-foreground flex items-center gap-1 justify-end">
                        <span>{clock(m.createdAt)}</span>
                        {mine && !selfDm && chat.active?.type === "GROUP" && (
                          <button type="button" onClick={() => setSeenFor(m)}>
                            {rec.seen.length
                              ? `Seen by ${rec.seen.length} of ${rec.seen.length + rec.unseen.length}`
                              : "Sent"}
                          </button>
                        )}
                        {mine && !selfDm && chat.active?.type !== "GROUP" && (
                          <button type="button" onClick={() => setSeenFor(m)}>
                            {rec.seen.length ? "Seen" : "Sent"}
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            {files.length > 0 && (
              <div className="px-4 text-xs text-muted-foreground">
                {files.map((f) => f.name).join(", ")}
              </div>
            )}
            {replyTo && (
              <div className="px-4 py-2 border-t border-border/60 flex items-center gap-2">
                <div className="w-0.5 self-stretch bg-primary rounded-full" />
                <div className="min-w-0 flex-1">
                  <p className="text-xs font-semibold text-primary truncate">
                    Replying to {replyTo.sender?.name || "message"}
                  </p>
                  <p className="text-xs text-muted-foreground truncate">
                    {replyTo.content?.trim() || (replyTo.attachments.length ? "Attachment" : "Message")}
                  </p>
                </div>
                <button type="button" className="p-1 rounded hover:bg-accent" onClick={() => setReplyTo(null)}>
                  <X className="size-4" />
                </button>
              </div>
            )}
            {emojiOpen && (
              <div className="max-h-48 overflow-y-auto border-t border-border/60 p-1 grid grid-cols-8 sm:grid-cols-12 gap-0">
                {CHAT_EMOJIS.map((e, i) => (
                  <button
                    key={`${e}-${i}`}
                    type="button"
                    className="h-7 text-base leading-none hover:bg-accent rounded-sm"
                    onClick={() => setDraft((prev) => prev + e)}
                  >
                    {e}
                  </button>
                ))}
              </div>
            )}
            <form
              className="p-3 border-t border-border/60 flex items-end gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                submit();
              }}
            >
              <label className="cursor-pointer p-2 rounded-lg hover:bg-accent">
                <Paperclip className="size-4" />
                <input
                  type="file"
                  className="hidden"
                  multiple
                  onChange={(e) => setFiles(Array.from(e.target.files || []))}
                />
              </label>
              <button
                type="button"
                className={cn("p-2 rounded-lg hover:bg-accent", emojiOpen && "text-primary")}
                onClick={() => setEmojiOpen((v) => !v)}
              >
                <Smile className="size-4" />
              </button>
              <div className="relative flex-1 min-w-0">
                {mentionHits.length > 0 && (
                  <div className="absolute bottom-full left-0 right-0 mb-1 rounded-lg border border-border/60 bg-card shadow-lg overflow-hidden max-h-56 overflow-y-auto z-10">
                    {mentionHits.map((hit, i) => (
                      <button
                        key={`${hit.insert}-${i}`}
                        type="button"
                        className={cn(
                          "w-full text-left px-3 py-2 text-sm",
                          i === mentionSel ? "bg-primary/10 text-primary" : "hover:bg-accent",
                        )}
                        onMouseDown={(e) => {
                          e.preventDefault();
                          applyMention(hit.insert);
                        }}
                      >
                        <span className="font-semibold">{hit.label}</span>
                        {hit.everyone ? (
                          <span className="ml-2 text-xs text-muted-foreground">Notify all members</span>
                        ) : null}
                      </button>
                    ))}
                  </div>
                )}
                <Textarea
                value={draft}
                onChange={(e) => {
                  setDraft(e.target.value);
                  chat.emitTyping();
                }}
                onKeyDown={(e) => {
                  if (mentionHits.length) {
                    if (e.key === "ArrowDown") {
                      e.preventDefault();
                      setMentionSel((i) => (i + 1) % mentionHits.length);
                      return;
                    }
                    if (e.key === "ArrowUp") {
                      e.preventDefault();
                      setMentionSel((i) => (i - 1 + mentionHits.length) % mentionHits.length);
                      return;
                    }
                    if (e.key === "Enter" && !e.shiftKey) {
                      e.preventDefault();
                      applyMention(mentionHits[mentionSel]?.insert || mentionHits[0].insert);
                      return;
                    }
                    if (e.key === "Escape") {
                      e.preventDefault();
                      setDraft((prev) => prev.replace(/@([^\s@]*)$/, ""));
                      return;
                    }
                  }
                  if (e.key === "Escape") {
                    e.preventDefault();
                    chat.setActiveId(null);
                    setDraft("");
                    setFiles([]);
                    setEmojiOpen(false);
                    setMobilePane("list");
                    return;
                  }
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    submit();
                  }
                }}
                placeholder="Type a message"
                className="min-h-[44px] max-h-32"
              />
              </div>
              <Button type="submit" disabled={chat.sending} className="h-11">
                {chat.sending ? <Loader2 className="size-4 animate-spin" /> : <Send className="size-4" />}
              </Button>
            </form>
          </>
        ) : (
          <div className="flex-1 grid place-items-center text-center p-8 text-muted-foreground">
            <div>
              <MessageSquare className="size-10 mx-auto mb-3 opacity-50" />
              <p className="font-medium text-foreground">Teams-style chat</p>
              <p className="text-sm mt-1">Select a conversation or start a new one.</p>
            </div>
          </div>
        )}
      </section>

      <Dialog open={!!showNew} onOpenChange={() => setShowNew(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{showNew === "group" ? "New group" : "New chat"}</DialogTitle>
          </DialogHeader>
          {showNew === "group" && (
            <Input
              placeholder="Group name"
              value={groupName}
              onChange={(e) => setGroupName(e.target.value)}
            />
          )}
          <Input
            placeholder="Search people"
            value={peopleQ}
            onChange={(e) => onSearchPeople(e.target.value)}
          />
          <div className="max-h-56 overflow-y-auto space-y-1">
            {chat.directory
              .filter((p) => showNew !== "group" || p.userId !== myId)
              .map((p) => {
              const selected = picked.some((x) => x.userId === p.userId);
              const isSelf = p.userId === myId;
              return (
                <button
                  key={p.userId}
                  className={cn(
                    "w-full flex items-center gap-2 rounded-lg px-2 py-2 text-left hover:bg-accent",
                    selected && "bg-accent",
                  )}
                  onClick={() => {
                    if (showNew === "dm") {
                      chat.startDm(p.userId);
                      setShowNew(null);
                      setMobilePane("thread");
                      return;
                    }
                    setPicked((prev) =>
                      selected ? prev.filter((x) => x.userId !== p.userId) : [...prev, p],
                    );
                  }}
                >
                  <Avatar size="sm">
                    <AvatarImage src={p.photoUrl || undefined} />
                    <AvatarFallback>{initials(p.name)}</AvatarFallback>
                  </Avatar>
                  <span className="flex flex-col min-w-0">
                    <span className="text-sm truncate">{isSelf ? `${p.name} (You)` : p.name}</span>
                    {isSelf && showNew === "dm" ? (
                      <span className="text-xs text-muted-foreground">Note to self</span>
                    ) : null}
                  </span>
                </button>
              );
            })}
          </div>
          {showNew === "group" && (
            <DialogFooter>
              <Button
                onClick={async () => {
                  await chat.createGroup(groupName, picked.map((p) => p.userId));
                  setShowNew(null);
                  setPicked([]);
                  setGroupName("");
                  setMobilePane("thread");
                }}
                disabled={!groupName.trim() || picked.length === 0}
              >
                Create group
              </Button>
            </DialogFooter>
          )}
        </DialogContent>
      </Dialog>

      <Dialog open={!!actionFor} onOpenChange={() => setActionFor(null)}>
        <DialogContent className="max-w-sm w-[calc(100vw-1.5rem)] sm:w-full">
          <DialogHeader>
            <DialogTitle>Message</DialogTitle>
          </DialogHeader>
          {actionFor && chat.active && (() => {
            const mine = actionFor.senderId === myId;
            const rec = receiptsFor(actionFor, chat.active);
            const canMutate = mine && rec.seen.length === 0 && !actionFor.deletedAt;
            const canEdit = canMutate && !!(actionFor.content || "").trim();
            return (
              <div className="grid gap-1">
                <Button
                  variant="ghost"
                  className="justify-start"
                  onClick={() => {
                    setReplyTo(actionFor);
                    setActionFor(null);
                  }}
                >
                  <Reply className="size-4 mr-2" /> Reply
                </Button>
                <Button
                  variant="ghost"
                  className="justify-start"
                  onClick={() => {
                    copyMessage(actionFor);
                    setActionFor(null);
                  }}
                >
                  <Copy className="size-4 mr-2" /> Copy
                </Button>
                <Button
                  variant="ghost"
                  className="justify-start"
                  onClick={() => {
                    setForwardFor(actionFor);
                    setForwardQ("");
                    setForwardIds([]);
                    setForwardSending(false);
                    setActionFor(null);
                  }}
                >
                  <Forward className="size-4 mr-2" /> Forward
                </Button>
                <Button
                  variant="ghost"
                  className="justify-start"
                  onClick={() => {
                    setReactFor(actionFor);
                    setActionFor(null);
                  }}
                >
                  <Smile className="size-4 mr-2" /> React
                </Button>
                {canEdit && (
                  <Button
                    variant="ghost"
                    className="justify-start"
                    onClick={() => {
                      setEditText(actionFor.content || "");
                      setEditFor(actionFor);
                      setActionFor(null);
                    }}
                  >
                    <Pencil className="size-4 mr-2" /> Edit
                  </Button>
                )}
                {canMutate && (
                  <Button
                    variant="ghost"
                    className="justify-start text-destructive"
                    onClick={async () => {
                      const id = actionFor.id;
                      setActionFor(null);
                      await chat.deleteMessage(id);
                    }}
                  >
                    <Trash2 className="size-4 mr-2" /> Delete
                  </Button>
                )}
              </div>
            );
          })()}
        </DialogContent>
      </Dialog>

      <Dialog
        open={!!forwardFor}
        onOpenChange={(open) => {
          if (!open) {
            setForwardFor(null);
            setForwardIds([]);
            setForwardSending(false);
          }
        }}
      >
        <DialogContent className="max-w-md w-[calc(100vw-1.5rem)]">
          <DialogHeader>
            <DialogTitle>Forward to</DialogTitle>
          </DialogHeader>
          <Input
            placeholder="Search people or chats"
            value={forwardQ}
            onChange={(e) => setForwardQ(e.target.value)}
          />
          <div className="max-h-72 overflow-y-auto space-y-0.5">
            {chat.channels
              .filter((c) => {
                const q = forwardQ.trim().toLowerCase();
                if (!q) return true;
                return (channelTitle(c) || "").toLowerCase().includes(q);
              })
              .map((c) => {
                const checked = forwardIds.includes(c.id);
                return (
                  <button
                    key={c.id}
                    type="button"
                    className="flex items-center gap-3 px-2 py-2 rounded-lg hover:bg-accent text-sm cursor-pointer min-w-0 w-full text-left"
                    onClick={() => {
                      setForwardIds((prev) =>
                        prev.includes(c.id) ? prev.filter((id) => id !== c.id) : [...prev, c.id],
                      );
                    }}
                  >
                    <Checkbox checked={checked} className="pointer-events-none" />
                    <span className="truncate">{channelTitle(c)}</span>
                  </button>
                );
              })}
          </div>
          <DialogFooter className="gap-2 sm:justify-between">
            <p className="text-xs text-muted-foreground self-center">
              {forwardIds.length === 0
                ? "Select people, then send"
                : `${forwardIds.length} selected`}
            </p>
            <Button
              disabled={forwardIds.length === 0 || forwardSending || !forwardFor}
              onClick={async () => {
                if (!forwardFor || forwardIds.length === 0) return;
                const msg = forwardFor;
                const ids = [...forwardIds];
                setForwardSending(true);
                try {
                  for (const id of ids) {
                    await chat.sendToChannel(id, {
                      content: msg.content || "",
                      attachments: msg.attachments,
                    });
                  }
                  setForwardFor(null);
                  setForwardIds([]);
                  setForwardQ("");
                } catch {
                  /* keep picker open so they can retry */
                } finally {
                  setForwardSending(false);
                }
              }}
            >
              <Send className="size-4 mr-2" />
              {forwardSending ? "Sending…" : "Send"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={!!editFor} onOpenChange={() => setEditFor(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit message</DialogTitle>
          </DialogHeader>
          <Textarea value={editText} onChange={(e) => setEditText(e.target.value)} className="min-h-[80px]" />
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditFor(null)}>Cancel</Button>
            <Button
              disabled={!editText.trim()}
              onClick={async () => {
                if (!editFor) return;
                await chat.editMessage(editFor.id, editText.trim());
                setEditFor(null);
              }}
            >
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={!!reactFor} onOpenChange={() => setReactFor(null)}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>React</DialogTitle>
          </DialogHeader>
          <div className="max-h-72 overflow-y-auto grid grid-cols-8 sm:grid-cols-12 gap-0 p-1">
            {CHAT_EMOJIS.map((e, i) => (
              <button
                key={`${e}-${i}`}
                type="button"
                className="h-7 text-base leading-none hover:bg-accent rounded-sm"
                onClick={() => {
                  if (!reactFor) return;
                  chat.react(reactFor.id, e);
                  setReactFor(null);
                }}
              >
                {e}
              </button>
            ))}
          </div>
        </DialogContent>
      </Dialog>

      <Dialog open={!!reactorsFor} onOpenChange={() => setReactorsFor(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {reactorsFor?.emoji} {reactorsFor && reactorsFor.users.length === 1 ? "1 reaction" : `${reactorsFor?.users.length ?? 0} reactions`}
            </DialogTitle>
          </DialogHeader>
          <div className="max-h-72 overflow-y-auto space-y-1">
            {(reactorsFor?.users ?? []).map((p) => (
              <div key={p.userId} className="flex items-center gap-2 py-1">
                <Avatar size="sm">
                  <AvatarImage src={p.photoUrl || undefined} />
                  <AvatarFallback>{initials(p.name)}</AvatarFallback>
                </Avatar>
                <span className="text-sm">{p.userId === myId ? `${p.name} (you)` : p.name}</span>
              </div>
            ))}
          </div>
          {reactorsFor && (
            <DialogFooter>
              <Button
                variant="outline"
                onClick={() => {
                  chat.react(reactorsFor.messageId, reactorsFor.emoji);
                  setReactorsFor(null);
                }}
              >
                {reactorsFor.mine ? "Remove your reaction" : `React with ${reactorsFor.emoji}`}
              </Button>
            </DialogFooter>
          )}
        </DialogContent>
      </Dialog>

      <Dialog open={!!seenFor} onOpenChange={() => setSeenFor(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Message status</DialogTitle>
          </DialogHeader>
          {seenFor && chat.active && (
            <div className="space-y-4">
              <div>
                <p className="text-sm font-semibold mb-2">
                  Seen ({receiptsFor(seenFor, chat.active).seen.length})
                </p>
                {receiptsFor(seenFor, chat.active).seen.length === 0 && (
                  <p className="text-sm text-muted-foreground">Nobody has seen this yet.</p>
                )}
                {receiptsFor(seenFor, chat.active).seen.map((p) => (
                  <div key={p.userId} className="flex items-center gap-2 py-1">
                    <Avatar size="sm">
                      <AvatarImage src={p.photoUrl || undefined} />
                      <AvatarFallback>{initials(p.name)}</AvatarFallback>
                    </Avatar>
                    <span className="text-sm">{p.name}</span>
                  </div>
                ))}
              </div>
              <div>
                <p className="text-sm font-semibold mb-2">
                  Not seen ({receiptsFor(seenFor, chat.active).unseen.length})
                </p>
                {receiptsFor(seenFor, chat.active).unseen.map((p) => (
                  <div key={p.userId} className="flex items-center gap-2 py-1">
                    <Avatar size="sm">
                      <AvatarImage src={p.photoUrl || undefined} />
                      <AvatarFallback>{initials(p.name)}</AvatarFallback>
                    </Avatar>
                    <span className="text-sm">{p.name}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
      {preview ? (
        <div className="fixed inset-0 z-[80] bg-black/85 flex flex-col">
          <div className="flex items-center gap-3 px-4 py-3 text-white shrink-0">
            <button
              type="button"
              className="rounded-full p-2 hover:bg-white/10"
              onClick={() => {
                if (preview.src.startsWith("blob:")) URL.revokeObjectURL(preview.src);
                setPreview(null);
              }}
              aria-label="Close photo"
            >
              <X className="size-5" />
            </button>
            <p className="font-semibold truncate flex-1">{preview.alt}</p>
          </div>
          <div
            className="flex-1 overflow-auto grid place-items-center p-6"
            onClick={() => {
              if (preview.src.startsWith("blob:")) URL.revokeObjectURL(preview.src);
              setPreview(null);
            }}
          >
            <img
              src={preview.src}
              alt={preview.alt}
              onClick={(e) => e.stopPropagation()}
              className="max-w-[min(92vw,1100px)] max-h-[82vh] object-contain select-none"
            />
          </div>
        </div>
      ) : null}
    </div>
  );
}
