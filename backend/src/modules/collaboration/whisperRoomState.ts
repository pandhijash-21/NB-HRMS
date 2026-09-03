/** In-memory per-meeting Whisper (live captions) switch. Default ON. */

const meetingWhisperEnabled = new Map<string, boolean>();

export function getMeetingWhisperEnabled(meetingId: string): boolean {
  if (!meetingId) return true;
  return meetingWhisperEnabled.get(meetingId) ?? true;
}

export function setMeetingWhisperEnabled(meetingId: string, enabled: boolean): boolean {
  if (!meetingId) return enabled;
  meetingWhisperEnabled.set(meetingId, enabled);
  return enabled;
}

export function clearMeetingWhisperEnabled(meetingId: string) {
  if (!meetingId) return;
  meetingWhisperEnabled.delete(meetingId);
}
