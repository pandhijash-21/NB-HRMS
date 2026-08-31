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
import {
  admitParticipant,
  denyParticipant,
  fetchMeetingByCode,
  guestEnterMeeting,
  guestJoinMeeting,
  meetErrorMessage,
  startRecording,
  stopRecording,
  type JoinPayload,
  type Meeting,
  type MeetingPerson,
} from "@/lib/hooks/useMeet";

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
  scope: "ROOM" | "DIRECT";
  recipientUserId: string | null;
  content: string;
  createdAt: string;
};

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
}: {
  participant: Participant;
  photoUrl?: string | null;
  compact?: boolean;
}) {
  const cam = cameraPub(participant);
  const showVideo = Boolean(liveTrack(cam));
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
          <PhotoLightbox src={photoUrl} alt={participant.name || "Guest"}>
            <Avatar className={compact ? "size-10" : "size-16"}>
              <AvatarImage src={photoUrl || undefined} />
              <AvatarFallback className="text-lg">{initials(participant.name)}</AvatarFallback>
            </Avatar>
          </PhotoLightbox>
        </div>
      )}
      <div className="absolute bottom-2 left-2 text-xs bg-black/55 rounded-md px-2 py-0.5">
        {participant.isLocal ? "You" : participant.name || "Guest"}
        {participant.isMicrophoneEnabled ? "" : " · muted"}
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
  const [draft, setDraft] = useState("");
  const [endedSummary, setEndedSummary] = useState<string | null>(null);
  const roomRef = useRef<Room | null>(null);
  const chatOpenRef = useRef(false);
  const waitingRef = useRef(false);
  const participantIdRef = useRef<string | null>(null);
  chatOpenRef.current = chatOpen;
  waitingRef.current = waiting;

  const loggedIn = status === "authenticated";

  useEffect(() => {
    fetchMeetingByCode(code)
      .then(setPreview)
      .catch(() => toast.error("Meeting not found"));
  }, [code]);

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
    sock.on("meeting_chat", (row: ChatRow) => {
      setChatRows((prev) => (prev.some((x) => x.id === row.id) ? prev : [...prev, row]));
      if (!chatOpenRef.current) setUnreadChat((n) => n + 1);
    });
    sock.on("meeting_ended", () => {
      toast.message("Host ended the meeting");
      void roomRef.current?.disconnect();
      setRoom(null);
      setEndedSummary("This meeting has ended. The host closed the room.");
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
    r.on(RoomEvent.LocalTrackPublished, bump);
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
    setRecording(Boolean(payload.meeting.recordEnabled));

    await attachMeetingSocket(payload.meeting.id, token);
    const chat = await api.get(`meetings/${payload.meeting.id}/chat`, {
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    });
    if (chat.data?.success) setChatRows(chat.data.data);
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
    try {
      const payload = await api.post("meetings/join", { code }).then((r) => r.data.data as JoinPayload);
      setMyParticipantId(payload.participant.id);
      participantIdRef.current = payload.participant.id;
      if (payload.waiting || !payload.livekit) {
        await beginWait(payload);
        return;
      }
      await connect(payload);
    } catch (e) {
      toast.error(meetErrorMessage(e, "Unable to join"));
    }
  }

  async function joinAsGuest() {
    try {
      const payload = await guestJoinMeeting(code, guestName);
      if (payload.guestToken) sessionStorage.setItem("meet_guest_token", payload.guestToken);
      setMyParticipantId(payload.participant.id);
      participantIdRef.current = payload.participant.id;
      if (payload.waiting || !payload.livekit) {
        await beginWait(payload, payload.guestToken);
        return;
      }
      await connect(payload, payload.guestToken);
    } catch (e) {
      toast.error(meetErrorMessage(e, "Unable to join as guest"));
    }
  }

  async function leave() {
    const meeting = joinData?.meeting;
    const isHost = meeting?.isHost || meeting?.host?.userId === (session?.user as { id?: string })?.id;
    if (isHost && meeting && room) {
      try {
        const res = await api.post(`meetings/${meeting.id}/end`);
        setEndedSummary(res.data?.data?.summaryText || "Meeting ended.");
      } catch {
        /* still disconnect */
      }
    }
    await roomRef.current?.disconnect();
    setRoom(null);
    setWaiting(false);
  }

  async function toggleShare() {
    if (!room) return;
    try {
      const next = !sharing;
      await room.localParticipant.setScreenShareEnabled(next, {
        audio: true,
        video: { cursor: "never" },
      });
    } catch (e) {
      toast.error(meetErrorMessage(e, "Screen share was cancelled or blocked"));
    }
  }

  async function sendChat() {
    const text = draft.trim();
    if (!text || !joinData) return;
    const sock = await getCollabSocket(sessionStorage.getItem("meet_guest_token") || undefined);
    sock.emit("meeting_chat", {
      meetingId: joinData.meeting.id,
      content: text,
      scope: chatMode,
      recipientUserId: chatMode === "DIRECT" ? dmTo : undefined,
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

  const presenters = participants
    .map((p) => ({ participant: p, pub: screenPub(p) }))
    .filter((x) => liveTrack(x.pub));
  const presenter = presenters[0];
  void mediaTick;

  const gridCols =
    participants.length <= 1 ? "grid-cols-1" : participants.length <= 4 ? "grid-cols-1 sm:grid-cols-2" : "grid-cols-1 sm:grid-cols-2 xl:grid-cols-3";

  if (endedSummary) {
    return (
      <div className="h-full overflow-y-auto p-6 max-w-3xl mx-auto space-y-4">
        <h1 className="text-2xl font-bold">Meeting ended</h1>
        <p className="text-sm text-muted-foreground">
          An AI summary was emailed to the host and attendees (when SMTP is configured).
        </p>
        <pre className="whitespace-pre-wrap rounded-xl border bg-card p-4 text-sm">{endedSummary}</pre>
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
    return (
      <div className="h-full grid place-items-center p-6">
        <div className="w-full max-w-md rounded-2xl border bg-card p-6 space-y-4">
          <h1 className="text-xl font-bold">{preview?.title || "Join meeting"}</h1>
          <p className="text-sm text-muted-foreground">{preview?.agenda || "Google Meet-style room"}</p>
          <p className="font-mono text-sm">{code}</p>
          {preview?.waitingRoom && (
            <p className="text-xs rounded-lg bg-amber-500/10 text-amber-800 dark:text-amber-200 px-3 py-2">
              The host must admit you before you can join.
            </p>
          )}
          {loggedIn ? (
            <Button className="w-full" onClick={joinAsMember}>
              <LogIn className="size-4 mr-2" /> {preview?.waitingRoom ? "Ask to join" : "Join with your account"}
            </Button>
          ) : (
            <>
              <Input placeholder="Your name" value={guestName} onChange={(e) => setGuestName(e.target.value)} />
              <Button className="w-full" onClick={joinAsGuest} disabled={guestName.trim().length < 2}>
                {preview?.waitingRoom ? "Ask to join as guest" : "Join as guest"}
              </Button>
            </>
          )}
        </div>
      </div>
    );
  }

  const isHost = Boolean(joinData?.meeting.isHost);
  const role = String((session?.user as { role?: string; roleName?: string } | undefined)?.roleName || (session?.user as { role?: string } | undefined)?.role || "")
    .toUpperCase()
    .replace(/\s+/g, "");
  const canRecord = isHost || ["ADMIN", "SUPERADMIN", "SYSTEMADMIN"].includes(role);

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
          </p>
        </div>
        <div className="flex items-center gap-2 flex-wrap justify-end">
          {recording && (
            <span className="text-xs text-rose-400 flex items-center gap-1">
              <Circle className="size-2 fill-current" /> REC
            </span>
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

      {isHost && waitingFor.length > 0 && (
        <div className="px-3 py-3 bg-amber-500/20 border-b-2 border-amber-400 space-y-3">
          <p className="text-sm font-bold text-amber-100">
            {waitingFor.length === 1
              ? `${waitingFor[0].name} wants to join`
              : `${waitingFor.length} people waiting to join`}
          </p>
          <p className="text-xs text-amber-100/80">They cannot enter until you admit them.</p>
          {waitingFor.map((person) => {
            const details = [
              person.isGuest ? "Guest" : null,
              person.department,
              person.email,
            ]
              .filter(Boolean)
              .join(" · ");
            return (
              <div key={person.id} className="flex items-center gap-3 text-sm flex-wrap">
                <Avatar className="size-10 shrink-0">
                  {person.photoUrl ? <AvatarImage src={person.photoUrl} alt="" /> : null}
                  <AvatarFallback className="bg-amber-400 text-slate-900 font-bold">
                    {(person.name || "?").slice(0, 1).toUpperCase()}
                  </AvatarFallback>
                </Avatar>
                <div className="flex-1 min-w-0">
                  <p className="font-semibold truncate">{person.name}</p>
                  <p className="text-xs text-amber-100/80 truncate">{details || (person.isGuest ? "Guest" : "Employee")}</p>
                </div>
                <div className="flex items-center gap-2 ml-auto">
                  <Button
                    size="sm"
                    variant="secondary"
                    onClick={async () => {
                      if (!joinData) return;
                      await denyParticipant(joinData.meeting.id, person.id);
                    }}
                  >
                    Deny
                  </Button>
                  <Button
                    size="sm"
                    className="bg-amber-400 text-slate-900 hover:bg-amber-300 font-extrabold px-5"
                    onClick={async () => {
                      if (!joinData) return;
                      await admitParticipant(joinData.meeting.id, person.id);
                    }}
                  >
                    Admit
                  </Button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <div className="flex-1 min-h-0 relative">
        <div className="h-full flex flex-col p-3 gap-3">
          {presenter ? (
            <div className="flex-1 min-h-0 flex flex-col md:flex-row gap-3">
              <div className="flex-1 min-h-0 rounded-2xl overflow-hidden bg-black relative">
                <VideoPane publication={presenter.pub} local={presenter.participant.isLocal} contain />
                <AudioPane publication={presenter.participant.getTrackPublication(Track.Source.ScreenShareAudio)} />
                <div className="absolute top-3 left-3 text-xs bg-black/60 rounded-md px-2 py-1">
                  {presenter.participant.isLocal
                    ? "You are presenting — others can see this screen"
                    : `${presenter.participant.name || "Guest"} is presenting`}
                </div>
              </div>
              <div className="h-28 shrink-0 flex gap-2 overflow-x-auto md:h-auto md:w-52 md:flex-col md:overflow-y-auto">
                {participants.map((p) => (
                  <div key={p.identity} className="w-44 shrink-0 md:w-full">
                    <PersonTile
                      compact
                      participant={p}
                      photoUrl={photos.get(p.identity) || photos.get(p.name || "") || null}
                    />
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className={cn("flex-1 min-h-0 grid gap-3 auto-rows-fr", gridCols)}>
              {participants.map((p) => (
                <PersonTile
                  key={p.identity}
                  participant={p}
                  photoUrl={photos.get(p.identity) || photos.get(p.name || "") || null}
                />
              ))}
            </div>
          )}
        </div>

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
                <option value="">Pick a teammate</option>
                {joinData?.meeting.participants
                  .filter((p) => p.userId)
                  .map((p) => (
                    <option key={p.userId!} value={p.userId!}>
                      {p.name}
                    </option>
                  ))}
              </select>
            )}
            <div className="flex-1 overflow-y-auto p-3 space-y-2">
              {chatRows
                .filter((r) => (chatMode === "ROOM" ? r.scope === "ROOM" : r.scope === "DIRECT"))
                .map((r) => (
                  <div key={r.id} className="text-sm">
                    <p className="text-[11px] text-white/50">{r.senderName}</p>
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
                placeholder="Message"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
              />
              <Button type="submit" size="icon">
                <Send className="size-4" />
              </Button>
            </form>
          </aside>
        )}
      </div>

      <footer className="h-16 border-t border-white/10 flex items-center justify-center gap-2 px-3 shrink-0">
        <Button
          size="icon"
          variant={mic ? "secondary" : "destructive"}
          onClick={async () => {
            const next = !mic;
            await room.localParticipant.setMicrophoneEnabled(next);
            setMic(next);
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
        <Button
          size="icon"
          variant={chatOpen ? "default" : "secondary"}
          className="relative"
          onClick={() => {
            setChatOpen((v) => !v);
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
        {canRecord && (
          <Button
            variant={recording ? "destructive" : "secondary"}
            onClick={async () => {
              if (!joinData) return;
              if (recording) await stopRecording(joinData.meeting.id);
              else await startRecording(joinData.meeting.id);
              setRecording((v) => !v);
            }}
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
