"use client";

import { io, Socket } from "socket.io-client";
import { getSession } from "next-auth/react";

function apiOrigin() {
  const raw = process.env.NEXT_PUBLIC_API_URL || "http://127.0.0.1:4000/api";
  return raw.replace(/\/api\/?$/, "");
}

let socket: Socket | null = null;
let heartbeat: ReturnType<typeof setInterval> | null = null;

export async function getCollabSocket(guestToken?: string) {
  if (socket?.connected) return socket;
  const session = await getSession();
  const token =
    guestToken ||
    (session?.user as { token?: string })?.token ||
    (typeof window !== "undefined" ? localStorage.getItem("hrms_token") : null) ||
    "";
  socket = io(apiOrigin(), {
    path: "/socket.io",
    transports: ["websocket"],
    auth: { token },
  });
  socket.on("connect", () => {
    if (heartbeat) clearInterval(heartbeat);
    heartbeat = setInterval(() => socket?.emit("heartbeat"), 20000);
  });
  socket.on("disconnect", () => {
    if (heartbeat) {
      clearInterval(heartbeat);
      heartbeat = null;
    }
  });
  return socket;
}

export function disconnectCollabSocket() {
  if (heartbeat) clearInterval(heartbeat);
  heartbeat = null;
  socket?.disconnect();
  socket = null;
}
