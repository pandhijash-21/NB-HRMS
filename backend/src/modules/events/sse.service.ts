import type { Response } from 'express';

type SSEClient = {
  userId: string;
  employeeId: number | null;
  role: string;
  res: Response;
};

// In-memory connected client registry
const clients = new Map<string, SSEClient>();

export const sseService = {
  add(userId: string, client: SSEClient) {
    clients.set(userId, client);
  },

  remove(userId: string) {
    clients.delete(userId);
  },

  /** Send an event to all connected admin/HR users */
  toAdmins(event: string, data: unknown) {
    const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    for (const client of clients.values()) {
      if (client.role === 'ADMIN' || client.role === 'SUPER_ADMIN' || client.role === 'HR') {
        try { client.res.write(payload); } catch { /* client disconnected */ }
      }
    }
  },

  /** Send an event to a specific employee by their employeeId */
  toEmployee(employeeId: number, event: string, data: unknown) {
    const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    for (const client of clients.values()) {
      if (client.employeeId === employeeId) {
        try { client.res.write(payload); } catch { /* client disconnected */ }
      }
    }
  },

  /** Broadcast to everyone (e.g. system announcements) */
  broadcast(event: string, data: unknown) {
    const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    for (const client of clients.values()) {
      try { client.res.write(payload); } catch { /* ignore */ }
    }
  },

  connectedCount() {
    return clients.size;
  },
};
