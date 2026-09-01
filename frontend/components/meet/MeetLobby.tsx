"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Video, Plus, LogIn, Calendar, Copy, Radio } from "lucide-react";
import { toast } from "sonner";
import { useMeetings } from "@/lib/hooks/useMeet";
import { useChat } from "@/lib/hooks/useChat";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { cn } from "@/lib/utils";

const STATUS: Record<string, string> = {
  LIVE: "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400",
  SCHEDULED: "bg-sky-500/15 text-sky-700 dark:text-sky-400",
  ENDED: "bg-muted text-muted-foreground",
  CANCELLED: "bg-rose-500/15 text-rose-700",
};

export function MeetLobby() {
  const { items, loading, create, end } = useMeetings();
  const { searchPeople, directory } = useChat();
  const router = useRouter();
  const [code, setCode] = useState("");
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState("Team meeting");
  const [agenda, setAgenda] = useState("");
  const [when, setWhen] = useState("");
  const [inviteeIds, setInviteeIds] = useState<string[]>([]);
  const [recordEnabled, setRecordEnabled] = useState(false);
  const [waitingRoom, setWaitingRoom] = useState(true);

  const upcoming = useMemo(
    () => items.filter((m) => m.status === "SCHEDULED" || m.status === "LIVE"),
    [items],
  );
  const past = useMemo(
    () => items.filter((m) => m.status === "ENDED" || m.status === "CANCELLED"),
    [items],
  );

  async function startInstant() {
    const meeting = await create({
      title: title || "Instant meeting",
      agenda,
      instant: true,
      recordEnabled,
      waitingRoom,
    });
    router.push(`/meet/r/${meeting.code}`);
  }

  async function schedule() {
    if (!when) {
      toast.error("Pick a date and time");
      return;
    }
    const meeting = await create({
      title,
      agenda,
      scheduledStart: new Date(when).toISOString(),
      inviteeIds,
      instant: false,
      recordEnabled,
      waitingRoom,
    });
    toast.success(`Scheduled. Code ${meeting.code}`);
    setOpen(false);
  }

  return (
    <div className="h-full overflow-y-auto">
      <div className="max-w-5xl mx-auto p-4 sm:p-8 space-y-8">
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold tracking-tight">Meet</h1>
            <p className="text-sm text-muted-foreground mt-1">
              Google Meet-style rooms with a shareable code, screen share, in-meet chat, recording, and AI summary.
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button onClick={() => { setOpen(true); searchPeople(""); }}>
              <Plus className="size-4 mr-1" /> New meeting
            </Button>
          </div>
        </div>

        <div className="grid sm:grid-cols-2 gap-4">
          <div className="rounded-2xl border border-border/60 bg-card p-5 space-y-3">
            <p className="text-sm font-semibold">Start or schedule</p>
            <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Meeting title" />
            <JoinAccess waitingRoom={waitingRoom} onChange={setWaitingRoom} />
            <Button className="w-full" onClick={startInstant}>
              <Video className="size-4 mr-2" /> Start instant meeting
            </Button>
          </div>
          <div className="rounded-2xl border border-border/60 bg-card p-5 space-y-3">
            <p className="text-sm font-semibold">Join with a code</p>
            <Input
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="abc-defg-hij"
              className="font-mono"
            />
            <Button
              variant="secondary"
              className="w-full"
              onClick={async () => {
                try {
                  router.push(`/meet/r/${code.trim()}`);
                } catch (e) {
                  toast.error(e instanceof Error ? e.message : "Unable to join");
                }
              }}
            >
              <LogIn className="size-4 mr-2" /> Join
            </Button>
          </div>
        </div>

        <section>
          <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground mb-3">Upcoming & live</h2>
          {loading ? (
            <p className="text-sm text-muted-foreground">Loading…</p>
          ) : upcoming.length === 0 ? (
            <p className="text-sm text-muted-foreground">No upcoming meetings.</p>
          ) : (
            <div className="grid gap-3">
              {upcoming.map((m) => (
                <div key={m.id} className="rounded-xl border border-border/60 bg-card p-4 flex flex-col sm:flex-row sm:items-center gap-3">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <p className="font-semibold truncate">{m.title}</p>
                      <Badge className={cn("border-0", STATUS[m.status])}>{m.status}</Badge>
                    </div>
                    <p className="text-xs text-muted-foreground mt-1">
                      {m.scheduledStart ? new Date(m.scheduledStart).toLocaleString() : "Starts when you join"}
                      {m.agenda ? ` · ${m.agenda}` : ""}
                    </p>
                    <p className="text-xs font-mono mt-1">{m.code}</p>
                  </div>
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => {
                        navigator.clipboard.writeText(m.joinUrl);
                        toast.success("Invite link copied");
                      }}
                    >
                      <Copy className="size-3.5 mr-1" /> Copy link
                    </Button>
                    {m.isHost && m.status === "LIVE" && (
                      <Button
                        variant="outline"
                        size="sm"
                        className="text-rose-600 border-rose-300 hover:bg-rose-50"
                        onClick={async () => {
                          if (!window.confirm("End this meeting for everyone? The link cannot be reused.")) return;
                          try {
                            await end(m.id);
                            toast.success("Meeting ended. Nobody can rejoin this link.");
                          } catch (e) {
                            toast.error(e instanceof Error ? e.message : "Unable to end meeting");
                          }
                        }}
                      >
                        End meet
                      </Button>
                    )}
                    <Button size="sm" onClick={() => router.push(`/meet/r/${m.code}`)}>
                      {m.status === "LIVE" ? <Radio className="size-3.5 mr-1" /> : <Calendar className="size-3.5 mr-1" />}
                      {m.status === "LIVE" ? "Join live" : "Enter"}
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>

        <section>
          <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground mb-3">Past</h2>
          <div className="grid gap-3">
            {past.slice(0, 12).map((m) => (
              <div key={m.id} className="rounded-xl border border-border/50 p-4 flex flex-col sm:flex-row sm:items-center gap-3">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <p className="font-medium">{m.title}</p>
                    <Badge className={cn("border-0", STATUS[m.status])}>{m.status}</Badge>
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">
                    {m.startedAt || m.scheduledStart
                      ? new Date(m.startedAt || m.scheduledStart || "").toLocaleString()
                      : ""}
                    {m.agenda ? ` · ${m.agenda}` : ""}
                  </p>
                  {m.summaryText && (
                    <p className="text-sm mt-2 whitespace-pre-wrap text-muted-foreground line-clamp-4">
                      {m.summaryText}
                    </p>
                  )}
                </div>
                {(m.hasRecording || m.recordingUrl) && m.recordingUrl && (
                  <a
                    href={m.recordingUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center justify-center rounded-md bg-primary px-3 py-2 text-sm font-medium text-primary-foreground hover:opacity-90"
                  >
                    Watch recording
                  </a>
                )}
              </div>
            ))}
          </div>
        </section>
      </div>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Schedule a meeting</DialogTitle>
          </DialogHeader>
          <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Title" />
          <Textarea value={agenda} onChange={(e) => setAgenda(e.target.value)} placeholder="Agenda" />
          <Input type="datetime-local" value={when} onChange={(e) => setWhen(e.target.value)} />
          <Input
            placeholder="Search people to invite"
            onChange={(e) => searchPeople(e.target.value)}
          />
          <div className="max-h-40 overflow-y-auto space-y-1">
            {directory.map((p) => {
              const on = inviteeIds.includes(p.userId);
              return (
                <button
                  key={p.userId}
                  className={cn("w-full text-left text-sm px-2 py-1.5 rounded-lg hover:bg-accent", on && "bg-accent")}
                  onClick={() =>
                    setInviteeIds((prev) => (on ? prev.filter((id) => id !== p.userId) : [...prev, p.userId]))
                  }
                >
                  {p.name}
                </button>
              );
            })}
          </div>
          <label className="text-sm flex items-center gap-2">
            <input type="checkbox" checked={recordEnabled} onChange={(e) => setRecordEnabled(e.target.checked)} />
            Enable recording (host device only)
          </label>
          <JoinAccess waitingRoom={waitingRoom} onChange={setWaitingRoom} />
          <DialogFooter>
            <Button variant="outline" onClick={startInstant}>Start now</Button>
            <Button onClick={schedule}>Schedule</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

function JoinAccess({
  waitingRoom,
  onChange,
}: {
  waitingRoom: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <div className="space-y-2">
      <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Who can join</p>
      <label className="flex gap-3 rounded-xl border border-border/60 p-3 cursor-pointer has-[:checked]:border-primary has-[:checked]:bg-primary/5">
        <input
          type="radio"
          name="join-access"
          className="mt-1"
          checked={!waitingRoom}
          onChange={() => onChange(false)}
        />
        <span>
          <span className="block text-sm font-medium">Direct entry</span>
          <span className="block text-xs text-muted-foreground">Anyone with the link joins immediately.</span>
        </span>
      </label>
      <label className="flex gap-3 rounded-xl border border-border/60 p-3 cursor-pointer has-[:checked]:border-primary has-[:checked]:bg-primary/5">
        <input
          type="radio"
          name="join-access"
          className="mt-1"
          checked={waitingRoom}
          onChange={() => onChange(true)}
        />
        <span>
          <span className="block text-sm font-medium">Ask to join</span>
          <span className="block text-xs text-muted-foreground">Host admits everyone before they enter, including guests.</span>
        </span>
      </label>
    </div>
  );
}
