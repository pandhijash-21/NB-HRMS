"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import {
  Search,
  Plus,
  Send,
  Paperclip,
  Users,
  MessageSquare,
  Smile,
} from "lucide-react";
import { useChat, type ChatChannel, type ChatMessage, type CollabProfile } from "@/lib/hooks/useChat";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { PhotoLightbox } from "@/components/ui/photo-lightbox";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
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

export function ChatApp() {
  const chat = useChat();
  const { data: session } = useSession();
  const myId = (session?.user as { id?: string })?.id;
  const [query, setQuery] = useState("");
  const [draft, setDraft] = useState("");
  const [files, setFiles] = useState<File[]>([]);
  const [showNew, setShowNew] = useState<"dm" | "group" | null>(null);
  const [peopleQ, setPeopleQ] = useState("");
  const [picked, setPicked] = useState<CollabProfile[]>([]);
  const [groupName, setGroupName] = useState("");
  const [mobilePane, setMobilePane] = useState<"list" | "thread">("list");
  const [emojiOpen, setEmojiOpen] = useState(false);
  const [reactFor, setReactFor] = useState<ChatMessage | null>(null);
  const [seenFor, setSeenFor] = useState<ChatMessage | null>(null);
  const [mentionSel, setMentionSel] = useState(0);
  const mentionQ = mentionQuery(draft);
  const mentionHits = mentionChoices(chat.active, myId, mentionQ);

  useEffect(() => {
    setMentionSel(0);
  }, [mentionQ, chat.active?.id]);

  function applyMention(insert: string) {
    setDraft((prev) => prev.replace(/@([^\s@]*)$/, insert));
  }

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key !== "Escape") return;
      if (reactFor || seenFor || showNew) return;
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
  }, [chat.activeId, chat.setActiveId, reactFor, seenFor, showNew, mentionHits.length]);

  async function openAttachment(id?: string, fallback?: string | null) {
    try {
      const url = id ? await chat.attachmentUrl(id) : fallback;
      if (!url) return;
      window.open(url, "_blank", "noopener,noreferrer");
    } catch {
      if (fallback) window.open(fallback, "_blank", "noopener,noreferrer");
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
    await chat.send(text, files);
    setDraft("");
    setFiles([]);
  }

  return (
    <div className="h-full grid grid-cols-1 md:grid-cols-[320px_1fr] min-h-0">
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
                    <PhotoLightbox src={c.avatarUrl || other?.photoUrl} alt={title}>
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
                      {c.lastMessage?.content || (c.lastMessage?.hasAttachment ? "Attachment" : "No messages yet")}
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
          "flex flex-col min-h-0 bg-background",
          mobilePane === "list" && "hidden md:flex",
        )}
      >
        {chat.active ? (
          <>
            <div className="h-14 border-b border-border/60 px-4 flex items-center gap-3">
              <button className="md:hidden text-sm text-primary" onClick={() => setMobilePane("list")}>
                Back
              </button>
              <PhotoLightbox src={chat.active.avatarUrl} alt={chat.active.name}>
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
                      <div
                        onContextMenu={(e) => {
                          if (m.deletedAt) return;
                          e.preventDefault();
                          setReactFor(m);
                        }}
                        onPointerDown={(e) => {
                          if (m.deletedAt || e.pointerType !== "touch") return;
                          const node = e.currentTarget;
                          const t = window.setTimeout(() => setReactFor(m), 450);
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
                        {m.attachments.map((a) => (
                          <button
                            key={a.id}
                            type="button"
                            onClick={() => void openAttachment(a.id, a.fileUrl)}
                            className="mt-1 flex items-center gap-2 text-xs underline"
                          >
                            <Paperclip className="size-3" />
                            {a.fileName}
                          </button>
                        ))}
                      </div>
                      {m.reactions.length > 0 && (
                        <div className="flex flex-wrap gap-1 mt-1 px-1">
                          {m.reactions.map((r) => (
                            <button
                              key={r.emoji}
                              onClick={() => chat.react(m.id, r.emoji)}
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
            {emojiOpen && (
              <div className="max-h-48 overflow-y-auto border-t border-border/60 p-2 grid grid-cols-10 gap-1">
                {CHAT_EMOJIS.map((e, i) => (
                  <button
                    key={`${e}-${i}`}
                    type="button"
                    className="h-8 text-lg hover:bg-accent rounded"
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
              <div className="relative flex-1">
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
                <Send className="size-4" />
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

      <Dialog open={!!reactFor} onOpenChange={() => setReactFor(null)}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>React</DialogTitle>
          </DialogHeader>
          <div className="max-h-72 overflow-y-auto grid grid-cols-10 gap-1">
            {CHAT_EMOJIS.map((e, i) => (
              <button
                key={`${e}-${i}`}
                type="button"
                className="h-8 text-lg hover:bg-accent rounded"
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
    </div>
  );
}
