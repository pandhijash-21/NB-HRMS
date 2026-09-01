"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import api from "@/lib/axios";
import { getCollabSocket, rememberChatChannel } from "@/lib/socket";

export type CollabProfile = {
  userId: string;
  employeeId: number | null;
  name: string;
  photoUrl: string | null;
  email: string | null;
  role: string;
  username: string | null;
  online?: boolean;
  lastReadAt?: string | null;
};

export type ChatChannel = {
  id: string;
  type: "DIRECT" | "GROUP";
  name: string | null;
  topic: string | null;
  avatarUrl: string | null;
  unread: number;
  members: CollabProfile[];
  lastMessage: {
    id: string;
    content: string | null;
    senderId: string;
    createdAt: string;
    hasAttachment: boolean;
  } | null;
};

export type ChatMessage = {
  id: string;
  channelId: string;
  senderId: string;
  sender: CollabProfile | null;
  content: string | null;
  replyToId: string | null;
  replyTo?: { id: string; senderName: string; content: string | null } | null;
  createdAt: string;
  editedAt: string | null;
  deletedAt: string | null;
  attachments: {
    id: string;
    fileName: string;
    mimeType: string;
    sizeBytes: number;
    fileUrl: string | null;
    bucketKey?: string;
    scanStatus: string;
  }[];
  reactions: {
    emoji: string;
    count: number;
    mine: boolean;
    userIds: string[];
    users?: { userId: string; name: string; photoUrl: string | null }[];
  }[];
  seenBy?: { userId: string; name: string; photoUrl: string | null }[];
  unseenBy?: { userId: string; name: string; photoUrl: string | null }[];
};

function mergeIncoming(prev: ChatMessage[], msg: ChatMessage): ChatMessage[] {
  if (prev.some((m) => m.id === msg.id)) return prev;
  const samePayload = (m: ChatMessage) =>
    m.channelId === msg.channelId &&
    (m.content ?? "") === (msg.content ?? "") &&
    (m.replyToId ?? "") === (msg.replyToId ?? "");
  if (msg.id.startsWith("local:")) {
    if (prev.some((m) => !m.id.startsWith("local:") && samePayload(m))) return prev;
    return [...prev, msg];
  }
  const localIdx = prev.findIndex((m) => m.id.startsWith("local:") && samePayload(m));
  if (localIdx >= 0) {
    const next = [...prev];
    next[localIdx] = msg;
    return next;
  }
  return [...prev, msg];
}

function unwrap<T>(res: { data: { success: boolean; data: T; error?: string } }): T {
  if (!res.data?.success) throw new Error(res.data?.error || "Request failed");
  return res.data.data;
}

