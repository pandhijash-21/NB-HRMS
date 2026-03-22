# HR Management System — Gandhinagar University (HRMS-GU)

A comprehensive Human Resource Management System for Gandhinagar University. Covers employee profile management, sensitive data handling with AES-256 encryption, document uploads via Cloudinary, family & academic records, full audit logging, JWT-based auth with Redis sessions, and a dynamic role-based permission system.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Next.js 14 (App Router), TypeScript, Tailwind CSS v4, Shadcn/ui |
| Auth | NextAuth.js v5 (Credentials provider, JWT sessions) |
| GraphQL Client | Apollo Client v4 → Hasura |
| REST Client | Axios → Express backend |
| Backend | Node.js + Express 5, TypeScript, Prisma v6 |
| Database | PostgreSQL 15 |
| GraphQL Engine | Hasura GraphQL Engine |
| Cache / Sessions | Redis (node-redis v5) |
| File Storage | Cloudinary v2 (via Multer memory storage) |
| Encryption | AES-256-CBC (Node.js `crypto`) — Aadhaar & PAN encrypted at rest |
| Audit | Append-only `AuditLog` table; every sensitive write is diffed and logged |
| Containerization | Docker & Docker Compose |

---

## Prerequisites

- **Node.js v20+** — [nodejs.org](https://nodejs.org/)
- **Docker Desktop** — [docker.com](https://www.docker.com/products/docker-desktop/)
- **Git** — [git-scm.com](https://git-scm.com/)
- **Hasura CLI** *(optional, for metadata management)* — [hasura.io/docs/latest/hasura-cli/install-hasura-cli](https://hasura.io/docs/latest/hasura-cli/install-hasura-cli/)

---

## First-time Setup

### 1. Clone

```bash
git clone https://github.com/Cipher-Shadow-IR/HR-Management-System.git
cd HR-Management-System
```

### 2. Install dependencies

```bash
cd backend && npm install && cd ..
cd frontend && npm install && cd ..
```

### 3. Configure environment variables

**Backend** — copy example and fill in secrets:

```bash
cd backend
cp .env.example .env
```

Edit `backend/.env`:

```env
DATABASE_URL=postgres://hrms_user:hrms_pass@localhost:5433/hrms_db
REDIS_URL=redis://localhost:6380
JWT_SECRET=<at_least_32_random_chars>
ENCRYPTION_KEY=<exactly_64_hex_chars>
PORT=4000

# Cloudinary (optional — uploads won't work without it)
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:9695
FRONTEND_URL=http://localhost:3000

# Email notifications (optional — silently skipped if not set)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=
SMTP_PASS=
SMTP_FROM=noreply@gandhinagaruni.ac.in
```

Generate `ENCRYPTION_KEY`:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

**Frontend** — create `frontend/.env`:

```env
DATABASE_URL=postgres://hrms_user:hrms_pass@localhost:5433/hrms_db
NEXT_PUBLIC_HASURA_URL=http://localhost:8080/v1/graphql
NEXT_PUBLIC_API_URL=http://127.0.0.1:4000/api
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=<any_random_string>
```

> **Note:** Use `127.0.0.1` (not `localhost`) in `NEXT_PUBLIC_API_URL` to avoid IPv6/IPv4 resolution issues on Windows.

### 4. Start infrastructure

```bash
docker compose up -d postgres redis hasura
```

This starts **PostgreSQL** (port `5433`), **Redis** (internal only), and **Hasura** (port `8080`).

> Do **not** start the Docker `backend` service during development — run it locally instead (step 6).

### 5. Run database migration & seed

```bash
cd backend
npx prisma migrate dev --name init_all
npx prisma generate
npx prisma db seed
cd ..
```

The seed creates:
- 12 system modules (PERSONAL_INFO, PAYROLL, LEAVE, etc.)
- 6 default roles (ADMIN, HOI, HR, HOD, FINANCE, EMPLOYEE) with full permission matrix
- Default admin account: **Employee ID `1`**, password **`01011990`**

### 6. Start the backend locally

```bash
cd backend
npm run dev
```

Wait for:
```
Redis connected
Server running on port 4000
```

### 7. Start the frontend

```bash
cd frontend
npm run dev
```

App available at **[http://localhost:3000](http://localhost:3000)**

### 8. (Optional) Apply Hasura metadata

```bash
cd hasura
hasura metadata apply
# or open the console:
hasura console   # → http://localhost:9695
```

---

## Daily Development Startup

Every session (after the first-time setup):

```powershell
# 1. Open Docker Desktop and wait for engine to start

# 2. Start infrastructure containers
docker compose up -d postgres redis hasura

# 3. Make sure Docker backend is NOT running (local dev takes port 4000)
docker compose stop backend

# 4. Terminal 1 — backend
cd backend; npm run dev

# 5. Terminal 2 — frontend
cd frontend; npm run dev
```

---

## Accessing the Application

| Service | URL |
|---|---|
| **Landing page** | http://localhost:3000 |
| **Login** | http://localhost:3000/login |
| **Change Password** | http://localhost:3000/change-password |
| **Employee Portal** | http://localhost:3000/profile |
| **Admin Dashboard** | http://localhost:3000/admin/dashboard |
| **Employee List (Admin)** | http://localhost:3000/admin/employees |
| **Employee Profile (Admin)** | http://localhost:3000/admin/employees/`<id>` |
| **Backend Health** | http://localhost:4000/health |
| **Backend API** | http://localhost:4000/api |
| **Hasura Console** | http://localhost:8080 |
| **Hasura Console (CLI)** | http://localhost:9695 (via `hasura console`) |

---

## Login

The login page accepts **Employee ID + Password** (not email).

### Default admin account (created by seed)

| Field | Value |
|---|---|
| Employee ID | `1` |
| Password | `01011990` |
| Role | ADMIN |
| First login | Yes — you will be redirected to `/change-password` |

### First-login flow

1. Log in → system detects `isFirstLogin = true`
2. Automatically redirected to `/change-password`
3. Set a new password (min 8 chars, at least 1 letter + 1 number)
4. Redirected back to `/login`
5. Sign in with new password → land on `/admin/dashboard`

### Role-based redirects after login

| Role | Redirect |
|---|---|
| ADMIN, HR, HOI, FINANCE | `/admin/dashboard` |
| HOD, EMPLOYEE | `/profile` |

---

## Backend API Reference

Base URL: `http://localhost:4000`

### Auth endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/auth/login` | Public | Login with `{ employeeId, password }` → JWT |
| POST | `/api/auth/logout` | JWT | Invalidate Redis session |
| POST | `/api/auth/change-password` | JWT | Change own password (forces re-login) |
| GET | `/api/auth/me` | JWT | Current user profile + permissions |
| POST | `/api/auth/reset-password/:userId` | JWT + `USER_MGMT:WRITE` | Reset any user's password to DOB default |

### User management

| Method | Path | Permission |
|---|---|---|
| GET | `/api/admin/users` | `USER_MGMT:READ` |
| GET | `/api/admin/users/:id` | `USER_MGMT:READ` |
| POST | `/api/admin/users` | `USER_MGMT:WRITE` |
| PATCH | `/api/admin/users/:id` | `USER_MGMT:WRITE` |
| DELETE | `/api/admin/users/:id` | `USER_MGMT:DELETE` |

### Role & permission management

| Method | Path | Permission |
|---|---|---|
| GET/POST | `/api/admin/roles` | `ROLE_MGMT:READ/WRITE` |
| GET/PATCH/DELETE | `/api/admin/roles/:id` | `ROLE_MGMT:READ/WRITE/DELETE` |
| GET | `/api/admin/modules` | `ROLE_MGMT:READ` |
| GET/PUT | `/api/admin/roles/:roleId/permissions` | `ROLE_MGMT:READ/WRITE` |
| PATCH | `/api/admin/roles/:roleId/permissions/:moduleKey` | `ROLE_MGMT:WRITE` |

### Employee — Personal & Education module

All routes require JWT. HR/ADMIN/HOI guards noted where applicable.

| Method | Path | Guard | Description |
|---|---|---|---|
| POST | `/api/employees` | HR/ADMIN | Create employee |
| GET | `/api/employees/:id` | Auth | Get employee (all sections) |
| PATCH | `/api/employees/:id` | Auth | Update core employee fields |
| GET/POST/PATCH | `/api/employees/:id/general` | GET: Auth · Write: HR/ADMIN/HOI | General info (name, dept, joining date) |
| GET/POST/PATCH | `/api/employees/:id/personal` | Auth + audit | Personal info (DOB, gender — Aadhaar/PAN encrypted) |
| GET/POST/PATCH | `/api/employees/:id/address/:type` | Auth + audit | LOCAL or PERMANENT address |
| GET/POST/PATCH | `/api/employees/:id/other` | Auth + audit | Skills, hobbies, physical info |
| GET/POST/PATCH/DELETE | `/api/employees/:id/family[/:memberId]` | Auth + audit | Family members (Aadhaar encrypted, soft delete) |
| GET/POST/PATCH | `/api/employees/:id/academic[/:qualId]` | Auth | Academic qualifications |
| DELETE | `/api/employees/:id/academic/:qualId` | HR/ADMIN | Soft-delete qualification |
| GET | `/api/employees/:id/audit-log` | HR/ADMIN | Audit history |

### File uploads (all require JWT + ownership check)

| Method | Path | Saves to |
|---|---|---|
| POST | `/api/upload/photo` | `Employee.photoUrl` |
| POST | `/api/upload/signature` | `Employee.signatureUrl` |
| POST | `/api/upload/aadhaar-card` | `PersonalInfo.aadhaarCardUrl` |
| POST | `/api/upload/pan-card` | `PersonalInfo.panCardUrl` |
| POST | `/api/upload/marksheet` | `AcademicQualification.semNMarksheetUrl` |
| POST | `/api/upload/certificate` | `AcademicQualification.certificateUrl` |

All upload endpoints accept `multipart/form-data` with a `file` field + `employeeId` in the body. Employees can only upload to their own profile; HR/ADMIN/HOI can upload for anyone.

---

## Dynamic RBAC System

### How permissions work

- Every user has a **Role** (ADMIN, HR, HOD, FINANCE, HOI, EMPLOYEE — or custom)
- Every role has a **permission matrix**: per system module, 5 boolean flags: `canRead`, `canWrite`, `canApprove`, `canDelete`, `canExport`
- On login, the full permissions map is embedded in the JWT — no DB hit on each request
- When permissions change for a role, **all active sessions for that role are invalidated** (users must re-login)

### System modules

`PERSONAL_INFO` · `EDUCATION` · `LEAVE` · `PAYROLL` · `SALARY` · `ATTENDANCE` · `BANK_DETAILS` · `DOCUMENTS` · `REPORTS` · `USER_MGMT` · `ROLE_MGMT` · `FIELD_MGMT`

### Default role permissions summary

| Role | Key access |
|---|---|
| **ADMIN** | Full access to everything |
| **HOI** | Read + approve + export on all modules |
| **HR** | Read/write/approve on PERSONAL_INFO, EDUCATION, LEAVE, DOCUMENTS; read on PAYROLL, SALARY |
| **HOD** | Read on most; approve on LEAVE |
| **FINANCE** | Full on PAYROLL + SALARY; read BANK_DETAILS, REPORTS |
| **EMPLOYEE** | Read/write own PERSONAL_INFO, EDUCATION, LEAVE, DOCUMENTS; read ATTENDANCE, BANK_DETAILS |

### Creating a new user account

```
POST /api/admin/users
{ "employeeId": 29, "roleId": "<uuid-of-role>" }
```

- Default password = employee's DOB formatted as `DDMMYYYY` (e.g. `27051974`)
- If no DOB on file yet → default password is `01011990`
- `isFirstLogin = true` → user must change password on first login
- Email notification sent automatically if SMTP is configured

---

## Database Schema

### Core models

| Model | Table | Description |
|---|---|---|
| `Employee` | `employees` | Core identity row — auto-increment int ID |
| `EmployeeGeneralInfo` | `employee_general_info` | Name, dept, joining date, designation |
| `EmployeePersonalInfo` | `employee_personal_info` | DOB, gender, Aadhaar/PAN (AES-256 encrypted) |
| `EmployeeAddress` | `employee_addresses` | LOCAL + PERMANENT address |
| `EmployeeOtherInfo` | `employee_other_info` | Skills, hobbies, physical info |
| `FamilyMember` | `family_members` | Family members (Aadhaar encrypted, soft delete) |
| `AcademicQualification` | `academic_qualifications` | SSC→PHD qualifications |
| `AuditLog` | `audit_log` | Append-only change history |

### Auth & RBAC models

| Model | Table | Description |
|---|---|---|
| `User` | `users` | One account per employee; bcrypt password |
| `Role` | `roles` | Dynamic roles (admin can create custom roles) |
| `SystemModule` | `system_modules` | Seeded — maps to real code sections |
| `RolePermission` | `role_permissions` | Junction: Role × Module with 5 action flags |

---

## Folder Structure

```
HR-Management-System/
├── frontend/                        # Next.js 14 app
│   ├── app/
│   │   ├── (auth)/
│   │   │   ├── login/               # Login page + form
│   │   │   └── change-password/     # First-login password change
│   │   ├── (employee)/profile/      # Employee self-service portal
│   │   ├── admin/
│   │   │   ├── dashboard/           # Admin dashboard
│   │   │   ├── employees/           # Employee list + profile view
│   │   │   └── layout.tsx           # Admin shell with sidebar
│   │   └── api/auth/[...nextauth]/  # NextAuth handler
│   ├── components/
│   │   ├── layout/                  # Sidebar, Topbar, PageWrapper
│   │   ├── profile/                 # ProfileHeader, ProfileTabs, all tab components
│   │   └── shared/                  # FileUploadInput, MaskedInput, AuditLogDrawer, etc.
│   ├── lib/
│   │   ├── apollo-client.ts         # Apollo Client v4 setup
│   │   ├── axios.ts                 # Axios instance with JWT interceptor
│   │   ├── graphql/                 # GQL queries & mutations
│   │   ├── hooks/                   # useEmployee, usePersonalInfo, useAddress, etc.
│   │   └── validators/              # Zod schemas for all profile sections
│   ├── types/next-auth.d.ts         # NextAuth type extensions (role, employeeId, isFirstLogin)
│   └── prisma/                      # Prisma schema (frontend read queries)
│
├── backend/                         # Express 5 + TypeScript API
│   ├── prisma/
│   │   ├── schema.prisma            # Full DB schema — source of truth
│   │   ├── migrations/              # Version-controlled migrations
│   │   └── seed.ts                  # Roles, modules, permissions, admin user
│   └── src/
│       ├── index.ts                 # Entry point — Redis connect + app.listen
│       ├── app.ts                   # Express app — middleware + router mounts
│       ├── config/                  # env (Zod), prisma, redis, cloudinary
│       ├── middleware/
│       │   ├── auth.ts              # requireAuth — JWT verify + Redis session check
│       │   ├── rbac.ts              # requirePermission + requireRole
│       │   └── audit.ts             # startAuditContext + flushAudit
│       ├── utils/
│       │   ├── crypto.ts            # AES-256-CBC encrypt/decrypt/mask
│       │   ├── response.ts          # ok() / fail() response helpers
│       │   └── mailer.ts            # Nodemailer — account create + password reset emails
│       └── modules/
│           ├── auth/                # login, logout, change-password, reset-password, me
│           ├── user-management/     # user CRUD, role CRUD, permission matrix CRUD
│           └── personal-education/  # employee, general, personal, address, other,
│                                    # family, academic, upload, audit
│
├── hasura/                          # Hasura metadata & migrations
├── docker-compose.yml               # postgres, redis, hasura, backend (backend = dev only)
└── schema.prisma                    # Convenience copy of the DB schema
```

---

## Common Issues & Fixes

### Windows: `&&` not valid in PowerShell
Use `;` instead of `&&` when chaining commands, or run each command separately.

### Docker backend intercepting port 4000
If you start the Docker `backend` container AND run `npm run dev` locally, the Docker container wins. Always stop it first:
```powershell
docker compose stop backend
```

### `ENCRYPTION_KEY` Zod validation error
Must be exactly **64 hex characters** (32 bytes):
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### `P1000: Authentication failed` on Prisma migrate
Your `DATABASE_URL` must use port **`5433`** (not 5432):
```env
DATABASE_URL=postgres://hrms_user:hrms_pass@localhost:5433/hrms_db
```

### `Database drift detected` on Prisma migrate
The local migrations folder is out of sync with the DB. Reset cleanly:
```bash
npx prisma migrate reset --force
npx prisma migrate dev --name init_all
npx prisma db seed
```

### Frontend login always fails
1. Check that the Docker `backend` container is **stopped** (`docker compose stop backend`)
2. Check that the local backend is running (`npm run dev` in `backend/`)
3. Verify `NEXT_PUBLIC_API_URL=http://127.0.0.1:4000/api` in `frontend/.env` (use `127.0.0.1`, not `localhost`)
4. Restart the frontend dev server after any `.env` change

### Redis not connecting
Redis runs inside Docker (`redis` service). The backend connects to it via `REDIS_URL=redis://localhost:6380`. Make sure `docker compose up -d redis` is running. The auth middleware is **fail-open** on Redis downtime — logins will still work using JWT alone.

### Prisma: `tsx not found`
```bash
cd backend && npm install
```

### Prisma version
Both `frontend/` and `backend/` pin Prisma to **v6** (`"prisma": "^6"`). Do not upgrade to v7 without reviewing the migration guide — the `datasource.url` API changed.

### Windows: Hasura CLI execution policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Security Notes

- **Aadhaar and PAN numbers** are AES-256-CBC encrypted at rest. They are never stored in plaintext in the database and are never exposed via Hasura/GraphQL — only via the Express REST API after decryption.
- **Passwords** are bcrypt-hashed with 12 salt rounds. Plain-text passwords are never stored or logged.
- **JWT sessions** are validated against Redis on every request. Logout, password change, role change, and permission updates all immediately invalidate active sessions.
- **CORS** is restricted to `http://localhost:3000` and `http://localhost:9695` in development. Set `CORS_ALLOWED_ORIGINS` in production.
- **Upload ownership**: employees can only upload files to their own profile. HR/ADMIN/HOI can upload for anyone.
