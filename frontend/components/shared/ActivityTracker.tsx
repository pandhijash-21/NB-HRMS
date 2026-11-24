"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import { useSession } from "next-auth/react";
import api from "@/lib/axios";

interface QueuedEvent {
  type: "USER_CLICK" | "PAGE_VIEW";
  target: string;
  screen: string;
  metadata?: string;
  reason?: string;
}

export function ActivityTracker() {
  const pathname = usePathname();
  const { data: session } = useSession();
  const queueRef = useRef<QueuedEvent[]>([]);
  const lastPathRef = useRef<string | null>(null);

  // Flush queued events to backend
  const flushQueue = async () => {
    if (!session?.user?.id) return;
    if (queueRef.current.length === 0) return;

    const eventsToSend = [...queueRef.current];
    queueRef.current = [];

    try {
      await api.post("/api/admin/audit-logs/track", { events: eventsToSend });
    } catch {
      // Re-queue up to 20 events on failure, drop rest to avoid unbounded memory
      if (eventsToSend.length > 0 && queueRef.current.length < 50) {
        queueRef.current.unshift(...eventsToSend.slice(0, 20));
      }
    }
  };

  // Track Page Views
  useEffect(() => {
    if (!pathname || !session?.user?.id) return;
    if (lastPathRef.current === pathname) return;
    lastPathRef.current = pathname;

    queueRef.current.push({
      type: "PAGE_VIEW",
      target: `Visited ${pathname}`,
      screen: pathname,
      metadata: `referrer: ${typeof document !== "undefined" ? document.referrer || "direct" : "direct"}`,
    });

    if (queueRef.current.length >= 5) {
      void flushQueue();
    }
  }, [pathname, session?.user?.id]);

  // Track User Clicks Globally
  useEffect(() => {
    if (!session?.user?.id) return;

    const handleClick = (e: MouseEvent) => {
      try {
        const rawTarget = e.target as HTMLElement | null;
        if (!rawTarget) return;

        // Check if user clicked an interactive element
        const clickable = rawTarget.closest(
          "button, a, [role='button'], [data-track], input[type='submit'], input[type='button'], summary"
        ) as HTMLElement | null;

        if (!clickable) return;

        // Don't log clicks inside the audit log table view or live logger to prevent feedback loop
        if (clickable.closest(".app-audit-logs, [data-no-track]")) return;

        // Extract readable label
        let label =
          clickable.getAttribute("data-track") ||
          clickable.getAttribute("aria-label") ||
          clickable.getAttribute("title") ||
          clickable.innerText?.trim() ||
          clickable.id ||
          clickable.className;

        if (!label || label.length === 0) {
          label = clickable.tagName.toLowerCase();
        }

        // Clean and truncate label
        label = label.replace(/\s+/g, " ").slice(0, 80);

        queueRef.current.push({
          type: "USER_CLICK",
          target: `Clicked "${label}"`,
          screen: pathname || window.location.pathname,
          metadata: `tag: <${clickable.tagName.toLowerCase()}> at (${Math.round(e.clientX)}, ${Math.round(e.clientY)})`,
        });

        if (queueRef.current.length >= 10) {
          void flushQueue();
        }
      } catch {
        /* silent */
      }
    };

    document.addEventListener("click", handleClick, { capture: true, passive: true });

    // Periodic flush timer every 2.5 seconds
    const timer = setInterval(() => {
      void flushQueue();
    }, 2500);

    return () => {
      document.removeEventListener("click", handleClick, { capture: true });
      clearInterval(timer);
      void flushQueue();
    };
  }, [session?.user?.id, pathname]);

  return null;
}
