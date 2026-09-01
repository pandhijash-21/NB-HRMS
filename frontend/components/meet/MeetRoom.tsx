"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  Room,
  RoomEvent,
  Track,
  type Participant,
  type TrackPublication,
} from "livekit-client";
import {
  Mic,
  MicOff,
  Video,
  VideoOff,
  MonitorUp,
  PhoneOff,
  MessageSquare,
  Circle,
  Copy,
  Send,
  X,
  ShieldCheck,
  LogIn,
  Hand,
  SmilePlus,
  Maximize2,
  Minimize2,
  Captions,
  ChevronLeft,
  ChevronRight,
  Users,
  UserX,
  AudioLines,
} from "lucide-react";
import { toast } from "sonner";
import { useSession } from "next-auth/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { PhotoLightbox } from "@/components/ui/photo-lightbox";
import { cn } from "@/lib/utils";
import api from "@/lib/axios";
import { getCollabSocket } from "@/lib/socket";
import { MeetLocalRecorder } from "@/lib/meetLocalRecorder";
import {
  admitParticipant,
  denyParticipant,
  fetchMeetingByCode,
  guestEnterMeeting,
  guestJoinMeeting,
  meetErrorMessage,
  removeMeetingParticipant,
  setMeetingTranscriptLanguage,
  fetchSttStatus,
  startRecording,
  stopRecording,
  type JoinPayload,
  type Meeting,
  type MeetingPerson,
  type MeetingUtterance,
} from "@/lib/hooks/useMeet";
import { MEET_STT_LANGUAGES, MeetBhashiniStt } from "@/lib/meetBhashiniStt";

function isValidIceUrl(url: string) {
  return /^(stuns?|turns?):[^:]+:\d+(\?.*)?$/i.test(url);
}

function sanitizeRtcConfig(config?: RTCConfiguration): RTCConfiguration {
  const fallback = [{ urls: "stun:stun.l.google.com:19302" }];
  const iceServers = (config?.iceServers ?? []).flatMap((server) => {
    const urls = (Array.isArray(server.urls) ? server.urls : [server.urls]).filter(
      (url): url is string => typeof url === "string" && isValidIceUrl(url),
    );
    return urls.length ? [{ ...server, urls }] : [];
  });
  return { ...config, iceServers: iceServers.length ? iceServers : fallback };
}

function installIceSanitizer() {
  const Ctor = window.RTCPeerConnection;
  if (!Ctor || (Ctor as typeof Ctor & { __nbIceSanitized?: boolean }).__nbIceSanitized) return;
  class SanitizedPeerConnection extends Ctor {
    constructor(config?: RTCConfiguration, constraints?: unknown) {
      super(sanitizeRtcConfig(config), constraints as never);
    }
  }
  (SanitizedPeerConnection as typeof Ctor & { __nbIceSanitized?: boolean }).__nbIceSanitized = true;
  window.RTCPeerConnection = SanitizedPeerConnection;
}

type ChatRow = {
  id: string;
  senderName: string;
  senderPhotoUrl: string | null;
  senderUserId: string | null;
  senderParticipantId?: string | null;
  scope: "ROOM" | "DIRECT";
  recipientUserId: string | null;
  recipientParticipantId?: string | null;
  recipientName?: string | null;
  content: string;
  createdAt: string;
};

type ChatToast = {
  id: string;
  senderName: string;
  content: string;
  scope: "ROOM" | "DIRECT";
  recipientKey?: string;
};

type DmPeer = {
  key: string;
  name: string;
  userId: string | null;
  participantId: string | null;
  isGuest: boolean;
  role?: string;
};

function isSelfPeer(
  peer: { userId?: string | null; participantId?: string | null; id?: string },
  me: { userId?: string | null; participantId?: string | null },
) {
  const part = peer.participantId || peer.id;
  if (me.participantId && part && me.participantId === part) return true;
  if (me.userId && peer.userId && me.userId === peer.userId) return true;
  return false;
}

function chatIsMine(row: ChatRow, me: { userId?: string | null; participantId?: string | null }) {
  if (me.userId && row.senderUserId === me.userId) return true;
  if (me.participantId && row.senderParticipantId === me.participantId) return true;
  return false;
}

function chatIsForMe(row: ChatRow, me: { userId?: string | null; participantId?: string | null }) {
  if (row.scope !== "DIRECT") return true;
  if (me.userId && row.recipientUserId === me.userId) return true;
  if (me.participantId && row.recipientParticipantId === me.participantId) return true;
  return chatIsMine(row, me);
}

function dmThreadMatches(row: ChatRow, peer: DmPeer, me: { userId?: string | null; participantId?: string | null }) {
  if (row.scope !== "DIRECT") return false;
  const peerHit =
    (peer.participantId &&
      (row.senderParticipantId === peer.participantId || row.recipientParticipantId === peer.participantId)) ||
    (peer.userId && (row.senderUserId === peer.userId || row.recipientUserId === peer.userId));
  if (!peerHit) return false;
  return chatIsMine(row, me) || chatIsForMe(row, me);
}

function parseLivekitIdentity(identity: string) {
  if (identity.startsWith("user:")) return { userId: identity.slice(5), participantId: null as string | null };
  if (identity.startsWith("guest:")) return { userId: null as string | null, participantId: identity.slice(6) };
  return { userId: null as string | null, participantId: identity || null };
}

const MEET_EMOJIS = ["👍", "👏", "❤️", "😂", "🎉", "😮", "👋", "🔥"] as const;

type FloatReaction = { id: string; emoji: string; name: string };

function initials(name?: string | null) {
  return (name || "?")
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase())
    .join("");
}

function liveTrack(pub?: TrackPublication) {
  if (!pub || pub.isMuted) return undefined;
  return pub.track ?? undefined;
}

function cameraPub(p: Participant) {
  return p.getTrackPublication(Track.Source.Camera);
}

function screenPub(p: Participant) {
  return p.getTrackPublication(Track.Source.ScreenShare);
}

function isMeetGuest(identity: string) {
  return identity.startsWith("guest:");
}

function GuestBadge() {
  return (
    <span className="inline-flex shrink-0 items-center rounded px-1 py-px text-[10px] font-extrabold uppercase tracking-wide bg-amber-400 text-slate-900">
      Guest
    </span>
  );
}

function meetTileName(participant: Participant) {
  const guest = isMeetGuest(participant.identity);
  const name = (participant.name || "").trim();
  if (participant.isLocal) return "You";
  if (name) return name;
  return guest ? "Guest" : "Member";
}

function VideoPane({
  publication,
  local,
  contain,
}: {
  publication?: TrackPublication;
  local?: boolean;
  contain?: boolean;
}) {
  const el = useRef<HTMLVideoElement>(null);
  const track = liveTrack(publication);
  useEffect(() => {
    const node = el.current;
    if (!track || !node) return;
    track.attach(node);
    return () => {
      track.detach(node);
    };
  }, [track, publication?.trackSid]);

  if (!track) return null;
  return (
    <video
      ref={el}
      className={cn("h-full w-full bg-black", contain ? "object-contain" : "object-cover")}
      autoPlay
      playsInline
      muted={local}
    />
  );
}

