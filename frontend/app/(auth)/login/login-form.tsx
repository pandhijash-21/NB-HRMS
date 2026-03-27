"use client";

import { signIn } from "next-auth/react";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { Eye, EyeOff, Hash } from "lucide-react";

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
    const callbackUrl = "/dashboard"; // Default redirect

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

    // Read session to determine redirect
    const { getSession } = await import("next-auth/react");
    const session = await getSession();
    
    if ((session?.user as { isFirstLogin?: boolean })?.isFirstLogin) {
      router.push("/change-password");
      return;
    }

    const role = session?.user?.role ?? "";

    if (role === "ADMIN") {
      router.push("/admin/dashboard");
    } else {
      router.push("/dashboard");
    }
  }

  return (
    <form className="space-y-6" onSubmit={handleSubmit}>
      <div className="space-y-1.5">
        <label className="block text-xs font-semibold tracking-wide text-white/80 uppercase">
          Employee ID
        </label>
        <div className="relative">
          <input
            type="number"
            autoComplete="username"
            required
            className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 pl-11 text-sm text-white placeholder-white/30 outline-none focus:border-white/30 focus:bg-white/10 focus:ring-2 focus:ring-white/20 transition-all duration-300"
            placeholder="e.g. 1"
            value={employeeId}
            onChange={(e) => setEmployeeId(e.target.value)}
          />
          <Hash className="absolute left-4 top-1/2 -translate-y-1/2 text-white/30 w-4 h-4" />
        </div>
      </div>

      <div className="space-y-1.5">
        <div className="flex items-center justify-between">
          <label className="block text-xs font-semibold tracking-wide text-white/80">
            PASSWORD
          </label>
        </div>
        <div className="relative group">
          <input
            type={showPass ? "text" : "password"}
            autoComplete="current-password"
            required
            className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 pr-12 text-sm text-white placeholder-white/30 outline-none focus:border-white/30 focus:bg-white/10 focus:ring-2 focus:ring-white/20 transition-all duration-300"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          <button
            type="button"
            className="absolute right-4 top-1/2 -translate-y-1/2 text-white/40 group-focus-within:text-white/70 hover:text-white transition-colors duration-200"
            onClick={() => setShowPass((s) => !s)}
            tabIndex={-1}
            aria-label={showPass ? "Hide password" : "Show password"}
          >
            {showPass ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
          </button>
        </div>
      </div>

      {error && (
        <div className="rounded-xl bg-rose-500/10 border border-rose-500/20 px-4 py-3 backdrop-blur-sm">
          <p className="text-xs font-medium text-rose-300">{error}</p>
        </div>
      )}

      <button
        type="submit"
        disabled={loading}
        className="mt-6 flex w-full items-center justify-center rounded-xl bg-[#d9b557] hover:bg-[#c9a547] px-4 py-3 text-sm font-bold text-[#1d3459] shadow-[0_0_20px_rgba(217,181,87,0.3)] transition-all duration-300 hover:shadow-[0_0_25px_rgba(217,181,87,0.5)] hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0 disabled:hover:shadow-[0_0_20px_rgba(217,181,87,0.3)]"
      >
        {loading ? (
          <span className="flex items-center gap-2">
            <svg className="animate-spin h-5 w-5 text-[#1d3459]" viewBox="0 0 24 24" fill="none">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            Authenticating…
          </span>
        ) : (
          "SIGN IN TO PORTAL"
        )}
      </button>

      <p className="text-center text-xs text-white/30 pt-4 pb-2">
        Use your <strong className="text-white/50">Employee ID</strong> and password to sign in
      </p>
    </form>
  );
}
