import { env } from '../../config/env';

export async function generateMeetingSummary(input: {
  title: string;
  agenda: string | null;
  hostName: string;
  startedAt: Date | null;
  endedAt: Date | null;
  attendees: string[];
  transcript: { who: string; at: Date; text: string; scope: string }[];
  spokenTranscript?: { who: string; at: Date; text: string }[];
}): Promise<string> {
  const durationMin =
    input.startedAt && input.endedAt
      ? Math.max(1, Math.round((+input.endedAt - +input.startedAt) / 60000))
      : null;

  const spokenText = (input.spokenTranscript ?? [])
    .map((t) => `[${t.at.toISOString()}] ${t.who}: ${t.text}`)
    .join('\n');

  const chatText = input.transcript
    .filter((t) => t.scope === 'ROOM')
    .map((t) => `[${t.at.toISOString()}] ${t.who}: ${t.text}`)
    .join('\n');

  const fallback = [
    `Meeting: ${input.title}`,
    input.agenda ? `Agenda: ${input.agenda}` : null,
    `Host: ${input.hostName}`,
    durationMin ? `Duration: ${durationMin} minutes` : null,
    `Attendees: ${input.attendees.join(', ') || 'None recorded'}`,
    '',
    'Key discussion (from spoken conversation):',
    spokenText || 'No spoken transcript was captured.',
    chatText ? `\nIn-meet chat:\n${chatText}` : null,
    '',
    'Action items: Please follow up on any commitments made during the meeting.',
  ]
    .filter(Boolean)
    .join('\n');

  if (!env.OPENAI_API_KEY) return fallback;

  try {
    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: env.OPENAI_MODEL,
        temperature: 0.3,
        messages: [
          {
            role: 'system',
            content:
              'You write concise professional meeting summaries for a CRM. Include: overview, decisions, action items (with owners if named), and open questions. Use short bullet lists. Do not invent attendees or facts. Prefer the spoken conversation transcript over in-meet chat.',
          },
          {
            role: 'user',
            content: `Title: ${input.title}\nAgenda: ${input.agenda || '(none)'}\nHost: ${input.hostName}\nDuration: ${durationMin ?? 'unknown'} min\nAttendees: ${input.attendees.join(', ')}\n\nSpoken conversation (person and time):\n${spokenText || '(empty)'}\n\nIn-meet chat:\n${chatText || '(empty)'}`,
          },
        ],
      }),
    });
    if (!res.ok) return fallback;
    const json = (await res.json()) as {
      choices?: { message?: { content?: string } }[];
    };
    return json.choices?.[0]?.message?.content?.trim() || fallback;
  } catch {
    return fallback;
  }
}
