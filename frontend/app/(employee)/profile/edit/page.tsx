const tabs = [
  "General",
  "Personal",
  "Address",
  "Other",
  "Family",
  "Education",
] as const;

export default function EmployeeProfileEditPage() {
  return (
    <div className="space-y-5">
      <header className="flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-base font-semibold text-slate-900">
            Edit profile
          </h1>
          <p className="text-xs text-slate-500">
            Keep your personal and academic information up to date.
          </p>
        </div>
        <button className="inline-flex items-center rounded-md bg-[color:var(--accent)] px-3 py-1.5 text-xs font-medium text-slate-900 shadow-sm hover:bg-[color:var(--accent-soft)]">
          Save changes
        </button>
      </header>

      <div className="rounded-xl border border-[color:var(--primary-muted)] bg-white/80">
        <div className="flex flex-wrap border-b border-[color:var(--primary-muted)] bg-slate-50/60 px-3">
          {tabs.map((tab) => (
            <button
              key={tab}
              className={
                "relative px-3 py-2 text-xs font-medium text-slate-600 hover:text-[color:var(--primary)] " +
                (tab === "General"
                  ? "text-[color:var(--primary)] after:absolute after:inset-x-2 after:-bottom-px after:h-0.5 after:rounded-full after:bg-[color:var(--accent)]"
                  : "")
              }
            >
              {tab}
            </button>
          ))}
        </div>

        <div className="p-4 text-xs text-slate-600">
          {/* Placeholder: individual tab forms will be wired later */}
          Start with the <span className="font-semibold">General</span> tab:
          Full Name, Organization, Department, Reporting hierarchy, etc.
        </div>
      </div>
    </div>
  );
}

