"use client";

import { useEffect, useRef, useCallback } from "react";
import { useSession } from "next-auth/react";

const API_URL = process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, "") ?? "http://localhost:4000/api";

type SSEHandler = (data: any) => void;

interface UseSSEOptions {
  onConnected?: (data: any) => void;
  onChangeRequestCreated?: (data: any) => void;   // admin: new pending request
  onChangeRequestApproved?: (data: any) => void;  // employee: their request approved
  onChangeRequestRejected?: (data: any) => void;  // employee: their request rejected
}

/**
 * Connects to GET /api/events/stream and dispatches typed SSE events.
 * Automatically reconnects on disconnect with exponential backoff.
 */
export function useSSE(options: UseSSEOptions) {
  const { data: session, status } = useSession();
  const esRef = useRef<EventSource | null>(null);
  const retryTimeout = useRef<NodeJS.Timeout | null>(null);
  const retryCount = useRef(0);

  const connect = useCallback(() => {
    const token = (session?.user as { token?: string })?.token;
    if (!token) return;

    const url = `${API_URL}/events/stream?token=${encodeURIComponent(token)}`;

    // Close any existing connection
    esRef.current?.close();

    const es = new EventSource(url);
    esRef.current = es;

    es.addEventListener("connected", (e) => {
      retryCount.current = 0;
      options.onConnected?.(JSON.parse(e.data));
    });

    es.addEventListener("change_request_created", (e) => {
      options.onChangeRequestCreated?.(JSON.parse(e.data));
    });

    es.addEventListener("change_request_approved", (e) => {
      options.onChangeRequestApproved?.(JSON.parse(e.data));
    });

    es.addEventListener("change_request_rejected", (e) => {
      options.onChangeRequestRejected?.(JSON.parse(e.data));
    });

    es.onerror = () => {
      es.close();
      // Exponential backoff: 2s, 4s, 8s … max 30s
      const delay = Math.min(2000 * Math.pow(2, retryCount.current), 30_000);
      retryCount.current++;
      retryTimeout.current = setTimeout(connect, delay);
    };
  }, [session?.user]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (status !== "authenticated") return;
    connect();
    return () => {
      esRef.current?.close();
      if (retryTimeout.current) clearTimeout(retryTimeout.current);
    };
  }, [status, connect]);
}
