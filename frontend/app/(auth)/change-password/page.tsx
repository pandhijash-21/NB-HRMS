"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useSession } from "next-auth/react";

export default function ChangePasswordPage() {
  const router = useRouter();
  const { data: session } = useSession();
  const [form, setForm] = useState({ currentPassword: "", newPassword: "", confirm: "" });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (form.newPassword !== form.confirm) {
      setError("New passwords do not match.");
      return;
    }
    setLoading(true);
    setError(null);

    try {
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4000/api"}/auth/change-password`,
        {
          method:  "POST",
          headers: {
            "Content-Type":  "application/json",
            Authorization:   `Bearer ${session?.user?.token ?? ""}`,
          },
          body: JSON.stringify({
            currentPassword: form.currentPassword,
            newPassword:     form.newPassword,
          }),
        }
      );

      const data = await res.json();
      if (!res.ok) {
        setError(data.message ?? "Failed to change password.");
        return;
      }

      setSuccess(true);
      setTimeout(() => router.push("/login"), 2000);
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#1d3459] to-[#243b63]">
      <div className="w-full max-w-md mx-4">
        <div className="rounded-2xl bg-white shadow-2xl px-8 py-10">
          <div className="mb-6 text-center">
            <div
              className="inline-flex items-center justify-center w-12 h-12 rounded-xl mb-3"
              style={{ backgroundColor: "#1d3459" }}
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="#d9b557" strokeWidth={2} className="w-6 h-6">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                <path d="M7 11V7a5 5 0 0 1 10 0v4" />
              </svg>
            </div>
            <h1 className="text-lg font-bold" style={{ color: "#1d3459" }}>
              Set New Password
            </h1>
            <p className="mt-1 text-xs text-slate-500">
              Your account requires a password change before continuing.
            </p>
          </div>

          {success ? (
            <div className="rounded-md bg-emerald-50 border border-emerald-200 px-4 py-3 text-center">
              <p className="text-sm font-medium text-emerald-700">
                Password changed! Redirecting to login…
              </p>
            </div>
          ) : (
            <form className="space-y-4" onSubmit={handleSubmit}>
              {(["currentPassword", "newPassword", "confirm"] as const).map((field) => (
                <div key={field} className="space-y-1">
                  <label className="block text-xs font-medium text-slate-600 capitalize">
                    {field === "currentPassword"
                      ? "Current Password"
                      : field === "newPassword"
                      ? "New Password"
                      : "Confirm New Password"}
                  </label>
                  <input
                    type="password"
                    required
                    className="w-full rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-sm outline-none focus:border-[#1d3459] focus:ring-1 focus:ring-[#1d3459] transition-colors"
                    placeholder="••••••••"
                    value={form[field]}
                    onChange={(e) => setForm((f) => ({ ...f, [field]: e.target.value }))}
                  />
                </div>
              ))}

              {error && (
                <div className="rounded-md bg-rose-50 border border-rose-200 px-3 py-2">
                  <p className="text-xs text-rose-600">{error}</p>
                </div>
              )}

              <p className="text-xs text-slate-400">
                Min. 8 characters, at least one letter and one number.
              </p>

              <button
                type="submit"
                disabled={loading}
                style={{ backgroundColor: "#1d3459" }}
                className="w-full inline-flex items-center justify-center rounded-md px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:opacity-90 disabled:opacity-60"
              >
                {loading ? "Updating…" : "Set Password & Continue"}
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
