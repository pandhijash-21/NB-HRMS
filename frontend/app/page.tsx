import Link from "next/link";

export default function Home() {
  return (
    <div
      className="min-h-screen flex flex-col items-center justify-center"
      style={{
        background: "linear-gradient(135deg, #1d3459 0%, #243b63 60%, #1a2e50 100%)",
      }}
    >
      <div className="text-center max-w-xl px-6">
        {/* Logo */}
        <div
          className="inline-flex items-center justify-center w-20 h-20 rounded-3xl mb-6 shadow-xl"
          style={{ backgroundColor: "rgba(217,181,87,0.2)", border: "2px solid #d9b557" }}
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="#d9b557"
            strokeWidth={2}
            className="w-10 h-10"
          >
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
        </div>

        <h1 className="text-4xl font-bold text-white tracking-tight">
          HRMS Portal
        </h1>
        <p className="mt-2 text-lg text-slate-300 font-light">
          Gandhinagar University
        </p>
        <p className="mt-4 text-sm text-slate-400 max-w-sm mx-auto leading-relaxed">
          Human Resource Management System — manage employees, profiles, documents, and more.
        </p>

        <div className="mt-10 flex flex-col sm:flex-row gap-3 justify-center">
          <Link
            href="/login"
            className="inline-flex items-center justify-center px-6 py-3 rounded-xl text-sm font-semibold text-[#1d3459] shadow-lg transition hover:scale-[1.02] hover:shadow-xl"
            style={{ backgroundColor: "#d9b557" }}
          >
            Employee Login
          </Link>
          <Link
            href="/admin/dashboard"
            className="inline-flex items-center justify-center px-6 py-3 rounded-xl text-sm font-semibold text-white border border-white/20 shadow-lg transition hover:bg-white/10"
          >
            Admin Panel →
          </Link>
        </div>

        <div className="mt-8 flex items-center justify-center gap-6 text-xs text-slate-500">
          <span className="flex items-center gap-1">
            <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 inline-block" />
            Secure Access
          </span>
          <span className="flex items-center gap-1">
            <span className="h-1.5 w-1.5 rounded-full bg-blue-400 inline-block" />
            Role-based Permissions
          </span>
          <span className="flex items-center gap-1">
            <span className="h-1.5 w-1.5 rounded-full bg-amber-400 inline-block" />
            Audit Logging
          </span>
        </div>
      </div>

      <p className="mt-16 text-xs text-slate-600">
        &copy; {new Date().getFullYear()} Gandhinagar University · All rights reserved
      </p>
    </div>
  );
}
