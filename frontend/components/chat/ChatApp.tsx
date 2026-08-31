"use client";

import { useMemo, useState } from "react";
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
                    <Avatar>
                      <AvatarImage src={c.avatarUrl || other?.photoUrl || undefined} />
                      <AvatarFallback>{initials(title)}</AvatarFallback>
                    </Avatar>
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
              <Avatar>
                <AvatarImage src={chat.active.avatarUrl || undefined} />
                <AvatarFallback>{initials(chat.active.name)}</AvatarFallback>
              </Avatar>
              <div className="min-w-0">
                <p className="font-semibold truncate">{chat.active.name}</p>
                <p className="text-xs text-muted-foreground truncate">
                  {chat.active.type === "GROUP"
                    ? `${chat.active.members.length} members`
                    : chat.typing
                      ? `${chat.typing.name} is typing…`
                      : "Direct message"}
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
                      <Avatar size="sm">
                        <AvatarImage src={m.sender?.photoUrl || undefined} />
                        <AvatarFallback>{initials(m.sender?.name)}</AvatarFallback>
                      </Avatar>
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
                        {m.deletedAt ? "This message was deleted" : m.content}
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
              <Textarea
                value={draft}
                onChange={(e) => {
                  setDraft(e.target.value);
                  chat.emitTyping();
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    submit();
                  }
                }}
                placeholder="Type a message"
                className="min-h-[44px] max-h-32"
              />
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
