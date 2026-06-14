"use client";

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useInstitutes } from "@/lib/hooks/useInstitutes";

type Props = {
  value?: string;
  onValueChange: (value: string) => void;
  placeholder?: string;
  /** Form value: institute id (default), code, or full name */
  valueMode?: "id" | "code" | "name";
  disabled?: boolean;
  id?: string;
  className?: string;
};

export function InstituteSelect({
  value,
  onValueChange,
  placeholder = "Select institute…",
  valueMode = "id",
  disabled,
  id,
  className,
}: Props) {
  const { data: institutes = [], isLoading } = useInstitutes({ activeOnly: true });

  return (
    <Select value={value ?? ""} onValueChange={onValueChange} disabled={disabled || isLoading}>
      <SelectTrigger id={id} className={className}>
        <SelectValue placeholder={isLoading ? "Loading…" : placeholder} />
      </SelectTrigger>
      <SelectContent>
        {institutes.map((i) => (
          <SelectItem
            key={i.id}
            value={valueMode === "id" ? i.id : valueMode === "name" ? i.name : i.code}
          >
            {i.name} ({i.code})
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
