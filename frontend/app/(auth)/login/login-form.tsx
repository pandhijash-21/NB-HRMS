"use client";

import { signIn } from "next-auth/react";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";

export default function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [employeeId, setEmployeeId] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPass, setShowPass] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const callbackUrl = searchParams.get("callbackUrl") ?? "/profile";

    const result = await signIn("credentials", {
      redirect: false,
      employeeId,
      password,
      callbackUrl,
    });

    setLoading(false);

    if (!result || result.error) {
      setError("Invalid Employee ID or password. Please try again.");
      return;
    }

    // NextAuth puts isFirstLogin + role in the URL via callbackUrl on success
    // Read fresh session to check isFirstLogin
    const { getSession } = await import("next-auth/react");
    const session = await getSession();

    if ((session?.user as { isFirstLogin?: boolean })?.isFirstLogin) {
      router.push("/change-password");
      return;
    }

    const role = session?.user?.role ?? "";
    if (role === "ADMIN" || role === "HR" || role === "HOI" || role === "FINANCE") {
      router.push("/admin/dashboard");
    } else {
      router.push(result.url ?? "/profile");
    }
  }

  return (
    <form className="space-y-5" onSubmit={handleSubmit}>
      <div className="space-y-1">
        <label className="block text-xs font-medium text-slate-600">
          Employee ID
        </label>
        <input
          type="number"
          autoComplete="username"
          required
          min={1}
          className="w-full rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-sm outline-none focus:border-[#1d3459] focus:ring-1 focus:ring-[#1d3459] transition-colors"
          placeholder="e.g. 1"
          value={employeeId}
          onChange={(e) => setEmployeeId(e.target.value)}
        />
      </div>

      <div className="space-y-1">
        <div className="flex items-center justify-between">
          <label className="block text-xs font-medium text-slate-600">
            Password
          </label>
          <button
            type="button"
            className="text-[0.7rem] font-medium text-[#1d3459] hover:text-[#d9b557] transition-colors"
          >
            Forgot password?
          </button>
        </div>
        <div className="relative">
          <input
            type={showPass ? "text" : "password"}
            autoComplete="current-password"
            required
            className="w-full rounded-md border border-slate-200 bg-slate-50 px-3 py-2 pr-10 text-sm outline-none focus:border-[#1d3459] focus:ring-1 focus:ring-[#1d3459] transition-colors"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          <button
            type="button"
            className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-slate-400 hover:text-slate-600"
            onClick={() => setShowPass((s) => !s)}
            tabIndex={-1}
          >
            {showPass ? "Hide" : "Show"}
          </button>
        </div>
      </div>

      {error && (
        <div className="rounded-md bg-rose-50 border border-rose-200 px-3 py-2">
          <p className="text-xs text-rose-600">{error}</p>
        </div>
      )}

      <button
        type="submit"
        disabled={loading}
        style={{ backgroundColor: "#1d3459" }}
        className="mt-2 inline-flex w-full items-center justify-center rounded-md px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:opacity-90 disabled:opacity-60"
      >
        {loading ? (
          <span className="flex items-center gap-2">
            <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            Signing in…
          </span>
        ) : (
          "Sign in"
        )}
      </button>

      <p className="text-center text-xs text-slate-400 pt-1">
        Use your Employee ID and password to sign in
      </p>
    </form>
  );
}
