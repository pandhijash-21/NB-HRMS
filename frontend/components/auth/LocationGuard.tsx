"use client";

import { useEffect, useState, ReactNode } from "react";
import { AlertCircle, MapPin } from "lucide-react";
import { Button } from "@/components/ui/button";

export function LocationGuard({ children }: { children: ReactNode }) {
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  useEffect(() => {
    if (!("geolocation" in navigator)) {
      setErrorMsg("Geolocation is not supported by your browser.");
      setHasPermission(false);
      return;
    }

    const checkPermission = async () => {
      try {
        const result = await navigator.permissions.query({ name: "geolocation" });
        if (result.state === "granted") {
          setHasPermission(true);
          startPing();
        } else if (result.state === "prompt") {
          // Do nothing, wait for user click to request
          setHasPermission(false);
        } else {
          setHasPermission(false);
          setErrorMsg("Location access is denied. Please enable it in your browser settings and refresh.");
        }

        result.onchange = () => {
          if (result.state === "granted") {
            setHasPermission(true);
            startPing();
            setErrorMsg(null);
          } else {
            setHasPermission(false);
          }
        };
      } catch (e) {
        // Fallback for browsers that don't support permissions.query
        requestLocation();
      }
    };

    checkPermission();
  }, []);

  let pingInterval: NodeJS.Timeout;

  const startPing = () => {
    if (pingInterval) clearInterval(pingInterval);
    
    // Ping every 3 seconds
    pingInterval = setInterval(() => {
      navigator.geolocation.getCurrentPosition(
        async (position) => {
          try {
            // Note: Replace with your actual auth token logic if needed for API calls.
            // Using a simple fetch here. In Next.js with NextAuth, you might want to wrap this in an authenticated context.
            const { getSession } = await import("next-auth/react");
            const session = await getSession();
            const token = (session?.user as any)?.token || "";
            
            const apiUrl = process.env.NEXT_PUBLIC_API_URL ? 
              (process.env.NEXT_PUBLIC_API_URL.endsWith('/') ? `${process.env.NEXT_PUBLIC_API_URL}tracking/live` : `${process.env.NEXT_PUBLIC_API_URL}/tracking/live`) : 
              "http://localhost:4000/api/tracking/live";
              
            await fetch(apiUrl, {
              method: "POST",
              headers: { "Content-Type": "application/json", "Authorization": `Bearer ${token}` }, // Ad-hoc token
              body: JSON.stringify({
                latitude: position.coords.latitude,
                longitude: position.coords.longitude,
                heading: position.coords.heading ?? 0
              })
            }).catch(() => {});
          } catch(e) {}
        },
        () => {},
        { enableHighAccuracy: true, maximumAge: 0 }
      );
    }, 3000);
  };

  const requestLocation = () => {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setHasPermission(true);
        startPing();
        setErrorMsg(null);
      },
      (error) => {
        setHasPermission(false);
        setErrorMsg("Location access was denied. You must enable it to use this application.");
      },
      { enableHighAccuracy: true }
    );
  };

  // While checking
  if (hasPermission === null) return <div className="min-h-screen flex items-center justify-center">Checking location requirements...</div>;

  // If granted, render app
  if (hasPermission) return <>{children}</>;

  // Block UI
  return (
    <div className="fixed inset-0 z-[9999] bg-[#0A0A0A] overflow-hidden flex flex-col items-center justify-center p-6 text-center">
      {/* Map Background */}
      <div 
        className="absolute inset-0 bg-cover bg-center bg-no-repeat opacity-40 mix-blend-lighten"
        style={{ backgroundImage: 'url(/images/golden_map.jpg)' }}
      ></div>

      {/* Glassmorphism Card */}
      <div className="relative z-10 max-w-md w-full bg-white/5 backdrop-blur-xl border border-amber-500/30 shadow-[0_0_40px_rgba(245,158,11,0.15)] rounded-3xl p-10 flex flex-col items-center">
        <div className="p-6 rounded-full bg-amber-500/10 shadow-[0_0_25px_rgba(245,158,11,0.25)] mb-8">
          <MapPin className="w-16 h-16 text-amber-400" />
        </div>
        <h1 className="text-2xl font-black tracking-widest text-white mb-4 uppercase">Location Required</h1>
        <p className="text-amber-50 text-base mb-10 leading-relaxed">
          {errorMsg || "This application strictly requires location access to function. Please grant location permissions to continue."}
        </p>
        <button 
          onClick={requestLocation} 
          className="w-full relative group overflow-hidden rounded-xl bg-gradient-to-r from-amber-500 to-orange-600 shadow-[0_5px_15px_rgba(245,158,11,0.4)]"
        >
          <div className="absolute inset-0 bg-gradient-to-r from-amber-400 to-orange-500 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
          <div className="relative w-full h-full bg-transparent px-6 py-4 flex items-center justify-center gap-3">
            <AlertCircle className="w-5 h-5 text-black" />
            <span className="text-black font-bold tracking-widest text-sm">ENABLE PERMISSIONS</span>
          </div>
        </button>
      </div>
    </div>
  );
}
