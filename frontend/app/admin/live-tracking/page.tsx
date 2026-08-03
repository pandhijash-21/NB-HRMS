"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { Card } from "@/components/ui/card";
import { Users } from "lucide-react";
import api from "@/lib/axios";

// Dynamically import the Map component to avoid SSR issues with Leaflet
const LiveMap = dynamic(() => import("./LiveMap"), {
  ssr: false,
  loading: () => <div className="w-full h-[600px] flex items-center justify-center bg-muted/20 animate-pulse">Loading map...</div>
});

export interface LiveLocation {
  employeeId: number;
  latitude: number;
  longitude: number;
  heading: number;
  updatedAt: string;
  fullName?: string;
  designation?: string;
}

export default function LiveTrackingPage() {
  const [locations, setLocations] = useState<LiveLocation[]>([]);

  useEffect(() => {
    const fetchLocations = async () => {
      try {
        const { data } = await api.get("tracking/live");
        if (data?.data) {
          setLocations(data.data);
        }
      } catch (e) {}
    };

    fetchLocations();
    const interval = setInterval(fetchLocations, 3000); // Poll every 3 seconds

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="p-6 max-w-[1600px] mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight">Employee Live Tracking</h1>
          <p className="text-muted-foreground mt-1">Real-time GPS locations of active employees on duty.</p>
        </div>
        <div className="flex items-center gap-2 bg-primary/10 text-primary px-4 py-2 rounded-full font-semibold">
          <Users className="w-5 h-5" />
          <span>{locations.length} Active</span>
        </div>
      </div>

      <Card className="overflow-hidden border-border/50 shadow-sm relative">
        <LiveMap locations={locations} />
      </Card>
    </div>
  );
}
