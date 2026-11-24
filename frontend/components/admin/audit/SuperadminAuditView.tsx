"use client";

import React, { useState, useMemo } from "react";
import {
  useSuperadminAuditHierarchy,
  useSuperadminTenantEmployees,
  useSuperadminAuditLogs,
  type SuperadminTenantHierarchy,
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
  Building2,
  Users,
  Search,
  Filter,
  Download,
  RotateCcw,
  Shield,
  Activity,
  Calendar,
  Layers,
  ChevronRight,
  UserCheck,
  Globe,
  MousePointerClick,
  Compass,
  Zap,
  FileEdit,
} from "lucide-react";

export function SuperadminAuditView() {
  const [selectedOrgId, setSelectedOrgId] = useState<string | null>(null);
  const [selectedEmployeeId, setSelectedEmployeeId] = useState<number | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<string>("ALL");
  const [orgSearch, setOrgSearch] = useState("");
  const [employeeSearch, setEmployeeSearch] = useState("");
  const [logSearch, setLogSearch] = useState("");
  const [selectedTable, setSelectedTable] = useState<string>("all");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [page, setPage] = useState(1);

  // Tier 1: Organization & Admin hierarchy
  const { hierarchy, loading: loadingHierarchy, refetch: refetchHierarchy } = useSuperadminAuditHierarchy();

  // Tier 2: Employees under selected organization
  const { employees, loading: loadingEmployees } = useSuperadminTenantEmployees(
    selectedOrgId ?? undefined,
    employeeSearch,
  );

  // Tier 3: Audit logs stream
  const { logs, pagination, loading: loadingLogs, refetch: refetchLogs } = useSuperadminAuditLogs({
    organizationId: selectedOrgId ?? undefined,
    employeeId: selectedEmployeeId ?? undefined,
    category: selectedCategory !== "ALL" ? selectedCategory : undefined,
    tableName: selectedTable !== "all" ? selectedTable : undefined,
    search: logSearch || undefined,
    startDate: startDate || undefined,
    endDate: endDate || undefined,
    page,
    limit: 50,
  });

  const selectedOrg = useMemo(() => {
    if (!selectedOrgId) return null;
    return hierarchy.find((h) => h.organizationId === selectedOrgId) ?? null;
  }, [selectedOrgId, hierarchy]);

  const selectedEmployee = useMemo(() => {
    if (!selectedEmployeeId) return null;
    return employees.find((e) => e.employeeId === selectedEmployeeId) ?? null;
  }, [selectedEmployeeId, employees]);

  const filteredHierarchy = useMemo(() => {
    if (!orgSearch.trim()) return hierarchy;
    const q = orgSearch.toLowerCase().trim();
    return hierarchy.filter(
      (h) =>
        h.organizationName.toLowerCase().includes(q) ||
        h.organizationCode.toLowerCase().includes(q) ||
        h.admins.some((a) => a.fullName.toLowerCase().includes(q) || a.username.toLowerCase().includes(q)),
    );
  }, [hierarchy, orgSearch]);

  const totalPlatformLogs = useMemo(() => {
    return hierarchy.reduce((acc, h) => acc + h.totalLogs, 0);
  }, [hierarchy]);

  const handleResetFilters = () => {
    setLogSearch("");
    setSelectedTable("all");
    setStartDate("");
    setEndDate("");
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
    link.setAttribute("download", `superadmin_audit_${selectedOrg?.organizationCode || "global"}_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-800 tracking-tight flex items-center gap-2">
            <Shield className="w-6 h-6 text-indigo-600" />
            Superadmin Platform Audit Explorer
          </h1>
          <p className="text-xs md:text-sm text-slate-500 mt-1">
            Hierarchical drill-down: Select a <strong className="text-slate-700">Company & Admin</strong>, then browse <strong className="text-slate-700">Employee-wise</strong> logs across all tenants.
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
            onClick={() => {
              refetchHierarchy();
              refetchLogs();
            }}
            className="text-xs h-9 text-slate-600 hover:text-slate-900"
          >
            <RotateCcw className="w-3.5 h-3.5" />
          </Button>
        </div>
      </div>

      {/* Breadcrumb Hierarchy Indicator */}
      <div className="bg-slate-50 border border-slate-200 rounded-lg px-4 py-2 text-xs flex items-center gap-2 flex-wrap text-slate-600">
        <button
          type="button"
          onClick={() => {
            setSelectedOrgId(null);
            setSelectedEmployeeId(null);
            setPage(1);
          }}
          className={`hover:underline flex items-center gap-1 font-semibold ${
            selectedOrgId === null ? "text-indigo-600 font-bold" : "text-slate-600"
          }`}
        >
          <Globe className="w-3.5 h-3.5" />
          All Tenants (Global)
        </button>

        {selectedOrg && (
          <>
            <ChevronRight className="w-3.5 h-3.5 text-slate-400" />
            <button
              type="button"
              onClick={() => {
                setSelectedEmployeeId(null);
                setPage(1);
              }}
              className={`hover:underline flex items-center gap-1 font-semibold ${
                selectedEmployeeId === null ? "text-indigo-600 font-bold" : "text-slate-600"
              }`}
            >
              <Building2 className="w-3.5 h-3.5" />
              {selectedOrg.organizationName}
              <span className="text-[10px] text-slate-400 font-mono">({selectedOrg.organizationCode})</span>
            </button>
          </>
        )}

        {selectedEmployee && (
          <>
            <ChevronRight className="w-3.5 h-3.5 text-slate-400" />
            <span className="font-bold text-indigo-700 flex items-center gap-1">
              <Users className="w-3.5 h-3.5" />
              {selectedEmployee.fullName}
              <span className="text-[10px] text-indigo-500 font-mono">
                ({selectedEmployee.employeeCode || `#${selectedEmployee.employeeId}`})
              </span>
            </span>
          </>
        )}
      </div>

      {/* Level 1: Organization & Admin Selector Carousel / Cards */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <div className="text-xs font-bold uppercase tracking-wider text-slate-500 flex items-center gap-1.5">
            <Building2 className="w-4 h-4 text-indigo-600" />
            1. Select Client Company & Admin
          </div>
          <div className="w-[220px]">
            <Input
              type="text"
              placeholder="Filter companies or admins..."
              value={orgSearch}
              onChange={(e) => setOrgSearch(e.target.value)}
              className="h-7 text-xs bg-white"
            />
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          {/* Global Card */}
          <button
            type="button"
            onClick={() => {
              setSelectedOrgId(null);
              setSelectedEmployeeId(null);
              setPage(1);
            }}
            className={`text-left p-3.5 rounded-xl border transition-all ${
              selectedOrgId === null
                ? "bg-indigo-50/90 border-indigo-300 ring-2 ring-indigo-400/30 shadow-sm"
                : "bg-white border-slate-200/80 hover:bg-slate-50"
            }`}
          >
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-xs font-bold text-indigo-900 flex items-center gap-1.5">
                <Globe className="w-4 h-4 text-indigo-600" />
                Global Platform
              </span>
              <Badge variant="secondary" className="text-[10px] font-bold bg-white">
                {totalPlatformLogs.toLocaleString()}
              </Badge>
            </div>
            <div className="text-[11px] text-slate-500 line-clamp-1">
              Cross-tenant view across all {hierarchy.length} registered companies
            </div>
          </button>

          {/* Org Cards */}
          {loadingHierarchy ? (
            Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="p-3.5 rounded-xl border border-slate-200 bg-white animate-pulse space-y-2">
                <div className="h-4 bg-slate-200 rounded w-3/4" />
                <div className="h-3 bg-slate-100 rounded w-1/2" />
              </div>
            ))
          ) : (
            filteredHierarchy.map((org) => {
              const isSelected = selectedOrgId === org.organizationId;
              const primaryAdmin = org.admins[0];
              return (
                <button
                  key={org.organizationId}
                  type="button"
                  onClick={() => {
                    setSelectedOrgId(org.organizationId);
                    setSelectedEmployeeId(null);
                    setPage(1);
                  }}
                  className={`text-left p-3.5 rounded-xl border transition-all ${
                    isSelected
                      ? "bg-indigo-50/90 border-indigo-300 ring-2 ring-indigo-400/30 shadow-sm"
                      : "bg-white border-slate-200/80 hover:bg-slate-50"
                  }`}
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs font-bold text-slate-800 truncate" title={org.organizationName}>
                      {org.organizationName}
                    </span>
                    <Badge
                      variant="secondary"
                      className={`text-[10px] font-bold shrink-0 ${
                        isSelected ? "bg-indigo-600 text-white" : "bg-slate-100 text-slate-700"
                      }`}
                    >
                      {org.totalLogs} logs
                    </Badge>
                  </div>

                  <div className="text-[11px] text-slate-500 flex items-center gap-1.5 mb-1 truncate">
                    <UserCheck className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <span className="truncate">
                      Admin:{" "}
                      <strong className="text-slate-700">
                        {primaryAdmin ? primaryAdmin.fullName : "Native Admin"}
                      </strong>
                    </span>
                  </div>

                  <div className="flex items-center justify-between text-[10px] text-slate-400 pt-1 border-t border-slate-100/80">
                    <span>{org.totalEmployees} Employees</span>
                    <span className="font-mono">{org.organizationCode}</span>
                  </div>
                </button>
              );
            })
          )}
        </div>
      </div>

      {/* Main Content: Level 2 Employee Drill-down & Level 3 Logs Stream */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 items-start">
        {/* Level 2: Employee Selector under Selected Company (4 cols) */}
        <div className="lg:col-span-4 bg-white border border-slate-200/80 rounded-xl shadow-sm p-4 space-y-3">
          <div className="flex items-center justify-between border-b pb-2.5">
            <div className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <Users className="w-4 h-4 text-indigo-600" />
              2. Company Workforce
            </div>
            {selectedOrg && (
              <Badge variant="outline" className="text-[10px] font-mono">
                {selectedOrg.organizationCode}
              </Badge>
            )}
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
              disabled={!selectedOrgId}
            />
          </div>

          {/* "All Employees of Company" Button */}
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
                <div className="font-semibold text-slate-800">
                  {selectedOrg ? `All ${selectedOrg.organizationCode} Logs` : "All Cross-Tenant Logs"}
                </div>
                <div className="text-[10px] text-slate-400">View entire tenant log stream</div>
              </div>
            </div>
            <Badge variant="secondary" className="text-[10px] bg-white border font-bold">
              {selectedOrg ? selectedOrg.totalLogs : totalPlatformLogs}
            </Badge>
          </button>

          {/* Employee List */}
          <div className="space-y-1 max-h-[500px] overflow-y-auto pr-1">
            {!selectedOrgId ? (
              <div className="text-center py-10 px-4 text-slate-400 text-xs">
                <Building2 className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                Select a client company above to drill into individual employees.
              </div>
            ) : loadingEmployees ? (
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
                No employees found in this tenant
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

        {/* Level 3: Logs Stream (8 cols) */}
        <div className="lg:col-span-8 space-y-4">
          {/* Active Scope Banner */}
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
                      Company: <strong className="text-slate-700">{selectedOrg?.organizationName}</strong> •{" "}
                      {selectedEmployee.designation || "Employee"}
                    </div>
                  </div>
                </>
              ) : selectedOrg ? (
                <div>
                  <div className="font-bold text-slate-800 text-sm flex items-center gap-2">
                    <Building2 className="w-4 h-4 text-indigo-600" />
                    <span>{selectedOrg.organizationName}</span>
                    <Badge variant="secondary" className="text-[10px] font-mono">
                      {selectedOrg.organizationCode}
                    </Badge>
                  </div>
                  <div className="text-xs text-slate-500">
                    Showing all activity logs recorded for this tenant's employees and admins
                  </div>
                </div>
              ) : (
                <div>
                  <div className="font-bold text-slate-800 text-sm flex items-center gap-2">
                    <Globe className="w-4 h-4 text-indigo-600" />
                    <span>Global Cross-Tenant Platform Stream</span>
                  </div>
                  <div className="text-xs text-slate-500">
                    Showing logs across all registered organizations on the SaaS platform
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
                Clear Employee Selection
              </Button>
            )}
          </div>

          {/* Filters Bar */}
          <div className="bg-white border border-slate-200/80 rounded-xl p-3 shadow-sm flex flex-wrap items-center gap-2.5">
            {/* Search */}
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

            {/* Module Filter */}
            <div className="w-[180px]">
              <Select
                value={selectedTable}
                onValueChange={(val) => {
                  setSelectedTable(val);
                  setPage(1);
                }}
              >
                <SelectTrigger className="h-8 text-xs bg-slate-50/50">
                  <SelectValue placeholder="All Sections" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Sections</SelectItem>
                  <SelectItem value="employee_personal_info">Personal Info</SelectItem>
                  <SelectItem value="employee_general_info">General Employment</SelectItem>
                  <SelectItem value="employee_addresses">Addresses</SelectItem>
                  <SelectItem value="employee_bank_info">Bank Details</SelectItem>
                  <SelectItem value="employee_other_info">Other Details</SelectItem>
                  <SelectItem value="family_members">Family Members</SelectItem>
                  <SelectItem value="employees">Employee Documents</SelectItem>
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
              <MousePointerClick className="w-3.5 h-3.5 text-cyan-500" />
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
