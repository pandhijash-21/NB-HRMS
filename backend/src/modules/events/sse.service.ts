import type { Response } from 'express';

type SSEClient = {
  userId: string;
  employeeId: number | null;
  role: string;
  companyAdminGranted?: boolean;
  res: Response;
};

// In-memory connected client registry (user ID -> Set of SSEClient connections)
const clients = new Map<string, Set<SSEClient>>();

export const sseService = {
  add(userId: string, client: SSEClient) {
    let set = clients.get(userId);
    if (!set) {
      set = new Set<SSEClient>();
      clients.set(userId, set);
    }
    set.add(client);
  },

  remove(userId: string, client?: SSEClient) {
    if (!client) {
      clients.delete(userId);
      return;
    }
    const set = clients.get(userId);
    if (set) {
      set.delete(client);
      if (set.size === 0) {
        clients.delete(userId);
      }
    }
  },

  /** Send an event to all connected admin/HR users */
  toAdmins(event: string, data: unknown) {
    const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    for (const set of clients.values()) {
      for (const client of set) {
        const role = String(client.role ?? '').toUpperCase().replace(/[\s_]/g, '');
        if (
          ['ADMIN', 'SUPERADMIN', 'SYSTEMADMIN', 'HR', 'DEVELOPER'].includes(role) ||
          client.companyAdminGranted === true
        ) {
          try { client.res.write(payload); } catch { /* client disconnected */ }
        }
      }
    }
  },

  /** Send an event to a specific logged-in user (all their active connections) */
  toUser(userId: string, event: string, data: unknown) {
    const set = clients.get(userId);
    if (!set || set.size === 0) return;
    const json = JSON.stringify(data);
    const payload = `event: ${event}\ndata: ${json}\n\n`;
    // For session displacement, emit both colon and underscore variants and close socket
    const isDisplacement = event === 'session:displaced' || event === 'session_displaced';
    const altPayload = isDisplacement
      ? `event: ${event === 'session:displaced' ? 'session_displaced' : 'session:displaced'}\ndata: ${json}\n\n`
      : null;

    for (const client of Array.from(set)) {
      try {
        client.res.write(payload);
        if (altPayload) {
          client.res.write(altPayload);
        }
        if (isDisplacement) {
          try {
            client.res.end();
          } catch (_) {}
          set.delete(client);
        }
      } catch {
        set.delete(client);
      }
    }
    if (set.size === 0) {
      clients.delete(userId);
    }
  },

  /** Send an event to a specific employee by their employeeId */
  toEmployee(employeeId: number, event: string, data: unknown) {
    const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    for (const set of clients.values()) {
      for (const client of set) {
        if (client.employeeId === employeeId) {
          try { client.res.write(payload); } catch { /* client disconnected */ }
        }
      }
    }
  },

  /** Broadcast to everyone (e.g. system announcements) */
  broadcast(event: string, data: unknown) {
    const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    for (const set of clients.values()) {
      for (const client of set) {
        try { client.res.write(payload); } catch { /* ignore */ }
      }
    }
  },

  connectedCount() {
    let count = 0;
    for (const set of clients.values()) {
      count += set.size;
    }
    return count;
  },
};
