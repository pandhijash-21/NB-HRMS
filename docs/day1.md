Based on everything we've built in the backend, here's the complete picture:

---

## User Panel (Employee Self-Service)

### Module 1 — Profile (current module, in progress)
- View own profile — photo, name, ID, designation
- General info — view only (HR edits this)
- Personal info — view + edit (pending HR approval)
- Local + permanent address — view + edit
- Other info — skills, hobbies, height, weight
- Family members — add, edit, soft delete
- Academic qualifications — add degrees, upload sem-wise marksheets
- Document uploads — Aadhaar card, PAN card, photo, signature

### Module 2 — Leave Management
- Apply for leave (CL, EL, ML, LOP, comp-off)
- View leave balance
- View leave history + status (pending/approved/rejected)
- Cancel pending leave request

### Module 3 — Attendance
- View own attendance calendar
- View monthly attendance summary
- Mark manual attendance (if applicable)

### Module 4 — Payroll & Salary
- View monthly payslips
- Download payslip as PDF
- View salary breakdown (basic, HRA, DA, allowances, deductions)
- Submit investment declarations (80C, HRA proofs)

### Module 5 — Bank Details
- View own bank details (masked account number)
- Request bank details change (pending HR approval)

### Module 6 — Notifications
- In-app notifications for approvals, rejections, announcements
- Mark as read

---

## Admin / HR Panel

### Module 1 — Employee Management
- Employee list with search, filter by dept/category/status
- View full employee profile (all sections)
- Create new employee account
- Edit any employee's general info, verify documents
- Approve/reject employee profile change requests
- View audit log per employee
- Reset employee password

### Module 2 — Leave Management
- View all leave requests across departments
- Approve/reject leave requests
- Configure leave types and balances
- View leave calendar across teams
- Generate leave reports

### Module 3 — Attendance Management
- View attendance for all employees
- Mark/correct attendance manually
- Configure shifts and rosters
- Generate attendance reports

### Module 4 — Payroll Management
- Run monthly payroll
- Configure salary structures (CTC, HRA, DA, allowances)
- Process payslips and send to employees
- Handle arrears and revisions
- PF/ESIC/PT deduction management
- Form 16 generation

### Module 5 — Dynamic Field Manager
- Add/remove/reorder custom fields per section
- Configure field types (text, dropdown, file etc.)
- Manage dropdown options
- Soft delete fields (data preserved)

### Module 6 — Role & Permission Manager
- Create/edit/delete roles
- Assign per-module per-action permissions
- View all users and their roles
- Change user roles
- Bulk session invalidation on permission change

### Module 7 — User Management
- Create user accounts for employees
- Activate/deactivate accounts
- Reset passwords
- View login history

### Module 8 — Reports & Analytics
- Employee headcount by department/category
- Leave utilization reports
- Attendance summary reports
- Payroll expense reports
- Export to PDF/Excel

### Module 9 — Notifications & Announcements
- Send announcements to all or specific departments
- Configure email notifications
- View notification history

---

## Shared Between Both Panels

- Login page (Employee ID + password)
- Force password change on first login
- Change password screen
- Notification bell with dropdown

---

## What's Backend-Ready Right Now

| Module | Backend Status |
|---|---|
| Profile (Module 1) | ✅ Fully done |
| Auth + Login | ✅ Fully done |
| Role & Permission Manager | ✅ Fully done |
| User Management | ✅ Fully done |
| Dynamic Field Manager | 🔴 Not started |
| Leave Management | 🔴 Not started |
| Attendance | 🔴 Not started |
| Payroll | 🔴 Not started |
| Bank Details | 🔴 Not started |
| Reports | 🔴 Not started |

---

So right now your frontend guy can fully build:
- The entire employee profile section
- Login + password change flow
- Admin user management
- Admin role + permission manager

Everything else needs backend work first before frontend can start on it.

Based on backend status, here's what's fully ready for frontend development right now:

---

## 1. Login & Auth Flow

**Employee panel:**
- Login page — Employee ID + password
- Force password change screen (triggers when `isFirstLogin = true`)
- Change password screen (available anytime from profile)

**Backend endpoints ready:**
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `POST /api/auth/change-password`
- `GET /api/auth/me`

---

## 2. Employee Profile (Full Module 1)

**Employee panel:**
- Profile header — photo, signature, name, ID, abbreviation, status badge
- General info tab — view only
- Personal info tab — view + edit (Aadhaar/PAN masked)
- Local address tab — view + edit
- Permanent address tab — view + edit
- Other info tab — skills, hobbies, height, weight, handicap
- Family members tab — table with add/edit/soft delete
- Education tab — per-degree cards, sem-wise marksheet uploads, certificate upload

**Backend endpoints ready:**
- `GET/POST/PATCH /api/employees/:id/general`
- `GET/POST/PATCH /api/employees/:id/personal`
- `GET/POST/PATCH /api/employees/:id/address/:type`
- `GET/POST/PATCH /api/employees/:id/other`
- `GET/POST/PATCH/DELETE /api/employees/:id/family`
- `GET/POST/PATCH /api/employees/:id/academic`
- All 6 upload endpoints

---

## 3. Admin — Employee Management

**Admin panel:**
- Employee list table — search, filter by department/category/status
- Click employee → full profile view (same components as employee panel, read-only)
- Create new employee form
- Edit any section of any employee profile
- Approve/reject profile change requests
- View audit log drawer per employee
- Reset employee password button

**Backend endpoints ready:**
- Everything from Module 1 above
- `GET /api/employees/:id/audit-log`
- `POST /api/auth/reset-password/:userId`

---

## 4. Admin — User Management

**Admin panel:**
- Users list table — search, filter by role/status
- Create user account form — pick employee + assign role
- Edit user — change role, activate/deactivate
- Delete user (soft delete)
- Last login column

**Backend endpoints ready:**
- `GET /api/admin/users`
- `GET /api/admin/users/:id`
- `POST /api/admin/users`
- `PATCH /api/admin/users/:id`
- `DELETE /api/admin/users/:id`

---

## 5. Admin — Role & Permission Manager

**Admin panel:**
- Roles list — name, description, user count, active/inactive
- Create new role form
- Edit role name/description
- Permission matrix screen per role:
  - Rows = all 12 system modules
  - Columns = READ / WRITE / APPROVE / DELETE / EXPORT
  - Toggle checkboxes per cell
  - Save → instantly invalidates all sessions for that role
- Delete role (blocked if users assigned)

**Backend endpoints ready:**
- `GET/POST /api/admin/roles`
- `GET/PATCH/DELETE /api/admin/roles/:id`
- `GET /api/admin/modules`
- `GET/PUT /api/admin/roles/:roleId/permissions`
- `PATCH /api/admin/roles/:roleId/permissions/:moduleKey`

---

## Summary

| Frontend Surface | Complexity | Backend Ready |
|---|---|---|
| Login + auth flow | Low | ✅ |
| Employee profile (all tabs) | High | ✅ |
| Admin employee list + view | Medium | ✅ |
| Admin user management | Medium | ✅ |
| Admin role + permission manager | Medium | ✅ |

---

These 5 surfaces are what your frontend guy should focus on right now. Everything else waits for backend Module 2 onwards.