function AudioPane({ publication }: { publication?: TrackPublication }) {
  const el = useRef<HTMLAudioElement>(null);
  const track = liveTrack(publication);
  useEffect(() => {
    const node = el.current;
    if (!track || !node) return;
    track.attach(node);
    return () => {
      track.detach(node);
    };
  }, [track, publication?.trackSid]);
  if (!track) return null;
  return <audio ref={el} autoPlay />;
}

function PersonTile({
  participant,
  photoUrl,
  compact,
  handRaised,
  canRemove,
  onRemove,
}: {
  participant: Participant;
  photoUrl?: string | null;
  compact?: boolean;
  handRaised?: boolean;
  canRemove?: boolean;
  onRemove?: () => void;
}) {
  const cam = cameraPub(participant);
  const showVideo = Boolean(liveTrack(cam));
  const guest = isMeetGuest(participant.identity);
  return (
    <div
      className={cn(
        "relative overflow-hidden rounded-2xl bg-slate-900 text-white h-full min-h-0",
        compact ? "min-h-[88px] aspect-video" : "min-h-[160px]",
      )}
    >
      {showVideo ? (
        <VideoPane publication={cam} local={participant.isLocal} />
      ) : (
        <div className="h-full w-full grid place-items-center">
          <PhotoLightbox src={photoUrl} alt={meetTileName(participant)}>
            <Avatar className={compact ? "size-10" : "size-16"}>
              <AvatarImage src={photoUrl || undefined} />
              <AvatarFallback className="text-lg">{initials(participant.name)}</AvatarFallback>
            </Avatar>
          </PhotoLightbox>
        </div>
      )}
      {handRaised && (
        <div className="absolute top-2 right-2 size-8 grid place-items-center rounded-full bg-amber-400 text-slate-900 shadow-lg">
          <Hand className="size-4" />
        </div>
      )}
      {canRemove && onRemove && (
        <button
          type="button"
          className="absolute top-2 left-2 text-[11px] bg-black/70 hover:bg-rose-600 rounded-md px-2 py-1"
          onClick={onRemove}
        >
          Remove
        </button>
      )}
      <div className="absolute bottom-2 left-2 text-xs bg-black/55 rounded-md px-2 py-0.5 flex items-center gap-1.5 max-w-[90%]">
        <span className="truncate">{meetTileName(participant)}</span>
        {guest ? <GuestBadge /> : null}
        {participant.isMicrophoneEnabled ? "" : " · muted"}
        {handRaised ? " · ✋" : ""}
      </div>
    </div>
  );
}

