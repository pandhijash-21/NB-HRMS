import { TopbarActions } from "./TopbarActions";

interface TopbarProps {
  title: string;
  subtitle?: string;
  isAdmin?: boolean;
}

/**
 * Topbar shell — safe to use in both server and client component trees.
 * All hooks (useSession, useSSE, etc.) live in <TopbarActions />.
 */
export function Topbar({ title, subtitle, isAdmin = false }: TopbarProps) {
  return (
    <header className="app-header">
      <div>
        <h1 className="app-header-title">{title}</h1>
        {subtitle && <p className="app-header-subtitle">{subtitle}</p>}
      </div>

      <TopbarActions isAdmin={isAdmin} />
    </header>
  );
}