export function useChat() {
  const [channels, setChannels] = useState<ChatChannel[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [directory, setDirectory] = useState<CollabProfile[]>([]);
  const [typing, setTyping] = useState<{ userId: string; name: string } | null>(null);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const typingTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const active = useMemo(
    () => channels.find((c) => c.id === activeId) ?? null,
    [channels, activeId],
  );

  const loadChannels = useCallback(async () => {
    const data = unwrap<ChatChannel[]>(await api.get("chat/channels"));
    setChannels(data);
    return data;
  }, []);

  const loadMessages = useCallback(async (channelId: string) => {
    const data = unwrap<{ items: ChatMessage[] }>(
      await api.get(`chat/channels/${channelId}/messages`),
    );
    setMessages(data.items);
    await api.post(`chat/channels/${channelId}/read`);
  }, []);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const data = await loadChannels();
        if (mounted && data[0] && !activeId) setActiveId(data[0].id);
      } catch {
        /* ignore */
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => {
      mounted = false;
    };
  }, [loadChannels, activeId]);

  useEffect(() => {
    if (!activeId) return;
    loadMessages(activeId).catch(() => {});
    let s: Awaited<ReturnType<typeof getCollabSocket>> | null = null;
    getCollabSocket().then((sock) => {
      s = sock;
      sock.emit("join_channel", activeId);
      rememberChatChannel(activeId);
      const onNew = (msg: ChatMessage) => {
        if (msg.channelId !== activeId) {
          setChannels((prev) =>
            prev.map((c) =>
              c.id === msg.channelId ? { ...c, unread: (c.unread || 0) + 1 } : c,
            ),
          );
          return;
        }
        setMessages((prev) => mergeIncoming(prev, msg));
      };
      const onUpd = (msg: ChatMessage) => {
        if (msg.channelId !== activeId) return;
        setMessages((prev) => prev.map((m) => (m.id === msg.id ? msg : m)));
      };
      const onTyping = (p: { channelId: string; userId: string; name: string }) => {
        if (p.channelId !== activeId) return;
        setTyping({ userId: p.userId, name: p.name });
        if (typingTimer.current) clearTimeout(typingTimer.current);
        typingTimer.current = setTimeout(() => setTyping(null), 2500);
      };
      const onPresence = (p: { userId: string; online: boolean }) => {
        setChannels((prev) =>
          prev.map((c) => ({
            ...c,
            members: c.members.map((m) =>
              m.userId === p.userId ? { ...m, online: p.online } : m,
            ),
          })),
        );
      };
      sock.on("new_message", onNew);
      sock.on("message_updated", onUpd);
      sock.on("user_typing", onTyping);
      sock.on("presence", onPresence);
      const onRead = (p: { channelId: string; userId: string; lastReadAt: string }) => {
        setChannels((prev) =>
          prev.map((c) =>
            c.id === p.channelId
              ? {
                  ...c,
                  members: c.members.map((m) =>
                    m.userId === p.userId ? { ...m, lastReadAt: p.lastReadAt } : m,
                  ),
                }
              : c,
          ),
        );
      };
      sock.on("channel_read", onRead);
    });
    return () => {
      s?.emit("leave_channel", activeId);
      s?.off("new_message");
      s?.off("message_updated");
      s?.off("user_typing");
      s?.off("presence");
      s?.off("channel_read");
    };
  }, [activeId, loadMessages]);

  const searchPeople = useCallback(async (q: string) => {
    const data = unwrap<CollabProfile[]>(await api.get("chat/directory", { params: { q } }));
    setDirectory(data);
    return data;
  }, []);

  const startDm = useCallback(async (userId: string) => {
    const ch = unwrap<ChatChannel>(await api.post("chat/channels/dm", { userId }));
    setChannels((prev) => [ch, ...prev.filter((c) => c.id !== ch.id)]);
    setActiveId(ch.id);
    return ch;
  }, []);

  const createGroup = useCallback(async (name: string, memberIds: string[], topic?: string) => {
    const ch = unwrap<ChatChannel>(
      await api.post("chat/channels/group", { name, memberIds, topic }),
    );
    setChannels((prev) => [ch, ...prev]);
    setActiveId(ch.id);
    return ch;
  }, []);

  const send = useCallback(
    async (content: string, files?: File[], opts?: { replyToId?: string }) => {
      if (!activeId) return;
      setSending(true);
      try {
        const attachments = [];
        if (files?.length) {
          for (const file of files) {
            const form = new FormData();
            form.append("file", file);
            const uploaded = unwrap<{
              bucketKey: string;
              fileUrl: string;
              fileName: string;
              mimeType: string;
              sizeBytes: number;
            }>(await api.post("chat/uploads", form));
            attachments.push(uploaded);
          }
        }
        const sock = await getCollabSocket();
        const replyToId = opts?.replyToId;
        if (attachments.length) {
          const msg = unwrap<ChatMessage>(
            await api.post(`chat/channels/${activeId}/messages`, {
              content,
              attachments,
              replyToId,
            }),
          );
          setMessages((prev) => mergeIncoming(prev, msg));
        } else {
          const optimistic: ChatMessage = {
            id: `local:${Date.now()}`,
            channelId: activeId,
            senderId: "",
            sender: null,
            content,
            replyToId: replyToId ?? null,
            createdAt: new Date().toISOString(),
            editedAt: null,
            deletedAt: null,
            attachments: [],
            reactions: [],
          };
          setMessages((prev) => mergeIncoming(prev, optimistic));
          sock.emit("send_message", { channelId: activeId, content, replyToId });
        }
      } finally {
        setSending(false);
      }
    },
    [activeId],
  );

  const sendToChannel = useCallback(
    async (
      channelId: string,
      payload: {
        content?: string;
        attachments?: ChatMessage["attachments"];
      },
    ) => {
      const attachments = (payload.attachments ?? [])
        .map((a) => {
          const bucketKey = a.bucketKey || a.fileUrl || "";
          const fileUrl = a.fileUrl || a.bucketKey || "";
          if (!bucketKey && !fileUrl) return null;
          return {
            bucketKey: bucketKey || fileUrl,
            fileUrl: fileUrl || bucketKey,
            fileName: a.fileName,
            mimeType: a.mimeType || "application/octet-stream",
            sizeBytes: a.sizeBytes || 0,
          };
        })
        .filter((a): a is NonNullable<typeof a> => a != null);
      const msg = unwrap<ChatMessage>(
        await api.post(`chat/channels/${channelId}/messages`, {
          content: payload.content || "",
          attachments: attachments.length ? attachments : undefined,
        }),
      );
      if (channelId === activeId) setMessages((prev) => mergeIncoming(prev, msg));
      return msg;
    },
    [activeId],
  );

  const editMessage = useCallback(async (id: string, content: string) => {
    const msg = unwrap<ChatMessage>(await api.patch(`chat/messages/${id}`, { content }));
    setMessages((prev) => prev.map((m) => (m.id === id ? msg : m)));
    return msg;
  }, []);

  const deleteMessage = useCallback(async (id: string) => {
    const msg = unwrap<ChatMessage>(await api.delete(`chat/messages/${id}`));
    setMessages((prev) => prev.map((m) => (m.id === id ? msg : m)));
    return msg;
  }, []);

  const emitTyping = useCallback(async () => {
    if (!activeId) return;
    const sock = await getCollabSocket();
    sock.emit("typing", { channelId: activeId });
  }, [activeId]);

  const react = useCallback(
    async (messageId: string, emoji: string) => {
      const sock = await getCollabSocket();
      sock.emit("react", { messageId, emoji });
    },
    [],
  );

  const attachmentUrl = useCallback(async (id: string) => {
    const data = unwrap<{ url: string | null; fileName?: string; mimeType?: string }>(
      await api.get(`chat/attachments/${id}`),
    );
    return data.url || "";
  }, []);

  const attachmentBlob = useCallback(async (id: string, download = false) => {
    const res = await api.get<Blob>(`chat/attachments/${id}/file`, {
      params: download ? { download: 1 } : undefined,
      responseType: "blob",
      timeout: 120_000,
    });
    return res.data;
  }, []);

  return {
    channels,
    active,
    activeId,
    setActiveId,
    messages,
    directory,
    typing,
    loading,
    sending,
    searchPeople,
    startDm,
    createGroup,
    send,
    sendToChannel,
    editMessage,
    deleteMessage,
    emitTyping,
    react,
    attachmentUrl,
    attachmentBlob,
    reload: loadChannels,
  };
}