export function MeetRoom({ code }: { code: string }) {
  const { data: session, status } = useSession();
  const [preview, setPreview] = useState<Meeting | null>(null);
  const [guestName, setGuestName] = useState("");
  const [joinData, setJoinData] = useState<JoinPayload | null>(null);
  const [waiting, setWaiting] = useState(false);
  const [waitingFor, setWaitingFor] = useState<MeetingPerson[]>([]);
  const [myParticipantId, setMyParticipantId] = useState<string | null>(null);
  const [room, setRoom] = useState<Room | null>(null);
  const [participants, setParticipants] = useState<Participant[]>([]);
  const [mediaTick, setMediaTick] = useState(0);
  const [mic, setMic] = useState(true);
  const [cam, setCam] = useState(true);
  const [sharing, setSharing] = useState(false);
  const [recording, setRecording] = useState(false);
  const [chatOpen, setChatOpen] = useState(false);
  const [unreadChat, setUnreadChat] = useState(0);
  const [chatMode, setChatMode] = useState<"ROOM" | "DIRECT">("ROOM");
  const [dmTo, setDmTo] = useState<string>("");
  const [chatRows, setChatRows] = useState<ChatRow[]>([]);
  const [chatToasts, setChatToasts] = useState<ChatToast[]>([]);
  const [draft, setDraft] = useState("");
  const [endedSummary, setEndedSummary] = useState<string | null>(null);
  const [endedConversation, setEndedConversation] = useState<string | null>(null);
  const [captionsOn, setCaptionsOn] = useState(true);
  const [captions, setCaptions] = useState<MeetingUtterance[]>([]);
  const [transcriptLang, setTranscriptLang] = useState("en");
  const [whisperOnline, setWhisperOnline] = useState(false);
  const sttRef = useRef<MeetBhashiniStt | null>(null);
  const [handRaised, setHandRaised] = useState(false);
  const [hands, setHands] = useState<Record<string, string>>({});
  const [floatReactions, setFloatReactions] = useState<FloatReaction[]>([]);
  const [emojiOpen, setEmojiOpen] = useState(false);
  const [peopleOpen, setPeopleOpen] = useState(false);
  const [presenterIndex, setPresenterIndex] = useState(0);
  const [leaving, setLeaving] = useState(false);
  const [busyLabel, setBusyLabel] = useState<string | null>(null);
  const [shareFs, setShareFs] = useState(false);
  const shareStageRef = useRef<HTMLDivElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const localRecorderRef = useRef<MeetLocalRecorder | null>(null);
  const roomRef = useRef<Room | null>(null);
  const chatOpenRef = useRef(false);
  const chatModeRef = useRef<"ROOM" | "DIRECT">("ROOM");
  const waitingRef = useRef(false);
  const joiningRef = useRef(false);
  const participantIdRef = useRef<string | null>(null);
  const toastTimers = useRef<Record<string, number>>({});
  const meRef = useRef<{ userId: string | null; participantId: string | null }>({ userId: null, participantId: null });
  const recordingRef = useRef(false);
  chatOpenRef.current = chatOpen;
  chatModeRef.current = chatMode;
  waitingRef.current = waiting;
  recordingRef.current = recording;
  meRef.current = {
    userId: (session?.user as { id?: string } | undefined)?.id || joinData?.participant.userId || null,
    participantId: myParticipantId || joinData?.participant.id || participantIdRef.current,
  };

  const pushChatToast = (row: ChatRow) => {
    const me = meRef.current;
    if (chatIsMine(row, me)) return;
    if (row.scope === "DIRECT" && !chatIsForMe(row, me)) return;
    const chatShowingThis =
      chatOpenRef.current && (row.scope === "ROOM" ? chatModeRef.current === "ROOM" : chatModeRef.current === "DIRECT");
    if (chatShowingThis) return;
    const toast: ChatToast = {
      id: row.id,
      senderName: row.senderName,
      content: row.content,
      scope: row.scope,
      recipientKey: row.senderParticipantId || (row.senderUserId ? `user:${row.senderUserId}` : undefined),
    };
    setChatToasts((prev) => [...prev.filter((t) => t.id !== toast.id), toast].slice(-3));
    if (toastTimers.current[toast.id]) window.clearTimeout(toastTimers.current[toast.id]);
    toastTimers.current[toast.id] = window.setTimeout(() => {
      setChatToasts((prev) => prev.filter((t) => t.id !== toast.id));
      delete toastTimers.current[toast.id];
    }, 6500);
  };

  useEffect(() => {
    if (!recording || !room) return;
    localRecorderRef.current?.syncAudioFromRoom(room);
  }, [recording, room, mediaTick]);

  useEffect(() => {
    if (!room && !joinData?.meeting.id) return;
    let cancelled = false;
    const tick = async () => {
      try {
        const status = await fetchSttStatus();
        if (!cancelled) setWhisperOnline(status.online);
      } catch {
        if (!cancelled) setWhisperOnline(false);
      }
    };
    void tick();
    const id = window.setInterval(() => void tick(), 12000);
    return () => {
      cancelled = true;
      window.clearInterval(id);
    };
  }, [room, joinData?.meeting.id]);

  useEffect(() => {
    const timers = toastTimers.current;
    return () => {
      Object.values(timers).forEach((id) => window.clearTimeout(id));
      void localRecorderRef.current?.stop({ download: true });
    };
  }, []);

  const loggedIn = status === "authenticated";

  useEffect(() => {
    fetchMeetingByCode(code)
      .then(setPreview)
      .catch(() => toast.error("Meeting not found"));
  }, [code]);

  useEffect(() => {
    if (!loggedIn || room || waiting) return;
    const isHost = Boolean(preview?.isHost || preview?.host?.userId === (session?.user as { id?: string })?.id);
    if (!isHost) return;
    void joinAsMember();
    // Host opening their own link should enter, not sit in the guest lobby.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loggedIn, preview?.isHost, preview?.host?.userId, room, waiting]);

  const refreshRoom = (r: Room) => {
    setParticipants([r.localParticipant, ...Array.from(r.remoteParticipants.values())]);
    setSharing(Boolean(liveTrack(screenPub(r.localParticipant))));
    setMediaTick((n) => n + 1);
  };

  const attachMeetingSocket = async (meetingId: string, token?: string) => {
    const sock = await getCollabSocket(token);
    const join = () => sock.emit("join_meeting", meetingId);
    if (sock.connected) join();
    else sock.once("connect", join);
    sock.emit("join_meeting", meetingId);
    sock.off("meeting_chat");
    sock.off("meeting_ended");
    sock.off("recording");
    sock.off("waiting_update");
    sock.off("waiting_knock");
    sock.off("join_approved");
    sock.off("join_denied");
    sock.off("meeting_transcript");
    sock.off("meeting_transcript_lang");
    sock.on("meeting_chat", (row: ChatRow) => {
      setChatRows((prev) => (prev.some((x) => x.id === row.id) ? prev : [...prev, row]));
      if (!chatOpenRef.current) setUnreadChat((n) => n + 1);
      pushChatToast(row);
    });
    sock.on("meeting_ended", () => {
      void finishCall("This meeting has ended. The host closed the room.");
    });
    sock.on("recording", (p: { active: boolean }) => setRecording(p.active));
    sock.on("waiting_update", (p: { waiting?: MeetingPerson[] }) => {
      setWaitingFor(p.waiting ?? []);
    });
    sock.on("waiting_knock", (person: MeetingPerson) => {
      setWaitingFor((current) => {
        if (!person?.id || current.some((p) => p.id === person.id)) return current;
        return [...current, person];
      });
    });
    sock.on("join_approved", async (p: { participantId?: string }) => {
      if (!waitingRef.current) return;
      if (p.participantId && participantIdRef.current && p.participantId !== participantIdRef.current) return;
      toast.success("Host let you in");
      const stored = sessionStorage.getItem("meet_guest_token");
      try {
        const payload = stored
          ? await guestEnterMeeting(stored)
          : await api.post("meetings/join", { code }).then((r) => r.data.data as JoinPayload);
        if (!payload.waiting && payload.livekit) {
          setWaiting(false);
          waitingRef.current = false;
          await connect(payload, stored || undefined);
        }
      } catch (e) {
        toast.error(meetErrorMessage(e, "Unable to enter the meeting"));
      }
    });
    sock.on("join_denied", (p: { participantId?: string }) => {
      if (!waitingRef.current) return;
      if (p.participantId && participantIdRef.current && p.participantId !== participantIdRef.current) return;
      setWaiting(false);
      waitingRef.current = false;
      toast.error("The host declined your request to join");
    });
    sock.on("meeting_transcript", (p: { utterance?: MeetingUtterance }) => {
      if (!p.utterance?.id) return;
      setCaptions((prev) => {
        const next = [...prev.filter((row) => row.id !== p.utterance!.id), p.utterance!];
        return next.slice(-40);
      });
    });
    sock.on("meeting_transcript_lang", (p: { language?: string }) => {
      if (!p.language) return;
      setTranscriptLang(p.language);
      sttRef.current?.setLanguage(p.language);
    });
    sock.off("meeting_hand");
    sock.off("meeting_reaction");
    sock.off("meeting_removed");
    sock.on("meeting_hand", (p: { identity?: string; name?: string; raised?: boolean }) => {
      const id = p.identity || "";
      if (!id) return;
      setHands((prev) => {
        const next = { ...prev };
        if (p.raised === false) delete next[id];
        else next[id] = p.name || "Someone";
        return next;
      });
      if (id === roomRef.current?.localParticipant.identity) setHandRaised(p.raised !== false);
    });
    sock.on("meeting_reaction", (p: { emoji?: string; name?: string }) => {
      if (!p.emoji) return;
      const row: FloatReaction = {
        id: `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
        emoji: p.emoji,
        name: p.name || "Someone",
      };
      setFloatReactions((prev) => [...prev, row].slice(-12));
      window.setTimeout(() => {
        setFloatReactions((prev) => prev.filter((x) => x.id !== row.id));
      }, 2600);
    });
    sock.on("meeting_removed", async (p: { participantId?: string; identity?: string }) => {
      const mePart = participantIdRef.current;
      const meId = roomRef.current?.localParticipant.identity;
      const isMe =
        Boolean(p.participantId && mePart && p.participantId === mePart) ||
        Boolean(p.identity && meId && p.identity === meId);
      if (!isMe) return;
      toast.error("You were removed from the meeting");
      await roomRef.current?.disconnect();
      setRoom(null);
      setEndedSummary("The host removed you from this meeting.");
    });
    return sock;
  };

  async function connect(payload: JoinPayload, token?: string) {
    if (!payload.livekit) return;
    installIceSanitizer();
    await roomRef.current?.disconnect();
    const r = new Room({ adaptiveStream: true, dynacast: true });
    const bump = () => refreshRoom(r);
    r.on(RoomEvent.ParticipantConnected, bump);
    r.on(RoomEvent.ParticipantDisconnected, bump);
    r.on(RoomEvent.TrackSubscribed, bump);
    r.on(RoomEvent.TrackUnsubscribed, bump);
    r.on(RoomEvent.TrackPublished, bump);
    r.on(RoomEvent.TrackUnpublished, bump);
    r.on(RoomEvent.TrackMuted, bump);
    r.on(RoomEvent.TrackUnmuted, bump);
    r.on(RoomEvent.LocalTrackPublished, (pub) => {
      bump();
      if (pub.source === Track.Source.Microphone) sttRef.current?.attach(r);
    });
    r.on(RoomEvent.LocalTrackUnpublished, bump);
    r.on(RoomEvent.Disconnected, () => setRoom(null));
    await r.connect(payload.livekit.url, payload.livekit.token, {
      rtcConfig: {
        iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
      },
    });
    await r.localParticipant.setMicrophoneEnabled(true);
    await r.localParticipant.setCameraEnabled(true);
    roomRef.current = r;
    setRoom(r);
    refreshRoom(r);
    setJoinData(payload);
    setWaitingFor(payload.meeting.waitingParticipants ?? []);
    setRecording(false);

    await attachMeetingSocket(payload.meeting.id, token);
    const chat = await api.get(`meetings/${payload.meeting.id}/chat`, {
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    });
    if (chat.data?.success) setChatRows(chat.data.data);
    const lang = payload.meeting.transcriptLanguage || "en";
    setTranscriptLang(lang);
    setCaptions(payload.meeting.utterances ?? []);
    setWhisperOnline(Boolean(payload.meeting.whisperOnline));
    const stt = new MeetBhashiniStt();
    sttRef.current = stt;
    stt.start({ room: r, meetingId: payload.meeting.id, language: lang, token });
  }

  async function beginWait(payload: JoinPayload, token?: string) {
    setJoinData(payload);
    setWaiting(true);
    waitingRef.current = true;
    setMyParticipantId(payload.participant.id);
    participantIdRef.current = payload.participant.id;
    setWaitingFor(payload.meeting.waitingParticipants ?? []);
    await attachMeetingSocket(payload.meeting.id, token);
  }

  async function joinAsMember() {
    if (joiningRef.current || roomRef.current) return;
    joiningRef.current = true;
    try {
      const payload = await api.post("meetings/join", { code }).then((r) => r.data.data as JoinPayload);
      setMyParticipantId(payload.participant.id);
      participantIdRef.current = payload.participant.id;
      if (payload.waiting && !payload.meeting.isHost) {
        await beginWait(payload);
        return;
      }
      if (!payload.livekit?.url || !payload.livekit?.token) {
        throw new Error("Meeting room is not available yet. Try again.");
      }
      await connect(payload);
    } catch (e) {
      toast.error(meetErrorMessage(e, "Unable to join"));
    } finally {
      joiningRef.current = false;
    }
  }

  async function joinAsGuest() {
    try {
      const payload = await guestJoinMeeting(code, guestName);
      if (payload.guestToken) sessionStorage.setItem("meet_guest_token", payload.guestToken);
      setMyParticipantId(payload.participant.id);
      participantIdRef.current = payload.participant.id;
      if (payload.waiting) {
        await beginWait(payload, payload.guestToken);
        return;
      }
      if (!payload.livekit?.url || !payload.livekit?.token) {
        throw new Error("Meeting room is not available yet. Try again.");
      }
      await connect(payload, payload.guestToken);
    } catch (e) {
      toast.error(meetErrorMessage(e, "Unable to join as guest"));
    }
  }

  async function finishCall(summary: string, conversation?: string | null) {
    setLeaving(true);
    setBusyLabel("Meeting ended. Cleaning up…");
    await sttRef.current?.stop();
    sttRef.current = null;
    if (document.fullscreenElement) {
      await document.exitFullscreen().catch(() => undefined);
    }
    try {
      await Promise.race([
        roomRef.current?.disconnect() ?? Promise.resolve(),
        new Promise<void>((resolve) => window.setTimeout(resolve, 2500)),
      ]);
    } catch {
      /* hang on mobile web */
    }
    setRoom(null);
    setLeaving(false);
    setBusyLabel(null);
    setEndedSummary(summary);
    setEndedConversation(conversation?.trim() || null);
  }

  async function leave() {
    const meeting = joinData?.meeting;
    const isHostNow = meeting?.isHost || meeting?.host?.userId === (session?.user as { id?: string })?.id;
    setLeaving(true);
    setBusyLabel(isHostNow ? "Ending meeting…" : "Leaving meeting…");
    await sttRef.current?.stop();
    sttRef.current = null;
    if (recordingRef.current) {
      try {
        await localRecorderRef.current?.stop({ download: true });
      } catch {
        /* still leave */
      }
      if (meeting?.isHost) {
        try {
          await stopRecording(meeting.id);
        } catch {
          /* ignore */
        }
      }
      setRecording(false);
    }
    if (isHostNow && meeting && room) {
      try {
        const res = await api.post(`meetings/${meeting.id}/end`);
        const ended = res.data?.data as Meeting | undefined;
        await finishCall(ended?.summaryText || "Meeting ended.", ended?.conversationText);
        return;
      } catch {
        /* still disconnect */
      }
    }
    if (document.fullscreenElement) {
      await document.exitFullscreen().catch(() => undefined);
    }
    try {
      await Promise.race([
        roomRef.current?.disconnect() ?? Promise.resolve(),
        new Promise<void>((resolve) => window.setTimeout(resolve, 2500)),
      ]);
    } catch {
      /* ignore */
    }
    setRoom(null);
    setWaiting(false);
    setLeaving(false);
    setBusyLabel(null);
  }

  async function toggleShare() {
    if (!room) return;
    setBusyLabel(sharing ? "Stopping screen share…" : "Starting screen share…");
    try {
      const next = !sharing;
      await room.localParticipant.setScreenShareEnabled(next, {
        audio: true,
        resolution: { width: 1920, height: 1080, frameRate: 15 },
        contentHint: "detail",
        selfBrowserSurface: "exclude",
      });
    } catch (e) {
      toast.error(meetErrorMessage(e, "Screen share was cancelled or blocked"));
    } finally {
      setBusyLabel(null);
    }
  }

  async function sendReaction(emoji: string) {
    if (!joinData) return;
    const sock = await getCollabSocket(sessionStorage.getItem("meet_guest_token") || undefined);
    sock.emit("meeting_reaction", { meetingId: joinData.meeting.id, emoji });
    setEmojiOpen(false);
  }

  async function toggleHand() {
    if (!joinData) return;
    const next = !handRaised;
    setHandRaised(next);
    const sock = await getCollabSocket(sessionStorage.getItem("meet_guest_token") || undefined);
    sock.emit("meeting_hand", { meetingId: joinData.meeting.id, raised: next });
  }

  async function toggleShareFullscreen() {
    const node = shareStageRef.current;
    if (!node) return;
    try {
      if (!document.fullscreenElement) {
        await node.requestFullscreen();
        setShareFs(true);
        const orient = (screen as Screen & { orientation?: { lock?: (m: string) => Promise<void> } }).orientation;
        await orient?.lock?.("landscape").catch(() => undefined);
      } else {
        await document.exitFullscreen();
        setShareFs(false);
      }
    } catch {
      setShareFs((v) => !v);
    }
  }

  async function removePeer(personId: string) {
    if (!joinData) return;
    try {
      await removeMeetingParticipant(joinData.meeting.id, personId);
      toast.success("Removed from the meeting");
    } catch (e) {
      toast.error(meetErrorMessage(e, "Unable to remove"));
    }
  }

  async function toggleLocalRecording() {
    if (!joinData || !room) return;
    const start = !recording;
    if (start) {
      const ok = window.confirm(
        "Start recording on this device? Only you (the host) can record. The file downloads here when you stop — it is not saved in the cloud.",
      );
      if (!ok) return;
      setBusyLabel("Starting recording…");
      try {
        const rec = localRecorderRef.current ?? new MeetLocalRecorder();
        localRecorderRef.current = rec;
        await rec.start({ room, stage: stageRef.current, code });
        try {
          await startRecording(joinData.meeting.id);
        } catch {
          toast.message("Recording this device. Others may not see the REC indicator.");
        }
        setRecording(true);
        toast.success("Recording on this device");
      } catch (e) {
        toast.error(meetErrorMessage(e, "Could not start local recording"));
      } finally {
        setBusyLabel(null);
      }
      return;
    }
    setBusyLabel("Saving recording…");
    try {
      await localRecorderRef.current?.stop({ download: true });
      try {
        await stopRecording(joinData.meeting.id);
      } catch {
        /* indicator only */
      }
      setRecording(false);
      toast.success("Recording saved to this device");
    } catch (e) {
      toast.error(meetErrorMessage(e, "Could not stop recording"));
    } finally {
      setBusyLabel(null);
    }
  }

  async function sendChat() {
    const text = draft.trim();
    if (!text || !joinData) return;
    if (chatMode === "DIRECT" && !dmTo) {
      toast.error("Pick someone in this meeting to message");
      return;
    }
    const fromRoster = joinData.meeting.participants.find(
      (p) => p.id === dmTo || (p.userId != null && `user:${p.userId}` === dmTo),
    );
    const host = joinData.meeting.host;
    const recipientParticipantId = chatMode === "DIRECT"
      ? fromRoster?.id || (dmTo.startsWith("user:") ? undefined : dmTo)
      : undefined;
    const recipientUserId = chatMode === "DIRECT"
      ? fromRoster?.userId || (dmTo.startsWith("user:") ? dmTo.slice(5) : host?.userId && `user:${host.userId}` === dmTo ? host.userId : undefined)
      : undefined;
    const sock = await getCollabSocket(sessionStorage.getItem("meet_guest_token") || undefined);
    sock.emit("meeting_chat", {
      meetingId: joinData.meeting.id,
      content: text,
      scope: chatMode,
      recipientParticipantId,
      recipientUserId,
    });
    setDraft("");
  }

  const photos = useMemo(() => {
    const map = new Map<string, string | null>();
    joinData?.meeting.participants.forEach((p) => {
      if (p.userId) map.set(`user:${p.userId}`, p.photoUrl);
      map.set(p.name, p.photoUrl);
    });
    return map;
  }, [joinData]);

  const meIds = {
    userId: (session?.user as { id?: string } | undefined)?.id || joinData?.participant.userId || null,
    participantId: myParticipantId || joinData?.participant.id || null,
  };

  const dmPeers = useMemo(() => {
    const list: DmPeer[] = [];
    const seen = new Set<string>();
    const add = (peer: DmPeer) => {
      if (!peer.key) return;
      if (isSelfPeer(peer, meIds)) return;
      const aliases = [peer.key, peer.participantId, peer.userId ? `user:${peer.userId}` : ""]
        .filter((x): x is string => Boolean(x));
      if (aliases.some((a) => seen.has(a))) return;
      aliases.forEach((a) => seen.add(a));
      list.push(peer);
    };
    for (const p of joinData?.meeting.participants ?? []) {
      add({
        key: p.id,
        name: p.name,
        userId: p.userId,
        participantId: p.id,
        isGuest: p.isGuest,
        role: p.role,
      });
    }
    const host = joinData?.meeting.host;
    if (host?.userId) {
      add({
        key: `user:${host.userId}`,
        name: host.name,
        userId: host.userId,
        participantId: null,
        isGuest: false,
        role: "HOST",
      });
    }
    for (const p of participants) {
      if (p.isLocal) continue;
      const parsed = parseLivekitIdentity(p.identity || "");
      add({
        key: parsed.participantId || (parsed.userId ? `user:${parsed.userId}` : p.identity),
        name: p.name || (parsed.userId ? "Member" : "Guest"),
        userId: parsed.userId,
        participantId: parsed.participantId,
        isGuest: !parsed.userId,
      });
    }
    return list;
  }, [joinData, participants, myParticipantId, session]);

  useEffect(() => {
    const onFs = () => setShareFs(Boolean(document.fullscreenElement));
    document.addEventListener("fullscreenchange", onFs);
    return () => document.removeEventListener("fullscreenchange", onFs);
  }, []);

  const presenters = participants
    .map((p) => ({ participant: p, pub: screenPub(p) }))
    .filter((x) => liveTrack(x.pub));
  const presenter = presenters.length ? presenters[((presenterIndex % presenters.length) + presenters.length) % presenters.length] : undefined;
  void mediaTick;

  function rosterPerson(p: Participant) {
    const parsed = parseLivekitIdentity(p.identity || "");
    return joinData?.meeting.participants.find(
      (x) =>
        (parsed.userId && x.userId === parsed.userId) ||
        (parsed.participantId && x.id === parsed.participantId) ||
        x.name === p.name,
    );
  }

  const gridCols =
    participants.length <= 1
      ? "grid-cols-1"
      : participants.length === 2
        ? "grid-cols-1 sm:grid-cols-2"
        : participants.length <= 4
          ? "grid-cols-2"
          : participants.length <= 9
            ? "grid-cols-2 lg:grid-cols-3"
            : "grid-cols-2 lg:grid-cols-3 xl:grid-cols-4";

  if (leaving && !endedSummary) {
    return (
      <div className="h-full grid place-items-center bg-slate-950 text-white p-8">
        <div className="w-full max-w-md space-y-4 text-center">
          <div className="h-1.5 w-full overflow-hidden rounded-full bg-white/10">
            <div className="h-full w-1/2 animate-pulse rounded-full bg-amber-400" />
          </div>
          <p className="text-lg font-semibold">{busyLabel || "Leaving meeting…"}</p>
          <p className="text-sm text-white/60">Please wait while this device disconnects.</p>
        </div>
      </div>
    );
  }

  if (endedSummary) {
    return (
      <div className="h-full overflow-y-auto p-4 sm:p-6 max-w-3xl mx-auto space-y-4">
        <h1 className="text-2xl font-bold">Meeting ended</h1>
        <p className="text-sm text-muted-foreground">
          Notes were emailed to the host and attendees (when SMTP is configured).
        </p>
        <section className="space-y-2">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">AI summary</h2>
          <pre className="whitespace-pre-wrap rounded-xl border bg-card p-4 text-sm">{endedSummary}</pre>
        </section>
        {endedConversation && (
          <section className="space-y-2">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
              Conversation (person & time)
            </h2>
            <pre className="whitespace-pre-wrap rounded-xl border bg-card p-4 text-sm">{endedConversation}</pre>
          </section>
        )}
      </div>
    );
  }

  if (waiting && !room) {
    return (
      <div className="h-full grid place-items-center p-6 bg-slate-950 text-white">
        <div className="w-full max-w-md rounded-2xl border border-white/10 bg-slate-900 p-8 space-y-4 text-center">
          <ShieldCheck className="size-10 mx-auto text-sky-400" />
          <h1 className="text-xl font-bold">Asking to join</h1>
          <p className="text-sm text-white/70">
            {joinData?.meeting.title || preview?.title || "This meeting"} requires host approval. You will enter as soon as they let you in.
          </p>
          <p className="font-mono text-sm text-white/50">{code}</p>
          <Button variant="secondary" onClick={() => setWaiting(false)}>Cancel</Button>
        </div>
      </div>
    );
  }

  if (!room) {
    if (status === "loading") {
      return (
        <div className="h-full grid place-items-center p-6 text-sm text-muted-foreground">
          Opening your meeting…
        </div>
      );
    }
    const isHostPreview = Boolean(
      preview?.isHost || preview?.host?.userId === (session?.user as { id?: string })?.id,
    );
    const needsKnock = Boolean(preview?.waitingRoom && !isHostPreview);
    return (
      <div className="h-full grid place-items-center p-6">
        <div className="w-full max-w-md rounded-2xl border bg-card p-6 space-y-4">
          <h1 className="text-xl font-bold">{preview?.title || "Join meeting"}</h1>
          <p className="text-sm text-muted-foreground">{preview?.agenda || "Google Meet-style room"}</p>
          <p className="font-mono text-sm">{code}</p>
          {needsKnock && (
            <p className="text-xs rounded-lg bg-amber-500/10 text-amber-800 dark:text-amber-200 px-3 py-2">
              The host must admit you before you can join.
            </p>
          )}
          {loggedIn ? (
            <Button className="w-full" onClick={joinAsMember}>
              <LogIn className="size-4 mr-2" />{" "}
              {needsKnock ? "Ask to join" : isHostPreview ? "Join your meeting" : "Join with your account"}
            </Button>
          ) : (
            <>
              <Input placeholder="Your name" value={guestName} onChange={(e) => setGuestName(e.target.value)} />
              <Button className="w-full" onClick={joinAsGuest} disabled={guestName.trim().length < 2}>
                {needsKnock ? "Ask to join as guest" : "Join as guest"}
              </Button>
            </>
          )}
        </div>
      </div>
    );
  }

  const isHost = Boolean(joinData?.meeting.isHost);
  const canRecord = isHost;

  return (
    <div className="h-full flex flex-col bg-slate-950 text-white relative">
      <header className="min-h-12 px-3 py-2 flex flex-wrap items-center justify-between gap-2 border-b border-white/10 shrink-0">
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold truncate">{joinData?.meeting.title}</p>
          <p className="text-[11px] text-white/60 flex flex-wrap items-center gap-x-2 gap-y-1">
            <span className="font-mono">{code}</span>
            <span>
              {participants.length} in this call
            </span>
            <span
              className={cn(
                "inline-flex items-center gap-1 rounded-full border px-1.5 py-0.5",
                whisperOnline ? "border-emerald-400/40 text-emerald-300" : "border-rose-400/40 text-rose-300",
              )}
              title={whisperOnline ? "Whisper is online" : "Whisper is offline"}
            >
              <AudioLines className="size-3 shrink-0" />
              <span
                className={cn(
                  "size-1.5 rounded-full shrink-0",
                  whisperOnline ? "bg-emerald-400" : "bg-rose-400",
                )}
              />
              <span className="hidden xs:inline sm:inline">{whisperOnline ? "Whisper on" : "Whisper off"}</span>
            </span>
          </p>
        </div>
        <div className="flex items-center gap-2 flex-wrap justify-end">
          {recording && (
            <span className="text-xs text-rose-400 flex items-center gap-1">
              <Circle className="size-2 fill-current" /> REC
            </span>
          )}
          {busyLabel && (
            <span className="text-xs text-amber-200 truncate max-w-[14rem]">{busyLabel}</span>
          )}
          {sharing && <span className="text-xs text-sky-300 hidden sm:inline">You are presenting</span>}
          <Button
            size="sm"
            variant="secondary"
            onClick={() => {
              navigator.clipboard.writeText(joinData?.meeting.joinUrl || window.location.href);
              toast.success("Invite copied");
            }}
          >
            <Copy className="size-3.5 mr-1" />
            <span className="hidden sm:inline">Copy link</span>
          </Button>
        </div>
      </header>
      {busyLabel && (
        <div className="h-1 w-full overflow-hidden bg-white/10">
          <div className="h-full w-1/2 animate-pulse bg-amber-400" />
        </div>
      )}

      {isHost && waitingFor.length > 0 && (
        <div className="max-h-24 overflow-y-auto border-b border-amber-400/80 bg-[#2A1C0C] px-2.5 py-1.5 space-y-1">
          {waitingFor.map((person, i) => (
            <div key={person.id} className="flex h-9 items-center gap-2 text-sm">
              <Avatar className="size-7 shrink-0">
                {person.photoUrl ? <AvatarImage src={person.photoUrl} alt="" /> : null}
                <AvatarFallback className="bg-amber-400 text-slate-900 text-[11px] font-bold">
                  {(person.name || "?").slice(0, 1).toUpperCase()}
                </AvatarFallback>
              </Avatar>
              <p className="min-w-0 flex-1 truncate text-[13px]">
                <span className="font-extrabold text-white">{person.name}</span>
                <span className="font-medium text-amber-100/80">
                  {waitingFor.length === 1 ? " wants to join" : " waiting"}
                </span>
                {person.isGuest ? <span className="text-amber-100/80"> · Guest</span> : null}
              </p>
              {i === 0 && waitingFor.length > 1 ? (
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-8 px-2 text-xs font-extrabold text-amber-300 hover:text-amber-200"
                  onClick={async () => {
                    if (!joinData) return;
                    for (const p of waitingFor) {
                      await admitParticipant(joinData.meeting.id, p.id);
                    }
                  }}
                >
                  Admit all
                </Button>
              ) : null}
              <Button
                size="sm"
                variant="ghost"
                className="h-8 px-2 text-xs font-bold text-red-400 hover:text-red-300"
                onClick={async () => {
                  if (!joinData) return;
                  await denyParticipant(joinData.meeting.id, person.id);
                }}
              >
                Deny
              </Button>
              <Button
                size="sm"
                className="h-8 bg-amber-400 px-3 text-xs font-extrabold text-slate-900 hover:bg-amber-300"
                onClick={async () => {
                  if (!joinData) return;
                  await admitParticipant(joinData.meeting.id, person.id);
                }}
              >
                Admit
              </Button>
            </div>
          ))}
        </div>
      )}

      <div className="flex-1 min-h-0 relative" ref={stageRef}>
        <div className="h-full flex flex-col p-3 gap-3">
          {presenter ? (
            <div className="flex-1 min-h-0 flex flex-col md:flex-row gap-3">
              <div className="flex-1 min-h-0 flex flex-col gap-2">
                {presenters.length > 1 && (
                  <div className="shrink-0 flex gap-2 overflow-x-auto pb-1">
                    {presenters.map((row, i) => {
                      const selected = row.participant.identity === presenter.participant.identity;
                      return (
                        <button
                          key={row.participant.identity}
                          type="button"
                          className={cn(
                            "relative h-16 w-28 shrink-0 overflow-hidden rounded-lg border-2",
                            selected ? "border-amber-400" : "border-white/20",
                          )}
                          onClick={() => setPresenterIndex(i)}
                          title={meetTileName(row.participant)}
                        >
                          <VideoPane publication={row.pub} local={row.participant.isLocal} contain />
                          <span className="absolute inset-x-0 bottom-0 bg-black/60 text-[10px] truncate px-1 py-0.5">
                            {row.participant.isLocal ? "Your screen" : meetTileName(row.participant)}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                )}
              <div
                ref={shareStageRef}
                className={cn(
                  "flex-1 min-h-0 rounded-2xl overflow-hidden bg-black relative meet-share-stage",
                  shareFs && "meet-share-fs",
                )}
              >
                <VideoPane publication={presenter.pub} local={presenter.participant.isLocal} contain />
                <AudioPane publication={presenter.participant.getTrackPublication(Track.Source.ScreenShareAudio)} />
                <div className="absolute top-3 left-3 text-xs bg-black/60 rounded-md px-2 py-1">
                  {presenter.participant.isLocal
                    ? "You are presenting — others can see this screen"
                    : `${meetTileName(presenter.participant)}${isMeetGuest(presenter.participant.identity) ? " (Guest)" : ""} is presenting`}
                  {presenters.length > 1 ? ` (${(presenterIndex % presenters.length) + 1}/${presenters.length})` : ""}
                </div>
                {presenters.length > 1 && (
                  <>
                    <button
                      type="button"
                      className="absolute left-2 top-1/2 -translate-y-1/2 size-10 rounded-full bg-black/65 text-white grid place-items-center"
                      onClick={() => setPresenterIndex((n) => n - 1)}
                      title="Previous screen"
                    >
                      <ChevronLeft className="size-5" />
                    </button>
                    <button
                      type="button"
                      className="absolute right-2 top-1/2 -translate-y-1/2 size-10 rounded-full bg-black/65 text-white grid place-items-center"
                      onClick={() => setPresenterIndex((n) => n + 1)}
                      title="Next screen"
                    >
                      <ChevronRight className="size-5" />
                    </button>
                  </>
                )}
                <Button
                  size="icon"
                  variant="secondary"
                  className="absolute bottom-3 right-3"
                  title={shareFs ? "Exit full screen" : "Full screen"}
                  onClick={toggleShareFullscreen}
                >
                  {shareFs ? <Minimize2 className="size-4" /> : <Maximize2 className="size-4" />}
                </Button>
              </div>
              </div>
              <div className="h-28 shrink-0 flex gap-2 overflow-x-auto md:h-auto md:w-52 md:flex-col md:overflow-y-auto">
                {participants.map((p) => {
                  const person = rosterPerson(p);
                  return (
                    <div key={p.identity} className="w-44 shrink-0 md:w-full">
                      <PersonTile
                        compact
                        participant={p}
                        photoUrl={photos.get(p.identity) || photos.get(p.name || "") || null}
                        handRaised={Boolean(hands[p.identity])}
                        canRemove={isHost && !p.isLocal && Boolean(person?.id)}
                        onRemove={person?.id ? () => void removePeer(person.id) : undefined}
                      />
                    </div>
                  );
                })}
              </div>
            </div>
          ) : (
            <div
              className={cn(
                "flex-1 min-h-0 p-4",
                participants.length <= 1
                  ? "grid place-items-center"
                  : cn("grid gap-3 auto-rows-fr content-center", gridCols),
              )}
            >
              {participants.map((p) => {
                const person = rosterPerson(p);
                return (
                  <div
                    key={p.identity}
                    className={cn(
                      "min-h-0",
                      participants.length <= 1
                        ? "h-full max-h-full w-auto max-w-full aspect-video"
                        : "h-full w-full",
                    )}
                  >
                    <PersonTile
                      participant={p}
                      photoUrl={photos.get(p.identity) || photos.get(p.name || "") || null}
                      handRaised={Boolean(hands[p.identity])}
                      canRemove={isHost && !p.isLocal && Boolean(person?.id)}
                      onRemove={person?.id ? () => void removePeer(person.id) : undefined}
                    />
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {chatToasts.length > 0 && (
          <div className="pointer-events-none absolute bottom-4 left-3 z-10 flex w-[min(100%-1.5rem,20rem)] flex-col gap-2">
            {chatToasts.map((t) => (
              <button
                key={t.id}
                type="button"
                className="meet-chat-toast pointer-events-auto text-left rounded-xl bg-zinc-800/92 backdrop-blur-md px-3.5 py-2.5 shadow-2xl border border-white/10"
                onClick={() => {
                  setChatOpen(true);
                  setUnreadChat(0);
                  setChatMode(t.scope);
                  if (t.scope === "DIRECT" && t.recipientKey) setDmTo(t.recipientKey);
                  setChatToasts((prev) => prev.filter((x) => x.id !== t.id));
                }}
              >
                <p className="text-[11px] font-semibold text-sky-300 truncate">
                  {t.senderName}
                  {t.scope === "DIRECT" ? " · Direct message" : ""}
                </p>
                <p className="text-sm text-white/95 line-clamp-2 leading-snug mt-0.5">{t.content}</p>
              </button>
            ))}
          </div>
        )}

        {chatOpen && (
          <aside className="absolute inset-y-0 right-0 w-full max-w-sm border-l border-white/10 bg-slate-900/95 backdrop-blur flex flex-col z-20 shadow-2xl">
            <div className="p-2 flex items-center gap-1 border-b border-white/10">
              <Button size="sm" variant={chatMode === "ROOM" ? "default" : "secondary"} onClick={() => setChatMode("ROOM")}>
                Everyone
              </Button>
              <Button size="sm" variant={chatMode === "DIRECT" ? "default" : "secondary"} onClick={() => setChatMode("DIRECT")}>
                Direct
              </Button>
              <Button size="icon" variant="ghost" className="ml-auto text-white" onClick={() => setChatOpen(false)}>
                <X className="size-4" />
              </Button>
            </div>
            {chatMode === "DIRECT" && (
              <select
                className="mx-2 mt-2 mb-1 bg-slate-800 rounded-md text-sm p-2"
                value={dmTo}
                onChange={(e) => setDmTo(e.target.value)}
              >
                <option value="">Pick anyone in this meeting</option>
                {dmPeers.map((p) => (
                  <option key={p.key} value={p.key}>
                    {p.name}
                    {p.role === "HOST" ? " (Host)" : p.isGuest ? " (Guest)" : ""}
                  </option>
                ))}
              </select>
            )}
            <div className="flex-1 overflow-y-auto p-3 space-y-2">
              {chatMode === "DIRECT" && !dmTo && (
                <p className="text-xs text-white/50">
                  {dmPeers.length
                    ? "Choose the host, a teammate, or a guest to message them privately."
                    : "No one else is in this meeting yet."}
                </p>
              )}
              {chatRows
                .filter((r) => {
                  if (chatMode === "ROOM") return r.scope === "ROOM";
                  if (r.scope !== "DIRECT") return false;
                  if (!dmTo) return true;
                  const peer = dmPeers.find((p) => p.key === dmTo);
                  return peer ? dmThreadMatches(r, peer, meIds) : true;
                })
                .map((r) => (
                  <div key={r.id} className="text-sm">
                    <p className="text-[11px] text-white/50">
                      {chatIsMine(r, meIds) ? "You" : r.senderName}
                      {r.scope === "DIRECT" && r.recipientName
                        ? chatIsMine(r, meIds)
                          ? ` → ${r.recipientName}`
                          : " → you"
                        : ""}
                    </p>
                    <p>{r.content}</p>
                  </div>
                ))}
            </div>
            <form
              className="p-2 flex gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                sendChat();
              }}
            >
              <Input
                className="bg-slate-800 border-white/10"
                placeholder={
                  chatMode === "DIRECT" && !dmTo ? "Pick someone first" : "Send a message"
                }
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    void sendChat();
                  }
                }}
                disabled={chatMode === "DIRECT" && !dmTo}
              />
              <Button type="submit" size="icon">
                <Send className="size-4" />
              </Button>
            </form>
          </aside>
        )}

        {peopleOpen && (
          <aside className="absolute inset-y-0 right-0 w-full max-w-sm border-l border-white/10 bg-slate-900/95 backdrop-blur flex flex-col z-20 shadow-2xl">
            <div className="p-3 flex items-center gap-2 border-b border-white/10">
              <p className="font-semibold text-sm">People</p>
              <Button size="icon" variant="ghost" className="ml-auto text-white" onClick={() => setPeopleOpen(false)}>
                <X className="size-4" />
              </Button>
            </div>
            <div className="flex-1 overflow-y-auto p-3 space-y-2">
              {participants.map((p) => {
                const person = rosterPerson(p);
                return (
                  <div key={p.identity} className="flex items-center gap-2 text-sm">
                    <Avatar className="size-8">
                      <AvatarImage src={photos.get(p.identity) || photos.get(p.name || "") || undefined} />
                      <AvatarFallback>{initials(p.name)}</AvatarFallback>
                    </Avatar>
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-medium flex items-center gap-1.5">
                        <span className="truncate">{meetTileName(p)}</span>
                        {isMeetGuest(p.identity) ? <GuestBadge /> : null}
                        {hands[p.identity] ? " ✋" : ""}
                      </p>
                      <p className="text-[11px] text-white/50">
                        {person?.role === "HOST" ? "Host" : person?.isGuest ? "Guest" : "In this call"}
                      </p>
                    </div>
                    {isHost && !p.isLocal && person?.id && (
                      <Button size="sm" variant="destructive" onClick={() => void removePeer(person.id)}>
                        <UserX className="size-3.5 mr-1" /> Remove
                      </Button>
                    )}
                  </div>
                );
              })}
            </div>
          </aside>
        )}

        {captionsOn && captions.length > 0 && (
          <div className="pointer-events-none absolute inset-x-0 bottom-4 z-10 px-3 sm:px-6">
            <div className="mx-auto max-w-3xl rounded-xl bg-black/70 px-3 py-2 text-white shadow-lg backdrop-blur">
              {captions.slice(-3).map((row) => (
                <p key={row.id} className="text-xs sm:text-sm leading-snug">
                  <span className="text-white/55 mr-1">
                    {new Date(row.spokenAt).toLocaleTimeString("en-IN", {
                      hour: "numeric",
                      minute: "2-digit",
                      second: "2-digit",
                    })}
                  </span>
                  <span className="font-semibold mr-1">{row.speakerName}:</span>
                  <span>{row.text}</span>
                </p>
              ))}
            </div>
          </div>
        )}

        {floatReactions.length > 0 && (
          <div className="pointer-events-none absolute bottom-6 left-1/2 -translate-x-1/2 z-10 flex gap-3">
            {floatReactions.map((r) => (
              <div key={r.id} className="meet-reaction-float text-center">
                <div className="text-3xl drop-shadow-lg">{r.emoji}</div>
                <p className="text-[10px] text-white/80 truncate max-w-20">{r.name}</p>
              </div>
            ))}
          </div>
        )}
      </div>

      <footer className="min-h-16 border-t border-white/10 flex flex-wrap items-center justify-center gap-2 px-3 py-2 shrink-0 relative overflow-x-auto">
        <Button
          size="icon"
          variant={mic ? "secondary" : "destructive"}
          onClick={async () => {
            const next = !mic;
            await room.localParticipant.setMicrophoneEnabled(next);
            setMic(next);
            sttRef.current?.setMicEnabled(next);
            if (next) sttRef.current?.attach(room);
          }}
        >
          {mic ? <Mic className="size-4" /> : <MicOff className="size-4" />}
        </Button>
        <Button
          size="icon"
          variant={cam ? "secondary" : "destructive"}
          onClick={async () => {
            const next = !cam;
            await room.localParticipant.setCameraEnabled(next);
            setCam(next);
          }}
        >
          {cam ? <Video className="size-4" /> : <VideoOff className="size-4" />}
        </Button>
        <Button size="icon" variant={sharing ? "default" : "secondary"} onClick={toggleShare} title="Share screen">
          <MonitorUp className="size-4" />
        </Button>
        <div className="relative">
          <Button
            size="icon"
            variant={emojiOpen ? "default" : "secondary"}
            title="Send a reaction"
            onClick={() => setEmojiOpen((v) => !v)}
          >
            <SmilePlus className="size-4" />
          </Button>
          {emojiOpen && (
            <div className="absolute bottom-14 left-1/2 -translate-x-1/2 flex gap-1 rounded-full bg-slate-800 px-2 py-1.5 shadow-xl border border-white/10">
              {MEET_EMOJIS.map((emoji) => (
                <button
                  key={emoji}
                  type="button"
                  className="size-9 text-xl hover:scale-125 transition-transform"
                  onClick={() => void sendReaction(emoji)}
                >
                  {emoji}
                </button>
              ))}
            </div>
          )}
        </div>
        <Button
          size="icon"
          variant={handRaised ? "default" : "secondary"}
          title={handRaised ? "Lower hand" : "Raise hand"}
          onClick={() => void toggleHand()}
        >
          <Hand className="size-4" />
        </Button>
        <Button
          size="icon"
          variant={chatOpen ? "default" : "secondary"}
          className="relative"
          onClick={() => {
            setChatOpen((v) => !v);
            setPeopleOpen(false);
            setUnreadChat(0);
          }}
        >
          <MessageSquare className="size-4" />
          {!chatOpen && unreadChat > 0 && (
            <span className="absolute -top-1 -right-1 min-w-4 h-4 rounded-full bg-rose-500 text-[10px] grid place-items-center px-1">
              {unreadChat}
            </span>
          )}
        </Button>
        <Button
          size="icon"
          variant={peopleOpen ? "default" : "secondary"}
          title="People"
          onClick={() => {
            setPeopleOpen((v) => !v);
            setChatOpen(false);
          }}
        >
          <Users className="size-4" />
        </Button>
        <Button
          size="icon"
          variant={captionsOn ? "default" : "secondary"}
          title={captionsOn ? "Hide captions" : "Show captions"}
          className="relative"
          onClick={() => setCaptionsOn((v) => !v)}
        >
          <Captions className="size-4" />
          <span
            className={cn(
              "absolute top-1 right-1 size-1.5 rounded-full",
              whisperOnline ? "bg-emerald-400" : "bg-rose-400",
            )}
            title={whisperOnline ? "Whisper online" : "Whisper offline"}
          />
        </Button>
        {isHost && (
          <select
            className="h-9 max-w-[7.5rem] rounded-md border border-white/15 bg-slate-800 px-2 text-xs text-white"
            value={transcriptLang}
            title="Speech-to-text language"
            onChange={(e) => {
              const language = e.target.value;
              setTranscriptLang(language);
              sttRef.current?.setLanguage(language);
              if (joinData?.meeting.id) {
                void setMeetingTranscriptLanguage(joinData.meeting.id, language).catch(() => undefined);
              }
            }}
          >
            {MEET_STT_LANGUAGES.map((lang) => (
              <option key={lang.code} value={lang.code}>
                {lang.label}
              </option>
            ))}
          </select>
        )}
        {canRecord && (
          <Button
            variant={recording ? "destructive" : "secondary"}
            onClick={() => void toggleLocalRecording()}
          >
            <Circle className={cn("size-3 mr-1", recording && "fill-current")} />
            {recording ? "Stop rec" : "Record"}
          </Button>
        )}
        <Button variant="destructive" onClick={leave}>
          <PhoneOff className="size-4 mr-1" /> {isHost ? "End" : "Leave"}
        </Button>
      </footer>
    </div>
  );
}
