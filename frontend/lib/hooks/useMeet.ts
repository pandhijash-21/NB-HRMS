"use client";

import { useCallback, useEffect, useState } from "react";
import api from "@/lib/axios";

export type MeetingUtterance = {
  id: string;
  speakerName: string;
  speakerUserId: string | null;
  speakerParticipantId: string | null;
  spokenAt: string;
  endedAt: string | null;
  text: string;
  language: string;
};

export type MeetingPerson = {
  id: string;
  userId: string | null;
  name: string;
  photoUrl: string | null;
  email?: string | null;
  department?: string | null;
  role: string;
  isGuest: boolean;
  admission?: string;
};

export type Meeting = {
  id: string;
  code: string;
  title: string;
  agenda: string | null;
  status: "SCHEDULED" | "LIVE" | "ENDED" | "CANCELLED";
  scheduledStart: string | null;
  scheduledEnd: string | null;
  startedAt: string | null;
  endedAt: string | null;
  allowGuests: boolean;
  waitingRoom: boolean;
  recordEnabled: boolean;
  recordingUrl: string | null;
  hasRecording?: boolean;
  summaryText: string | null;
  conversationText?: string | null;
  transcriptLanguage?: string | null;
  transcriptEnabled?: boolean;
  whisperOnline?: boolean;
  utterances?: MeetingUtterance[];
  isHost: boolean;
  joinUrl: string;
  host: { userId: string; name: string; photoUrl: string | null } | null;
  participants: MeetingPerson[];
  waitingParticipants?: MeetingPerson[];
};

export type JoinPayload = {
  waiting?: boolean;
  meeting: Meeting;
  livekit?: { url: string; token: string; room: string };
  participant: MeetingPerson;
  guestToken?: string;
};

function unwrap<T>(res: { data: { success: boolean; data: T; error?: string } }): T {
  if (!res.data?.success) throw new Error(res.data?.error || "Request failed");
  return res.data.data;
}

export function meetErrorMessage(e: unknown, fallback = "Request failed") {
  if (e && typeof e === "object" && "response" in e) {
    const data = (e as { response?: { data?: { error?: string } } }).response?.data;
    if (data?.error) return data.error;
  }
  if (e instanceof Error && e.message) return e.message;
  return fallback;
}

export function useMeetings() {
  const [items, setItems] = useState<Meeting[]>([]);
  const [loading, setLoading] = useState(true);

  const reload = useCallback(async () => {
    const data = unwrap<Meeting[]>(await api.get("meetings"));
    setItems(data.filter(Boolean));
  }, []);

  useEffect(() => {
    reload()
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [reload]);

  const create = useCallback(
    async (body: {
      title: string;
      agenda?: string;
      scheduledStart?: string;
      scheduledEnd?: string;
      inviteeIds?: string[];
      instant?: boolean;
      recordEnabled?: boolean;
      waitingRoom?: boolean;
      allowGuests?: boolean;
    }) => {
      const data = unwrap<Meeting>(await api.post("meetings", body));
      await reload();
      return data;
    },
    [reload],
  );

  const join = useCallback(async (code: string) => {
    return unwrap<JoinPayload>(await api.post("meetings/join", { code }));
  }, []);

  const joinById = useCallback(async (id: string) => {
    return unwrap<JoinPayload>(await api.post(`meetings/${id}/join`));
  }, []);

  const end = useCallback(async (id: string) => {
    const data = unwrap<Meeting>(await api.post(`meetings/${id}/end`));
    await reload();
    return data;
  }, [reload]);

  const cancel = useCallback(async (id: string) => {
    await api.post(`meetings/${id}/cancel`);
    await reload();
  }, [reload]);

  return { items, loading, reload, create, join, joinById, end, cancel };
}

export async function fetchMeetingByCode(code: string) {
  return unwrap<Meeting>(await api.get(`meetings/code/${code}`));
}

export async function guestJoinMeeting(code: string, displayName: string, email?: string) {
  return unwrap<JoinPayload>(
    await api.post("meetings/guest-join", { code, displayName, email }),
  );
}

export async function guestEnterMeeting(guestToken: string) {
  return unwrap<JoinPayload>(
    await api.post("meetings/guest-enter", {}, { headers: { Authorization: `Bearer ${guestToken}` } }),
  );
}

export async function admitParticipant(meetingId: string, participantId: string) {
  return unwrap<{ meeting: Meeting; participant: MeetingPerson }>(
    await api.post(`meetings/${meetingId}/admit`, { participantId }),
  );
}

export async function denyParticipant(meetingId: string, participantId: string) {
  return unwrap<{ meeting: Meeting; participant: MeetingPerson }>(
    await api.post(`meetings/${meetingId}/deny`, { participantId }),
  );
}

export async function removeMeetingParticipant(meetingId: string, participantIdOrIdentity: string) {
  return unwrap<{ meeting: Meeting; participant: MeetingPerson; identity: string }>(
    await api.post(`meetings/${meetingId}/remove`, {
      participantId: participantIdOrIdentity.startsWith('user:') || participantIdOrIdentity.startsWith('guest:')
        ? undefined
        : participantIdOrIdentity,
      identity: participantIdOrIdentity.startsWith('user:') || participantIdOrIdentity.startsWith('guest:')
        ? participantIdOrIdentity
        : undefined,
    }),
  );
}

export async function moderateMeetingParticipant(
  meetingId: string,
  data: {
    action: 'mute_mic' | 'unmute_mic' | 'stop_video' | 'allow_video' | 'stop_screen' | 'allow_screen' | 'mute_all';
    targetIdentity?: string;
    targetParticipantId?: string;
    targetUserId?: string;
  },
) {
  return unwrap<{
    success: boolean;
    meetingId: string;
    action: string;
    targetIdentity?: string;
    targetParticipantId?: string;
    targetUserId?: string;
  }>(await api.post(`meetings/${meetingId}/moderation`, data));
}

export async function setMeetingTranscriptLanguage(id: string, language: string) {
  return unwrap<{ language: string }>(
    await api.post(`meetings/${id}/transcript-language`, { language }),
  );
}

export async function fetchSttStatus() {
  return unwrap<{ enabled: boolean; online: boolean; whisperEnabled: boolean; source: string }>(
    await api.get("meetings/stt-status"),
  );
}

export async function startRecording(id: string) {
  return unwrap<Meeting>(await api.post(`meetings/${id}/recording/start`));
}

export async function stopRecording(id: string) {
  return unwrap<Meeting>(await api.post(`meetings/${id}/recording/stop`));
}

export async function deleteRecording(id: string) {
  return unwrap<Meeting>(await api.delete(`meetings/${id}/recording`));
}

export async function listAdminMeetings() {
  return unwrap<
    {
      id: string;
      code: string;
      title: string;
      agenda: string | null;
      status: string;
      scheduledStart: string | null;
      scheduledEnd: string | null;
      startedAt: string | null;
      endedAt: string | null;
      hostName: string;
      attendeeCount: number;
      joinUrl: string;
      recordingUrl?: string | null;
      hasRecording?: boolean;
    }[]
  >(await api.get("meetings/admin"));
}
