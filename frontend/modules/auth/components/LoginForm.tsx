"use client";

import { useLogin } from "../hooks/useAuth";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Eye, EyeOff, Hash, Loader2 } from "lucide-react";
import { getSession } from "next-auth/react";

export function LoginForm() {
  const router = useRouter();
  const [employeeId, setEmployeeId] = useState("");
  const [password, setPassword] = useState("");
  const [showPass, setShowPass] = useState(false);
  const [errorVisible, setErrorVisible] = useState(false);

  const loginMutation = useLogin();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    loginMutation.mutate(
      { employeeId, password },
      {
        onSuccess: async () => {
          const session = await getSession();
          if ((session?.user as any)?.isFirstLogin) {
            router.push("/change-password");
            return;
          }

          const role = session?.user?.role ?? "";
          if (role === "ADMIN" || role === "HR") {
            router.push("/admin/dashboard");
          } else {
            router.push("/dashboard");
          }
        },
        onError: () => {
          setErrorVisible(true);
        },
      }
    );
  }

  return (
    <form className="space-y-6" onSubmit={handleSubmit}>
      <div className="space-y-1.5">
        <label
          htmlFor="employeeId"
          className="block text-xs font-semibold tracking-wide text-white/80 uppercase"
        >
          Employee ID
        </label>
        <div className="relative">
          <input
            id="employeeId"
            name="employeeId"
            type="number"
            autoComplete="username"
            required
            className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 pl-11 text-sm text-white placeholder-white/30 outline-none focus:border-white/30 focus:bg-white/10 focus:ring-2 focus:ring-white/20 transition-all duration-300"
            placeholder="e.g. 1"
            value={employeeId}
            onChange={(e) => {
              setEmployeeId(e.target.value);
              setErrorVisible(false);
            }}
          />
          <Hash className="absolute left-4 top-1/2 -translate-y-1/2 text-white/30 w-4 h-4" />
        </div>
      </div>

      <div className="space-y-1.5">
        <div className="flex items-center justify-between">
          <label
            htmlFor="password"
            className="block text-xs font-semibold tracking-wide text-white/80 uppercase"
          >
            Password
          </label>
        </div>
        <div className="relative group">
          <input
            id="password"
            name="password"
            type={showPass ? "text" : "password"}
            autoComplete="current-password"
            required
            className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 pr-12 text-sm text-white placeholder-white/30 outline-none focus:border-white/30 focus:bg-white/10 focus:ring-2 focus:ring-white/20 transition-all duration-300"
            placeholder="••••••••"
            value={password}
            onChange={(e) => {
              setPassword(e.target.value);
              setErrorVisible(false);
            }}
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

      {errorVisible && (
        <div className="rounded-xl bg-rose-500/10 border border-rose-500/20 px-4 py-3 backdrop-blur-sm">
          <p className="text-xs font-medium text-rose-300">
            Invalid Employee ID or password. Please try again.
          </p>
        </div>
      )}

      <button
        type="submit"
        disabled={loginMutation.isPending}
        className="mt-6 flex w-full items-center justify-center rounded-xl bg-[#d9b557] hover:bg-[#c9a547] px-4 py-3 text-sm font-bold text-[#1d3459] shadow-[0_0_20px_rgba(217,181,87,0.3)] transition-all duration-300 hover:shadow-[0_0_25px_rgba(217,181,87,0.5)] hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0 disabled:hover:shadow-[0_0_20px_rgba(217,181,87,0.3)]"
      >
        {loginMutation.isPending ? (
          <span className="flex items-center gap-2">
            <Loader2 className="h-5 w-5 animate-spin" />
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
