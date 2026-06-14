import type { EmployeeNameItem } from "@/modules/admin/hooks/useAdminEmployees";

export function formatApproverOption(item: EmployeeNameItem): string {
  if (item.type === "POSITION") {
    const role = item.designationName ?? item.employeeCode;
    return role ? `${item.fullName} (${role})` : item.fullName;
  }
  return item.employeeCode ? `${item.fullName} (${item.employeeCode})` : item.fullName;
}

export function groupApproverOptions(items: EmployeeNameItem[]) {
  const positions = items.filter((i) => i.type === "POSITION");
  const employees = items.filter((i) => i.type === "EMPLOYEE");
  return { positions, employees };
}
