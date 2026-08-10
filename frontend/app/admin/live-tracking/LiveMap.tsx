import "leaflet/dist/leaflet.css";
import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
import L from "leaflet";
import { LiveLocation } from "./page";

// Fix Leaflet's default icon paths in Next.js
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

export default function LiveMap({ locations }: { locations: LiveLocation[] }) {
  // Default to a central location (e.g., Gandhinagar)
  const defaultCenter: [number, number] = [23.2156, 72.6369];

  return (
    <div className="w-full h-[600px] z-0">
      <MapContainer
        center={locations.length > 0 ? [locations[0].latitude, locations[0].longitude] : defaultCenter}
        zoom={13}
        className="w-full h-full"
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {locations.map((loc) => (
          <Marker
            key={loc.employeeId}
            position={[loc.latitude, loc.longitude]}
          >
            <Popup>
              <div className="text-sm">
                <p className="font-bold">{loc.fullName || `Employee #${loc.employeeId}`}</p>
                {loc.designation && <p className="text-muted-foreground">{loc.designation}</p>}
                {loc.isSimulated && (
                  <p className="text-xs text-amber-600 font-medium mt-1">Demo simulation</p>
                )}
                {loc.tripId && (
                  <p className="text-xs text-emerald-600 mt-0.5">On trip</p>
                )}
                <p className="text-xs text-slate-400 mt-1">Last seen: {new Date(loc.updatedAt).toLocaleTimeString()}</p>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}
