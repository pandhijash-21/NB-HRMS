"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Users, Play, Square, FlaskConical } from "lucide-react";
import api from "@/lib/axios";
import { toast } from "sonner";

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
  isSimulated?: boolean;
  tripId?: string | null;
}

export default function LiveTrackingPage() {
  const [locations, setLocations] = useState<LiveLocation[]>([]);
  const [simBusy, setSimBusy] = useState(false);
  const [simRunning, setSimRunning] = useState(false);
  const [scenario, setScenario] = useState<"office_loop" | "gap" | "geofence_exit">("office_loop");
  const [employeeId, setEmployeeId] = useState("");

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
    const interval = setInterval(fetchLocations, 3000);

    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    // Prefill employee id from /auth/me when available
    (async () => {
      try {
        const { data } = await api.get("auth/me");
        const id = data?.data?.employeeId ?? data?.data?.employee?.id;
        if (id != null) setEmployeeId(String(id));
      } catch {
        /* ignore */
      }
    })();
  }, []);

  const startSim = async () => {
    const id = Number(employeeId);
    if (!id) {
      toast.error("Enter an employee ID to simulate");
      return;
    }
    setSimBusy(true);
    try {
      const { data } = await api.post("tracking/simulate/start", {
        employeeId: id,
        scenario,
        intervalMs: 2200,
      });
      setSimRunning(true);
      toast.success(data?.data?.message ?? "Simulation started — watch the map");
    } catch (e: any) {
      toast.error(e?.response?.data?.message ?? e?.message ?? "Failed to start simulation");
    } finally {
      setSimBusy(false);
    }
  };

  const stopSim = async () => {
    const id = Number(employeeId);
    if (!id) return;
    setSimBusy(true);
    try {
      await api.post("tracking/simulate/stop", { employeeId: id });
      setSimRunning(false);
      toast.success("Simulation stopped");
    } catch (e: any) {
      toast.error(e?.response?.data?.message ?? e?.message ?? "Failed to stop");
    } finally {
      setSimBusy(false);
    }
  };

  return (
    <div className="p-6 max-w-[1600px] mx-auto space-y-6">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight">Employee Live Tracking</h1>
          <p className="text-muted-foreground mt-1">Real-time GPS locations of active employees on duty.</p>
        </div>
        <div className="flex items-center gap-2 bg-primary/10 text-primary px-4 py-2 rounded-full font-semibold self-start">
          <Users className="w-5 h-5" />
          <span>{locations.length} Active</span>
        </div>
      </div>

      <Card className="p-4 border-border/50 shadow-sm space-y-3">
        <div className="flex items-center gap-2 font-semibold">
          <FlaskConical className="w-4 h-4" />
          Tracking simulator
        </div>
        <p className="text-sm text-muted-foreground">
          Drives the real pipeline (Redis live pin → trip → heartbeats) with a fake GPS path so you can see how it works without a field phone.
        </p>
        <div className="flex flex-wrap items-end gap-3">
          <label className="text-sm space-y-1">
            <span className="text-muted-foreground">Employee ID</span>
            <input
              className="block w-28 rounded-md border border-input bg-background px-3 py-2 text-sm"
              value={employeeId}
              onChange={(e) => setEmployeeId(e.target.value)}
              placeholder="e.g. 1"
            />
          </label>
          <label className="text-sm space-y-1">
            <span className="text-muted-foreground">Scenario</span>
            <select
              className="block rounded-md border border-input bg-background px-3 py-2 text-sm min-w-[160px]"
              value={scenario}
              onChange={(e) => setScenario(e.target.value as typeof scenario)}
              disabled={simRunning}
            >
              <option value="office_loop">Office loop</option>
              <option value="geofence_exit">Geofence exit</option>
              <option value="gap">Network gap</option>
            </select>
          </label>
          <Button onClick={startSim} disabled={simBusy || simRunning} className="gap-2">
            <Play className="w-4 h-4" />
            Start demo
          </Button>
          <Button variant="outline" onClick={stopSim} disabled={simBusy || !simRunning} className="gap-2">
            <Square className="w-4 h-4" />
            Stop
          </Button>
        </div>
      </Card>

      <Card className="overflow-hidden border-border/50 shadow-sm relative">
        <LiveMap locations={locations} />
      </Card>
    </div>
  );
}
