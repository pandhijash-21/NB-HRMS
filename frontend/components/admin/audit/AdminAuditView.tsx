"use client";

import React, { useState, useMemo } from "react";
import {
  useAuditLogs,
  useAuditEmployees,
  useAuditStats,
  type AuditEmployeeSummary,
} from "@/lib/hooks/useAuditLogs";
import { AuditLogTable } from "./AuditLogTable";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Users,
  Search,
  Filter,
  Download,
  RotateCcw,
  ShieldCheck,
  Activity,
  FileSpreadsheet,
  Calendar,
  Layers,
  MousePointerClick,
  Compass,
  Zap,
  FileEdit,
} from "lucide-react";

export function AdminAuditView() {
  const [selectedEmployeeId, setSelectedEmployeeId] = useState<number | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<string>("ALL");
  const [employeeSearch, setEmployeeSearch] = useState("");
  const [logSearch, setLogSearch] = useState("");
  const [selectedTable, setSelectedTable] = useState<string>("all");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [page, setPage] = useState(1);

  // Stats
  const { stats } = useAuditStats();

  // Employee list
  const { employees, loading: loadingEmployees } = useAuditEmployees(employeeSearch);

  // Logs
  const { logs, pagination, loading: loadingLogs, refetch } = useAuditLogs({
    employeeId: selectedEmployeeId ?? undefined,
    category: selectedCategory !== "ALL" ? selectedCategory : undefined,
    tableName: selectedTable !== "all" ? selectedTable : undefined,
    search: logSearch || undefined,
    startDate: startDate || undefined,
    endDate: endDate || undefined,
    page,
    limit: 50,
  });

  const selectedEmployee = useMemo(() => {
    if (!selectedEmployeeId) return null;
    return employees.find((e) => e.employeeId === selectedEmployeeId) ?? null;
  }, [selectedEmployeeId, employees]);

  const handleResetFilters = () => {
    setLogSearch("");
    setSelectedTable("all");
    setStartDate("");
    setEndDate("");
    setSelectedCategory("ALL");
    setPage(1);
  };

  const setDatePreset = (preset: "today" | "yesterday" | "7days" | "30days") => {
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, "0");
    const fmt = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

    if (preset === "today") {
      const todayStr = fmt(now);
      setStartDate(todayStr);
      setEndDate(todayStr);
    } else if (preset === "yesterday") {
      const y = new Date(now);
      y.setDate(y.getDate() - 1);
      const yStr = fmt(y);
      setStartDate(yStr);
      setEndDate(yStr);
    } else if (preset === "7days") {
      const start = new Date(now);
      start.setDate(start.getDate() - 7);
      setStartDate(fmt(start));
      setEndDate(fmt(now));
    } else if (preset === "30days") {
      const start = new Date(now);
      start.setDate(start.getDate() - 30);
      setStartDate(fmt(start));
      setEndDate(fmt(now));
    }
    setPage(1);
  };

  const handleExportCSV = () => {
    if (!logs.length) {
      alert("No logs to export in current view");
      return;
    }
    const headers = [
      "Timestamp",
      "Employee ID",
      "Employee Name",
      "Employee Code",
      "Module",
      "Field",
      "Previous Value",
      "Updated Value",
      "Changed By",
      "Changer Role",
      "Is Self Edit",
      "IP Address",
      "Reason",
    ];

    const rows = logs.map((l) => [
      `"${l.changedAt}"`,
      `"${l.employeeId ?? ""}"`,
      `"${(l.targetEmployee?.fullName ?? "").replace(/"/g, '""')}"`,
      `"${(l.targetEmployee?.employeeCode ?? "").replace(/"/g, '""')}"`,
      `"${l.tableLabel}"`,
      `"${l.fieldLabel}"`,
      `"${(l.oldValue ?? "").replace(/"/g, '""')}"`,
      `"${(l.newValue ?? "").replace(/"/g, '""')}"`,
      `"${(l.changedByName ?? "").replace(/"/g, '""')}"`,
      `"${l.changedByRole ?? ""}"`,
      `"${l.isSelfChange ? "Yes" : "No"}"`,
      `"${l.ipAddress ?? ""}"`,
      `"${(l.changeReason ?? "").replace(/"/g, '""')}"`,
    ]);

    const csvContent = "data:text/csv;charset=utf-8," + [headers.join(","), ...rows.map((e) => e.join(","))].join("\n");
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `audit_logs_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6">
      {/* Page Title & Actions */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-800 tracking-tight flex items-center gap-2">
            <ShieldCheck className="w-6 h-6 text-indigo-600" />
            Workforce Audit Logs & Activity Trail
          </h1>
          <p className="text-xs md:text-sm text-slate-500 mt-1">
            Browse and inspect all historical profile edits, field changes, and system operations employee-wise.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={handleExportCSV}
            className="text-xs h-9 font-semibold text-slate-700 bg-white shadow-sm border-slate-200 hover:bg-slate-50"
          >
            <Download className="w-3.5 h-3.5 mr-1.5 text-indigo-600" />
            Export CSV
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => refetch()}
            className="text-xs h-9 text-slate-600 hover:text-slate-900"
          >
            <RotateCcw className="w-3.5 h-3.5" />
          </Button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 md:gap-4">
        <div className="bg-white border border-slate-200/80 rounded-xl p-4 shadow-sm">
          <div className="flex items-center justify-between text-slate-500 mb-1">
            <span className="text-xs font-semibold uppercase tracking-wider">Total Changes</span>
            <Activity className="w-4 h-4 text-indigo-500" />
          </div>
          <div className="text-2xl font-extrabold text-slate-800">
            {stats?.totalLogs?.toLocaleString() ?? "—"}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">Audit events logged to date</div>
        </div>

        <div className="bg-white border border-slate-200/80 rounded-xl p-4 shadow-sm">
          <div className="flex items-center justify-between text-slate-500 mb-1">
            <span className="text-xs font-semibold uppercase tracking-wider">Today's Edits</span>
            <Calendar className="w-4 h-4 text-emerald-500" />
          </div>
          <div className="text-2xl font-extrabold text-slate-800">
            {stats?.todayLogs?.toLocaleString() ?? "—"}
          </div>
          <div className="text-[11px] text-emerald-600 font-medium mt-1">Logged since midnight</div>
        </div>

        <div className="bg-white border border-slate-200/80 rounded-xl p-4 shadow-sm">
          <div className="flex items-center justify-between text-slate-500 mb-1">
            <span className="text-xs font-semibold uppercase tracking-wider">Employees Tracked</span>
            <Users className="w-4 h-4 text-sky-500" />
          </div>
          <div className="text-2xl font-extrabold text-slate-800">
            {stats?.activeEmployeesWithLogs?.toLocaleString() ?? "—"}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">Members with audit events</div>
        </div>

        <div className="bg-white border border-slate-200/80 rounded-xl p-4 shadow-sm">
          <div className="flex items-center justify-between text-slate-500 mb-1">
            <span className="text-xs font-semibold uppercase tracking-wider">Most Active Section</span>
            <Layers className="w-4 h-4 text-amber-500" />
          </div>
          <div className="text-base font-bold text-slate-800 truncate" title={stats?.topTables?.[0]?.label}>
            {stats?.topTables?.[0]?.label ?? "General Info"}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">
            {stats?.topTables?.[0]?.count ? `${stats.topTables[0].count} edits recorded` : "—"}
          </div>
        </div>
      </div>

      {/* Main Split Layout: Employee-wise Left Selector & Right Log Stream */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 items-start">
        {/* Left: Employee Selection Pane (4 cols) */}
        <div className="lg:col-span-4 bg-white border border-slate-200/80 rounded-xl shadow-sm p-4 space-y-3">
          <div className="flex items-center justify-between border-b pb-2.5">
            <div className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <Users className="w-4 h-4 text-indigo-600" />
              Workforce Members
            </div>
            <Badge variant="outline" className="text-[10px] font-bold text-slate-500">
              {employees.length} Total
            </Badge>
          </div>

          {/* Search Employees */}
          <div className="relative">
            <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <Input
              type="text"
              placeholder="Search employee by name, code..."
              value={employeeSearch}
              onChange={(e) => setEmployeeSearch(e.target.value)}
              className="pl-9 h-8 text-xs bg-slate-50/50"
            />
          </div>

          {/* "All Employees" Button */}
          <button
            type="button"
            onClick={() => {
              setSelectedEmployeeId(null);
              setPage(1);
            }}
            className={`w-full text-left p-2.5 rounded-lg border text-xs transition-all flex items-center justify-between ${
              selectedEmployeeId === null
                ? "bg-indigo-50/80 border-indigo-200 text-indigo-900 font-bold shadow-sm"
                : "border-slate-100 hover:bg-slate-50 text-slate-700"
            }`}
          >
            <div className="flex items-center gap-2.5">
              <div className="w-7 h-7 rounded-full bg-indigo-100 text-indigo-700 font-bold text-xs flex items-center justify-center shrink-0">
                All
              </div>
              <div>
                <div className="font-semibold text-slate-800">All Workforce Logs</div>
                <div className="text-[10px] text-slate-400">View company-wide audit stream</div>
              </div>
            </div>
            <Badge variant="secondary" className="text-[10px] bg-white border font-bold">
              {stats?.totalLogs ?? 0}
            </Badge>
          </button>

          {/* Employee List */}
          <div className="space-y-1 max-h-[520px] overflow-y-auto pr-1">
            {loadingEmployees ? (
              Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="p-2.5 rounded-lg border border-slate-100 animate-pulse flex items-center gap-2">
                  <div className="w-7 h-7 rounded-full bg-slate-200" />
                  <div className="space-y-1 flex-1">
                    <div className="h-3 bg-slate-200 rounded w-3/4" />
                    <div className="h-2 bg-slate-100 rounded w-1/2" />
                  </div>
                </div>
              ))
            ) : employees.length === 0 ? (
              <div className="text-center py-8 text-slate-400 text-xs">
                No matching workforce members found
              </div>
            ) : (
              employees.map((emp) => {
                const isSelected = selectedEmployeeId === emp.employeeId;
                return (
                  <button
                    key={emp.employeeId}
                    type="button"
                    onClick={() => {
                      setSelectedEmployeeId(emp.employeeId);
                      setPage(1);
                    }}
                    className={`w-full text-left p-2.5 rounded-lg border text-xs transition-all flex items-center justify-between ${
                      isSelected
                        ? "bg-indigo-50/80 border-indigo-200 text-indigo-900 font-bold shadow-sm ring-1 ring-indigo-300"
                        : "border-slate-100 hover:bg-slate-50 text-slate-700"
                    }`}
                  >
                    <div className="flex items-center gap-2.5 min-w-0">
                      <Avatar className="w-7 h-7 shrink-0 border border-slate-200">
                        {emp.avatarUrl && <AvatarImage src={emp.avatarUrl} alt={emp.fullName} />}
                        <AvatarFallback className="bg-indigo-50 text-indigo-700 font-bold text-[10px]">
                          {emp.fullName.slice(0, 2).toUpperCase()}
                        </AvatarFallback>
                      </Avatar>
                      <div className="min-w-0">
                        <div className="font-semibold text-slate-800 truncate" title={emp.fullName}>
                          {emp.fullName}
                        </div>
                        <div className="text-[10px] text-slate-400 font-mono truncate">
                          {emp.employeeCode ? emp.employeeCode : `ID #${emp.employeeId}`}
                          {emp.designation ? ` • ${emp.designation}` : ""}
                        </div>
                      </div>
                    </div>
                    {emp.totalChanges > 0 ? (
                      <Badge
                        variant="secondary"
                        className={`text-[10px] font-bold px-1.5 py-0 shrink-0 ${
                          isSelected ? "bg-indigo-600 text-white" : "bg-slate-100 text-slate-700"
                        }`}
                      >
                        {emp.totalChanges}
                      </Badge>
                    ) : (
                      <span className="text-[10px] text-slate-300 shrink-0">—</span>
                    )}
                  </button>
                );
              })
            )}
          </div>
        </div>

        {/* Right: Selected Employee Logs Table (8 cols) */}
        <div className="lg:col-span-8 space-y-4">
          {/* Active Employee Banner / Title */}
          <div className="bg-white border border-slate-200/80 rounded-xl p-4 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              {selectedEmployee ? (
                <>
                  <Avatar className="w-10 h-10 border border-indigo-200">
                    {selectedEmployee.avatarUrl && (
                      <AvatarImage src={selectedEmployee.avatarUrl} alt={selectedEmployee.fullName} />
                    )}
                    <AvatarFallback className="bg-indigo-100 text-indigo-700 font-bold text-xs">
                      {selectedEmployee.fullName.slice(0, 2).toUpperCase()}
                    </AvatarFallback>
                  </Avatar>
                  <div>
                    <div className="font-bold text-slate-800 text-sm flex items-center gap-2">
                      <span>{selectedEmployee.fullName}</span>
                      <Badge variant="outline" className="text-[10px] font-mono py-0">
                        {selectedEmployee.employeeCode || `ID #${selectedEmployee.employeeId}`}
                      </Badge>
                    </div>
                    <div className="text-xs text-slate-500">
                      {selectedEmployee.designation || "Employee"} •{" "}
                      {selectedEmployee.department || "General"}
                    </div>
                  </div>
                </>
              ) : (
                <div>
                  <div className="font-bold text-slate-800 text-sm">
                    Company-Wide Audit Trail (All Workforce)
                  </div>
                  <div className="text-xs text-slate-500">
                    Showing changes recorded across all employee records in your organization
                  </div>
                </div>
              )}
            </div>

            {selectedEmployee && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setSelectedEmployeeId(null);
                  setPage(1);
                }}
                className="text-xs h-7 text-indigo-600 hover:text-indigo-800 hover:bg-indigo-50"
              >
                Clear Selection
              </Button>
            )}
          </div>

          {/* Filters Bar */}
          <div className="bg-white border border-slate-200/80 rounded-xl p-3 shadow-sm flex flex-wrap items-center gap-2.5">
            {/* Search within logs */}
            <div className="relative flex-1 min-w-[200px]">
              <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <Input
                type="text"
                placeholder="Search field, value, reason, actor..."
                value={logSearch}
                onChange={(e) => {
                  setLogSearch(e.target.value);
                  setPage(1);
                }}
                className="pl-9 h-8 text-xs bg-slate-50/50"
              />
            </div>

            {/* Module / Table Filter */}
            <div className="w-[180px]">
              <Select
                value={selectedTable}
                onValueChange={(val) => {
                  setSelectedTable(val);
                  setPage(1);
                }}
              >
                <SelectTrigger className="h-8 text-xs bg-slate-50/50">
                  <SelectValue placeholder="All Modules / Sections" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Modules & Sections</SelectItem>
                  <SelectItem value="attendance">Attendance & Punches</SelectItem>
                  <SelectItem value="leave_records">Leave & Approvals</SelectItem>
                  <SelectItem value="crm_leads">CRM & Sales Leads</SelectItem>
                  <SelectItem value="tasks">Tasks & Work Orders</SelectItem>
                  <SelectItem value="dpr_records">ERP, BOQ & DPR</SelectItem>
                  <SelectItem value="admin_roles">Roles & RBAC</SelectItem>
                  <SelectItem value="salary_records">Salary & Payroll</SelectItem>
                  <SelectItem value="employee_personal_info">Profile: Personal Info</SelectItem>
                  <SelectItem value="employee_general_info">Profile: Employment</SelectItem>
                  <SelectItem value="employee_addresses">Profile: Addresses</SelectItem>
                  <SelectItem value="employee_bank_info">Profile: Bank Details</SelectItem>
                  <SelectItem value="family_members">Profile: Family Members</SelectItem>
                  <SelectItem value="employees">Profile: Documents</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Start Date */}
            <div className="w-[130px]">
              <Input
                type="date"
                value={startDate}
                onChange={(e) => {
                  setStartDate(e.target.value);
                  setPage(1);
                }}
                className="h-8 text-xs bg-slate-50/50 px-2"
                title="From Date"
              />
            </div>

            {/* End Date */}
            <div className="w-[130px]">
              <Input
                type="date"
                value={endDate}
                onChange={(e) => {
                  setEndDate(e.target.value);
                  setPage(1);
                }}
                className="h-8 text-xs bg-slate-50/50 px-2"
                title="To Date"
              />
            </div>

            {/* Quick Date Presets */}
            <div className="flex items-center gap-1 border-l pl-2 border-slate-200">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setDatePreset("today")}
                className="h-7 px-2 text-[11px] text-slate-600 hover:text-slate-900"
              >
                Today
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setDatePreset("yesterday")}
                className="h-7 px-2 text-[11px] text-slate-600 hover:text-slate-900"
              >
                Yesterday
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setDatePreset("7days")}
                className="h-7 px-2 text-[11px] text-slate-600 hover:text-slate-900"
              >
                7 Days
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setDatePreset("30days")}
                className="h-7 px-2 text-[11px] text-slate-600 hover:text-slate-900"
              >
                30 Days
              </Button>
            </div>

            {/* Reset */}
            {(logSearch || selectedTable !== "all" || startDate || endDate || selectedCategory !== "ALL") && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setSelectedCategory("ALL");
                  handleResetFilters();
                }}
                className="h-8 text-xs text-slate-500 hover:text-slate-800"
                title="Reset filters"
              >
                <RotateCcw className="w-3.5 h-3.5 mr-1" />
                Reset
              </Button>
            )}
          </div>

          {/* Activity Category Filter Pills */}
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
            <button
              type="button"
              onClick={() => {
                setSelectedCategory("ALL");
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 border shrink-0 ${
                selectedCategory === "ALL"
                  ? "bg-indigo-600 text-white border-indigo-600 shadow-sm"
                  : "bg-white text-slate-600 border-slate-200 hover:bg-slate-50"
              }`}
            >
              <Layers className="w-3.5 h-3.5" />
              All Activities
            </button>
            <button
              type="button"
              onClick={() => {
                setSelectedCategory("CLICK");
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 border shrink-0 ${
                selectedCategory === "CLICK"
                  ? "bg-cyan-600 text-white border-cyan-600 shadow-sm"
                  : "bg-white text-slate-600 border-slate-200 hover:bg-slate-50"
              }`}
            >
              <MousePointerClick className="w-3.5 h-3.5 text-cyan-500 group-hover:text-cyan-600" />
              Clicks
            </button>
            <button
              type="button"
              onClick={() => {
                setSelectedCategory("VIEW");
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 border shrink-0 ${
                selectedCategory === "VIEW"
                  ? "bg-purple-600 text-white border-purple-600 shadow-sm"
                  : "bg-white text-slate-600 border-slate-200 hover:bg-slate-50"
              }`}
            >
              <Compass className="w-3.5 h-3.5 text-purple-500" />
              Page Navigation
            </button>
            <button
              type="button"
              onClick={() => {
                setSelectedCategory("ACTION");
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 border shrink-0 ${
                selectedCategory === "ACTION"
                  ? "bg-amber-600 text-white border-amber-600 shadow-sm"
                  : "bg-white text-slate-600 border-slate-200 hover:bg-slate-50"
              }`}
            >
              <Zap className="w-3.5 h-3.5 text-amber-500" />
              System Actions
            </button>
            <button
              type="button"
              onClick={() => {
                setSelectedCategory("DIFF");
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 border shrink-0 ${
                selectedCategory === "DIFF"
                  ? "bg-indigo-600 text-white border-indigo-600 shadow-sm"
                  : "bg-white text-slate-600 border-slate-200 hover:bg-slate-50"
              }`}
            >
              <FileEdit className="w-3.5 h-3.5 text-indigo-500" />
              Data Edits
            </button>
          </div>

          {/* Audit Logs Table */}
          <AuditLogTable
            logs={logs}
            pagination={pagination}
            loading={loadingLogs}
            onPageChange={(newPage) => setPage(newPage)}
            hideEmployeeCol={selectedEmployeeId !== null}
          />
        </div>
      </div>
    </div>
  );
}
