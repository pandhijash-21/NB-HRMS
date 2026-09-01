"use client";

import { useEffect, useState } from "react";
import { deleteRecording, listAdminMeetings } from "@/lib/hooks/useMeet";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";

const STATUS: Record<string, string> = {
  LIVE: "bg-emerald-100 text-emerald-700",
  SCHEDULED: "bg-sky-100 text-sky-700",
  ENDED: "bg-slate-100 text-slate-600",
  CANCELLED: "bg-rose-100 text-rose-700",
};

export default function AdminMeetingsPage() {
  const [rows, setRows] = useState<Awaited<ReturnType<typeof listAdminMeetings>>>([]);
  const [q, setQ] = useState("");
  const [tab, setTab] = useState<"upcoming" | "past">("upcoming");
  const [busyId, setBusyId] = useState<string | null>(null);

  function reload() {
    listAdminMeetings().then(setRows).catch(() => setRows([]));
  }

  useEffect(() => {
    reload();
  }, []);

  async function onDelete(id: string, title: string) {
    if (!window.confirm(`Delete the recording for “${title}”? This cannot be undone.`)) return;
    setBusyId(id);
    try {
      await deleteRecording(id);
      reload();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Could not delete recording");
    } finally {
      setBusyId(null);
    }
  }

  const filtered = rows.filter((r) => {
    const hay = `${r.title} ${r.agenda || ""} ${r.hostName} ${r.code}`.toLowerCase();
    if (q && !hay.includes(q.toLowerCase())) return false;
    const upcoming = r.status === "SCHEDULED" || r.status === "LIVE";
    return tab === "upcoming" ? upcoming : !upcoming;
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">All meetings</h1>
        <p className="text-sm text-muted-foreground mt-1">
          Scheduled and past meetings across the organisation — date, time, agenda, host.
        </p>
      </div>
      <div className="flex flex-col sm:flex-row gap-3">
        <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search title, agenda, host, code" />
        <div className="flex gap-2">
          <button
            className={`px-3 py-2 rounded-lg text-sm font-medium ${tab === "upcoming" ? "bg-primary text-primary-foreground" : "bg-muted"}`}
            onClick={() => setTab("upcoming")}
          >
            Scheduled / live
          </button>
          <button
            className={`px-3 py-2 rounded-lg text-sm font-medium ${tab === "past" ? "bg-primary text-primary-foreground" : "bg-muted"}`}
            onClick={() => setTab("past")}
          >
            Past
          </button>
        </div>
      </div>
      <div className="overflow-x-auto rounded-xl border bg-card">
        <table className="w-full text-sm">
          <thead className="bg-muted/50 text-left">
            <tr>
              <th className="p-3">Date & time</th>
              <th className="p-3">Title / agenda</th>
              <th className="p-3">Host</th>
              <th className="p-3">Code</th>
              <th className="p-3">Status</th>
              <th className="p-3">Attendees</th>
              <th className="p-3">Recording</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((r) => (
              <tr key={r.id} className="border-t">
                <td className="p-3 whitespace-nowrap">
                  {r.scheduledStart
                    ? new Date(r.scheduledStart).toLocaleString()
                    : r.startedAt
                      ? new Date(r.startedAt).toLocaleString()
                      : "—"}
                </td>
                <td className="p-3">
                  <p className="font-medium">{r.title}</p>
                  {r.agenda && <p className="text-xs text-muted-foreground line-clamp-2">{r.agenda}</p>}
                </td>
                <td className="p-3">{r.hostName}</td>
                <td className="p-3 font-mono text-xs">{r.code}</td>
                <td className="p-3">
                  <Badge className={STATUS[r.status] || ""}>{r.status}</Badge>
                </td>
                <td className="p-3">{r.attendeeCount}</td>
                <td className="p-3">
                  {r.hasRecording || r.recordingUrl ? (
                    <div className="flex items-center gap-3">
                      {r.recordingUrl ? (
                        <a href={r.recordingUrl} target="_blank" rel="noreferrer" className="text-primary font-medium hover:underline">
                          Watch
                        </a>
                      ) : (
                        <span className="text-muted-foreground">Saved</span>
                      )}
                      <button
                        type="button"
                        className="text-rose-600 hover:underline disabled:opacity-50"
                        disabled={busyId === r.id}
                        onClick={() => onDelete(r.id, r.title)}
                      >
                        {busyId === r.id ? "Deleting…" : "Delete"}
                      </button>
                    </div>
                  ) : (
                    <span className="text-muted-foreground">—</span>
                  )}
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={7} className="p-6 text-center text-muted-foreground">
                  No meetings in this view.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
