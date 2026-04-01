# HRMS Frontend — Day 1 Completion Status

> Last updated: 2026-03-31 | Based on `day1.md` roadmap

---

## User Panel (Employee Self-Service)

### Module 1 — Profile ✅ Completed
- [x] View own profile — photo, name, ID, designation *(ProfileHeader component)*
- [x] General info — view only (HR edits this) *(GeneralTab — read-only for employees)*
- [x] Personal info — view + edit (pending HR approval) *(PersonalTab + ChangeRequest workflow)*
- [x] Local + permanent address — view + edit *(AddressTab — pending HR approval integrated)*
- [x] Other info — skills, hobbies, height, weight *(OtherTab — view + edit)*
- [x] Family members — add, edit, soft delete *(FamilyTab — isActive=false hides from all views)*
- [x] Academic qualifications — add degrees, upload sem-wise marksheets *(EducationTab — Sem 1–8 individual upload slots)*
- [x] Document uploads — Aadhaar card, PAN card, photo, signature *(DocumentsTab — upload via Cloudinary)*

> ⚠️ **Note:** Personal and Address tabs have the HR approval workflow stabilized and fully integrated. Other, Family, and Academic modules currently save directly or are pending issue resolution, which will be tackled in a later phase.

### Module 2 — Leave Management
- [ ] Apply for leave (CL, EL, ML, LOP, comp-off)
- [ ] View leave balance
- [ ] View leave history + status (pending/approved/rejected)
- [ ] Cancel pending leave request

> 🔴 **Backend not started** — Do not build frontend yet.

### Module 3 — Attendance
- [ ] View own attendance calendar
- [ ] View monthly attendance summary
- [ ] Mark manual attendance (if applicable)

> 🔴 **Backend not started** — Do not build frontend yet.

### Module 4 — Payroll & Salary
- [ ] View monthly payslips
- [ ] Download payslip as PDF
- [ ] View salary breakdown (basic, HRA, DA, allowances, deductions)
- [ ] Submit investment declarations (80C, HRA proofs)

> 🔴 **Backend not started** — Do not build frontend yet.

### Module 5 — Bank Details
- [ ] View own bank details (masked account number)
- [ ] Request bank details change (pending HR approval)

> 🔴 **Backend not started** — Do not build frontend yet.

### Module 6 — Notifications
- [ ] In-app notifications for approvals, rejections, announcements
- [ ] Mark as read

> 🔴 **Backend not started** — Do not build frontend yet.

---

## Admin / HR Panel

### Module 1 — Employee Management ✅ Completed
- [x] Employee list with search, filter by dept/category/status
- [x] View full employee profile (all sections)
- [x] Create new employee account *(AddEmployeeDialog + POST /api/employees/full)*
- [x] Edit any employee's general info, verify documents *(Admin profile tabs — isAdmin=true)*
- [x] Approve/reject employee profile change requests *(Admin Approvals Dashboard — diff view)*
- [x] View audit log per employee *(AuditLog drawer)*
- [x] Reset employee password *(POST /api/auth/reset-password/:userId)*

### Module 2 — Leave Management (Admin)
- [ ] View all leave requests across departments
- [ ] Approve/reject leave requests
- [ ] Configure leave types and balances
- [ ] View leave calendar across teams
- [ ] Generate leave reports

> 🔴 **Backend not started.**

### Module 3 — Attendance Management
- [ ] View attendance for all employees
- [ ] Mark/correct attendance manually
- [ ] Configure shifts and rosters
- [ ] Generate attendance reports

> 🔴 **Backend not started.**

### Module 4 — Payroll Management
- [ ] Run monthly payroll
- [ ] Configure salary structures
- [ ] Process payslips
- [ ] Handle arrears and revisions
- [ ] PF/ESIC/PT deduction management
- [ ] Form 16 generation

> 🔴 **Backend not started.**

### Module 5 — Dynamic Field Manager
- [ ] Add/remove/reorder custom fields per section
- [ ] Configure field types (text, dropdown, file)
- [ ] Manage dropdown options
- [ ] Soft delete fields (data preserved)

> 🔴 **Backend not started.**

### Module 6 — Role & Permission Manager ✅ Completed
- [x] Create/edit/delete roles *(Admin Roles page)*
- [x] Assign per-module per-action permissions *(Permission matrix — READ/WRITE/APPROVE/DELETE/EXPORT)*
- [x] View all users and their roles
- [x] Change user roles
- [x] Bulk session invalidation on permission change *(Backend handles via Redis)*

### Module 7 — User Management ✅ Completed
- [x] Create user accounts for employees *(AddUserDialog)*
- [x] Activate/deactivate accounts *(PATCH /api/admin/users/:id)*
- [x] Reset passwords *(POST /api/auth/reset-password/:userId)*
- [x] View login history *(lastLoginAt column in users table)*

### Module 8 — Reports & Analytics
- [ ] Employee headcount by department/category
- [ ] Leave utilization reports
- [ ] Attendance summary reports
- [ ] Payroll expense reports
- [ ] Export to PDF/Excel

> 🔴 **Backend not started.**

### Module 9 — Notifications & Announcements
- [ ] Send announcements to all or specific departments
- [ ] Configure email notifications
- [ ] View notification history

> 🔴 **Backend not started.**

---

## Shared Between Both Panels ✅ Completed
- [x] Login page — Employee ID + password
- [x] Force password change on first login *(isFirstLogin flag + redirect)*
- [x] Change password screen *(available from profile)*
- [ ] Notification bell with dropdown *(backend not ready)*

---

## What's Backend-Ready & Frontend Status

| Module | Backend | Frontend |
|---|---|---|
| Profile (Module 1) | ✅ Done | ✅ **Done** |
| Auth + Login | ✅ Done | ✅ **Done** |
| Role & Permission Manager | ✅ Done | ✅ **Done** |
| User Management | ✅ Done | ✅ **Done** |
| Approval Workflow | ✅ Done | ✅ **Done** |
| Dynamic Field Manager | 🔴 Not started | ⬜ Waiting |
| Leave Management | 🔴 Not started | ⬜ Waiting |
| Attendance | 🔴 Not started | ⬜ Waiting |
| Payroll | 🔴 Not started | ⬜ Waiting |
| Bank Details | 🔴 Not started | ⬜ Waiting |
| Reports | 🔴 Not started | ⬜ Waiting |
| Notifications | 🔴 Not started | ⬜ Waiting |

---

## Key Infrastructure Implemented

| Item | Status |
|---|---|
| NextAuth session (JWT) | ✅ |
| Force password change flow | ✅ |
| Hasura GraphQL (Address, Family, Academic) | ✅ |
| REST API (all profile endpoints) | ✅ |
| Cloudinary file uploads | ✅ |
| ChangeRequest approval workflow | ✅ |
| Soft-delete (Family + Academic) | ✅ |
| Audit Log (all profile sections) | ✅ |
| Docker (PostgreSQL + Redis + Hasura) live-sync | ✅ |
