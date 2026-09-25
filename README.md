# NB CRM

**HRMS · CRM · ERP** — one product, three suites.

The day-to-day client is the Flutter app in `nb_crm_flutter` (web, Android, iOS, desktop). Next.js in `frontend` is the companion site. Express in `backend` is the API.

[![Flutter](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Node](https://img.shields.io/badge/Node.js-20.x-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-5-000000?logo=express&logoColor=white)](https://expressjs.com)
[![Prisma](https://img.shields.io/badge/Prisma-6-2D3748?logo=prisma&logoColor=white)](https://www.prisma.io)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Redis](https://img.shields.io/badge/Redis-7%2F8-DC382D?logo=redis&logoColor=white)](https://redis.io)

> This fork uses its own database, **`nb_crm_db`**. The college database **`hrms_db`** stays untouched. Same Postgres server, separate data.

---

## Contents

1. [At a glance](#at-a-glance)
2. [What you need](#what-you-need)
3. [First-time setup](#first-time-setup)
4. [Every day](#every-day)
5. [Sign in](#sign-in)
6. [What the app covers](#what-the-app-covers)
7. [API](#api)
8. [Access control](#access-control)
9. [Data model](#data-model)
10. [Repository map](#repository-map)
11. [When something fails](#when-something-fails)
12. [Security](#security)

---

## At a glance

| | |
|---|---|
| Repository | [pandhijash-21/NB-HRMS](https://github.com/pandhijash-21/NB-HRMS) |
| Primary client | Flutter — `flutter run -d chrome` |
| API | `http://127.0.0.1:4000/api` |
| Health | `http://127.0.0.1:4000/health` |
| Database | `postgres://hrms_user:hrms_pass@localhost:5434/nb_crm_db` |
| Sessions | `redis://localhost:6380` |
| Seed login | Employee **`1`** · password **`01011998`** |
| App version | `1.0.1` (`pubspec.yaml` `1.0.1+2`, `kAppVersion` in `lib/core/app_version.dart`) |

| Service | Address |
|---|---|
| Flutter app | The port `flutter run` prints, for example `http://localhost:61905` |
| Next.js site | http://localhost:3000 |
| API | http://127.0.0.1:4000 |
| Postgres | `localhost:5434` · database `nb_crm_db` |
| Redis | `localhost:6380` |
| Hasura | http://localhost:8080 (optional) |

| Layer | Technology |
|---|---|
| App | Flutter in `nb_crm_flutter` |
| Site | Next.js 14, TypeScript, Tailwind |
| API | Node.js, Express 5, TypeScript, Prisma 6 |
| Database | PostgreSQL 15 · `nb_crm_db` |
| Sessions | Redis, one live login per account |
| Auth | JWT checked against Redis on every request |
| Files | Cloudinary (optional) |
| Calls | LiveKit (optional) |

---

## What you need

| Tool | Version | Used for |
|---|---|---|
| Git | current | Clone and updates |
| Node.js | 20.x (24 runs, with an engines warning) | API and Next.js |
| Flutter | SDK 3.9+ | The NB CRM app |
| PostgreSQL | 15 | Database on port **5434** |
| Redis | 7 or 8 | Sessions on port **6380** |
| Docker Desktop | optional | Postgres, Redis, and Hasura in one command |
| Chrome | current | Flutter web. Android Studio or Xcode only for a device build |

---

## First-time setup

### 1. Clone

```bash
git clone https://github.com/pandhijash-21/NB-HRMS.git
cd NB-HRMS
```

### 2. Postgres and Redis

**Docker** (when virtualization is on):

```bash
docker compose up -d postgres redis hasura
```

Compose creates a bootstrap database named `hrms_db` on first volume init. Create the database this app actually uses:

```powershell
.\scripts\create_nb_crm_db.ps1
```

```bash
bash scripts/create_nb_crm_db.sh
```

Leave the Docker `backend` service stopped while you develop. Run the API on your machine so it reloads on save.

**Windows without Docker** (WSL or virtualization off):

Install PostgreSQL 15 and Redis yourself and match this login:

| | |
|---|---|
| Host | `127.0.0.1` |
| Postgres port | `5434` |
| User | `hrms_user` |
| Password | `hrms_pass` |
| Database | `nb_crm_db` |
| Redis | `127.0.0.1:6380` |

Create `nb_crm_db`, then continue with the backend steps.

### 3. API environment

```bash
cd backend
npm install
cp .env.example .env
```

On Windows: `Copy-Item .env.example .env`

`backend/.env` needs at least:

```env
DATABASE_URL=postgres://hrms_user:hrms_pass@localhost:5434/nb_crm_db
REDIS_URL=redis://localhost:6380
JWT_SECRET=<at least 32 random characters>
ENCRYPTION_KEY=<exactly 64 hex characters>
TRANSPORT_SECRET=nb-crm-double-enc-v2-local
PORT=4000
FRONTEND_URL=http://localhost:3000
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:9695
```

Generate the encryption key:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

`JWT_SECRET` is any long random string. Cloudinary, SMTP, LiveKit, MinIO, and OpenAI are optional. The API starts without them. Uploads, email OTP, and Meet calls need those keys when you use those features.

If the browser blocks the Flutter web app, add the origin `flutter run` printed (for example `http://localhost:61905`) to `CORS_ALLOWED_ORIGINS` and restart the API.

### 4. Schema and seed

```bash
npx prisma generate
npx prisma migrate deploy
npx prisma db seed
```

The seed prints the admin login: employee id **`1`**, password **`01011998`**.

On a brand-new `nb_crm_db`, `migrate deploy` can stop because an early migration expects `organizations` or `attendance_policy` before those tables exist. Sync the Prisma schema and seed:

```bash
npx prisma db push --accept-data-loss --skip-generate
npx prisma db seed
```

Run that only against a new local `nb_crm_db`.

### 5. Start the API

```bash
npm run dev
```

Wait for Redis connected and the server on port 4000. Open http://127.0.0.1:4000/health.

### 6. Flutter app

```bash
cd ../nb_crm_flutter
flutter pub get
flutter run -d chrome
```

The app calls `http://localhost:4000/api` (`AppConfig.localApiBaseUrl`). After login, allow location. Live tracking and attendance use GPS.

Other targets:

```bash
flutter devices
flutter run -d <device-id>
```

Ship a build by bumping both numbers together:

| File | Field | Current |
|---|---|---|
| `nb_crm_flutter/pubspec.yaml` | `version` | `1.0.1+2` |
| `nb_crm_flutter/lib/core/app_version.dart` | `kAppVersion` | `1.0.1` |

### 7. Next.js site (optional)

```bash
cd frontend
npm install
```

Create `frontend/.env`:

```env
DATABASE_URL=postgres://hrms_user:hrms_pass@localhost:5434/nb_crm_db
NEXT_PUBLIC_HASURA_URL=http://localhost:8080/v1/graphql
NEXT_PUBLIC_API_URL=http://127.0.0.1:4000/api
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=<any random string>
```

On Windows, `NEXT_PUBLIC_API_URL` uses `127.0.0.1` so the browser stays on the same address family. Restart the site after any `.env` change.

```bash
npm run dev
```

Open http://localhost:3000.

---

## Every day

1. Postgres is on **5434** and Redis is on **6380**. With Docker: `docker compose up -d postgres redis`.
2. API: `cd backend` then `npm run dev`.
3. App: `cd nb_crm_flutter` then `flutter run -d chrome` (or your device).
4. Start `frontend` only when you are working on the Next.js site.

After a Dart or API change, hot restart Flutter. Restart `npm run dev` if the API process did not reload.

---

## Sign in

Both login screens take an **employee id or username** and a password.

| Field | Value |
|---|---|
| Employee ID | `1` |
| Password | `01011998` |
| Role | Admin (seed) |

First login asks for a new password, then email verification, then at least one family member marked as an emergency contact.

A new employee's default password is their date of birth as `DDMMYYYY` (example `27051974`). With no date of birth on file, the fallback is `01011990`. The seeded admin account uses `01011998`.

An **open trip** (`trips.end_time` is empty) locks the account:

- Another device cannot sign in while that employee still has a live session.
- That employee cannot sign out until the trip ends (they return to a work location, or they punch out).
- If the Redis session is already gone, the same person can sign in again and finish the trip.

---

## What the app covers

| Suite | Screens |
|---|---|
| HRMS | Home, profile, attendance, leave, salary, reimbursements, recruitment, org tree |
| CRM | Pre-sales, post-sales, dashboard |
| ERP | Projects, work orders, BOQ, store, purchase, tenders, DPR |
| Field | Live location and trips after punch-in, when the person leaves a work geofence |
| Platform | Superadmin console at `/platform` — tenants, licensing, app version |

**App version policy** lives on Platform Health. A superadmin sets a minimum version, a latest version, and three update links (web, Android, iOS). Clients read them from `GET /api/auth/branding`.

- Current version below the minimum: a blocking update screen.
- Current version below the latest, and at or above the minimum: a dismissible update prompt each time the app comes to the foreground.
- An empty link hides the Update button on that platform.

**Trip tracking.** Punch in, or be inside a work geofence, then leave it. One GPS fix at least 30 metres past the nearest fence opens the trip. A fix that is only just outside needs two readings. Punch-out, or two readings back inside a fence, closes the trip. Whether the person was last inside or outside is kept for 12 hours so a short GPS gap does not skip opening the trip. The trip row itself stays open until they return or punch out. The live map pin expires after 120 seconds.

---

## API

Base URL: `http://127.0.0.1:4000`

### Auth

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/auth/login` | Public | `{ employeeId, password }` → JWT |
| POST | `/api/auth/logout` | JWT | Drop the Redis session. Refused while an open trip exists |
| POST | `/api/auth/change-password` | JWT | Change own password, then sign in again |
| GET | `/api/auth/me` | JWT | Profile, permissions, and `onTrip` |
| GET | `/api/auth/branding` | Public | Logo, colours, and the app version policy |
| POST | `/api/auth/reset-password/:userId` | JWT + `USER_MGMT:WRITE` | Reset a password to the date-of-birth default |

### Users

| Method | Path | Permission |
|---|---|---|
| GET | `/api/admin/users` | `USER_MGMT:READ` |
| GET | `/api/admin/users/:id` | `USER_MGMT:READ` |
| POST | `/api/admin/users` | `USER_MGMT:WRITE` |
| PATCH | `/api/admin/users/:id` | `USER_MGMT:WRITE` |
| DELETE | `/api/admin/users/:id` | `USER_MGMT:DELETE` |

### Roles and permissions

| Method | Path | Permission |
|---|---|---|
| GET, POST | `/api/admin/roles` | `ROLE_MGMT:READ` / `WRITE` |
| GET, PATCH, DELETE | `/api/admin/roles/:id` | `ROLE_MGMT:READ` / `WRITE` / `DELETE` |
| GET | `/api/admin/modules` | `ROLE_MGMT:READ` |
| GET, PUT | `/api/admin/roles/:roleId/permissions` | `ROLE_MGMT:READ` / `WRITE` |
| PATCH | `/api/admin/roles/:roleId/permissions/:moduleKey` | `ROLE_MGMT:WRITE` |

### Employees

All routes need a JWT. Write guards are HR, ADMIN, or HOI where noted.

| Method | Path | Who | What |
|---|---|---|---|
| POST | `/api/employees` | HR / ADMIN | Create an employee |
| GET | `/api/employees/:id` | Signed in | Full profile |
| PATCH | `/api/employees/:id` | Signed in | Core fields |
| GET, POST, PATCH | `/api/employees/:id/general` | Write: HR / ADMIN / HOI | Name, department, joining date |
| GET, POST, PATCH | `/api/employees/:id/personal` | Signed in, audited | Date of birth, gender. Aadhaar and PAN are encrypted |
| GET, POST, PATCH | `/api/employees/:id/address/:type` | Signed in, audited | `LOCAL` or `PERMANENT` |
| GET, POST, PATCH | `/api/employees/:id/other` | Signed in, audited | Skills, hobbies, physical info |
| GET, POST, PATCH, DELETE | `/api/employees/:id/family[/:memberId]` | Signed in, audited | Family members. Aadhaar encrypted. Delete is soft |
| GET, POST, PATCH | `/api/employees/:id/academic[/:qualId]` | Signed in | Qualifications |
| DELETE | `/api/employees/:id/academic/:qualId` | HR / ADMIN | Soft-delete a qualification |
| GET | `/api/employees/:id/audit-log` | HR / ADMIN | Change history |

### Uploads

JWT plus an ownership check. `multipart/form-data` with a `file` field and `employeeId`. An employee uploads only to their own profile. HR, ADMIN, and HOI can upload for anyone.

| Method | Path | Saved on |
|---|---|---|
| POST | `/api/upload/photo` | `Employee.photoUrl` |
| POST | `/api/upload/signature` | `Employee.signatureUrl` |
| POST | `/api/upload/aadhaar-card` | `PersonalInfo.aadhaarCardUrl` |
| POST | `/api/upload/pan-card` | `PersonalInfo.panCardUrl` |
| POST | `/api/upload/marksheet` | `AcademicQualification.semNMarksheetUrl` |
| POST | `/api/upload/certificate` | `AcademicQualification.certificateUrl` |

### Platform

Superadmin. Version policy is also returned on the public branding route.

| Method | Path | What |
|---|---|---|
| GET, PUT | `/api/platform/app-version` | Minimum version, latest version, update links for web, Android, and iOS |

---

## Access control

Each user has one role. Each role has a matrix: for every module, five flags — `canRead`, `canWrite`, `canApprove`, `canDelete`, `canExport`.

The matrix is embedded in the JWT at login. Changing a role's permissions drops every live session for that role. Those people sign in again.

**Modules:** `PERSONAL_INFO` · `EDUCATION` · `LEAVE` · `PAYROLL` · `SALARY` · `ATTENDANCE` · `BANK_DETAILS` · `DOCUMENTS` · `REPORTS` · `USER_MGMT` · `ROLE_MGMT` · `FIELD_MGMT`

| Role | Access |
|---|---|
| ADMIN | Full access |
| HOI | Read, approve, and export on every module |
| HR | Read, write, and approve on personal info, education, leave, and documents. Read on payroll and salary |
| HOD | Read on most modules. Approve on leave |
| FINANCE | Full payroll and salary. Read bank details and reports |
| EMPLOYEE | Read and write own personal info, education, leave, and documents. Read attendance and bank details |

Create an account:

```http
POST /api/admin/users
{ "employeeId": 29, "roleId": "<role-uuid>" }
```

Default password is the employee's date of birth as `DDMMYYYY`. With no date of birth, it is `01011990`. `isFirstLogin` is true, so the first session must set a new password. If SMTP is configured, the account email goes out automatically.

---

## Data model

Source of truth: `backend/prisma/schema.prisma`.

### People

| Model | Table | Holds |
|---|---|---|
| `Employee` | `employees` | Identity. Auto-increment integer id |
| `EmployeeGeneralInfo` | `employee_general_info` | Name, department, joining date, designation |
| `EmployeePersonalInfo` | `employee_personal_info` | Date of birth, gender. Aadhaar and PAN encrypted with AES-256 |
| `EmployeeAddress` | `employee_addresses` | Local and permanent address |
| `EmployeeOtherInfo` | `employee_other_info` | Skills, hobbies, physical info |
| `FamilyMember` | `family_members` | Family. Aadhaar encrypted. Soft delete |
| `AcademicQualification` | `academic_qualifications` | SSC through PhD |
| `AuditLog` | `audit_log` | Append-only history |

### Accounts

| Model | Table | Holds |
|---|---|---|
| `User` | `users` | One account per employee. bcrypt password |
| `Role` | `roles` | Built-in and custom roles |
| `SystemModule` | `system_modules` | Seeded module keys |
| `RolePermission` | `role_permissions` | Role × module × five action flags |

---

## Repository map

```
NB-HRMS/
├── nb_crm_flutter/                  # Flutter app — web, Android, iOS, desktop
│   └── lib/
│       ├── core/                    # router, theme, tracking, API client, version
│       └── features/                # auth, home, profile, attendance, CRM, ERP, platform
├── frontend/                        # Next.js 14 site
│   ├── app/
│   │   ├── (auth)/login/            # Login
│   │   ├── (auth)/change-password/  # First-login password change
│   │   ├── (employee)/profile/      # Employee self-service
│   │   ├── admin/                   # Dashboard, employees, admin shell
│   │   └── api/auth/[...nextauth]/  # NextAuth
│   ├── components/                  # layout, profile, shared inputs
│   ├── lib/                         # Apollo, Axios, GraphQL, hooks, Zod
│   └── prisma/                      # Frontend read schema
├── backend/                         # Express 5 API
│   ├── prisma/
│   │   ├── schema.prisma            # Database source of truth
│   │   ├── migrations/
│   │   └── seed.ts                  # Roles, modules, admin user (password 01011998)
│   └── src/
│       ├── index.ts                 # Redis, then listen
│       ├── app.ts                   # Middleware and routes
│       ├── config/                  # env, Prisma, Redis, Cloudinary
│       ├── middleware/              # JWT session, RBAC, audit
│       ├── utils/                   # AES-256, responses, mail
│       └── modules/                 # auth, users, employees, tracking, platform
├── scripts/                         # create_nb_crm_db.ps1 and .sh
├── hasura/                          # Hasura metadata
└── docker-compose.yml               # postgres :5434, redis :6380, hasura, backend
```

---

## When something fails

| Symptom | Fix |
|---|---|
| PowerShell rejects `&&` | Use `;` or run each command on its own line |
| Port 4000 is taken by Docker | `docker compose stop backend`, then `npm run dev` in `backend/` |
| `ENCRYPTION_KEY` rejected | Exactly 64 hex characters. Generate with the `node -e` command in step 3 |
| Prisma `P1000` authentication failed | `DATABASE_URL` must be port **5434** and database **`nb_crm_db`** |
| `migrate deploy` stops on a fresh database | `npx prisma db push --accept-data-loss --skip-generate`, then `npx prisma db seed`. Local `nb_crm_db` only |
| Drift between migrations and the database | `npx prisma migrate reset --force`, then `npx prisma migrate dev --name init_all`, then `npx prisma db seed` |
| Next.js login always fails | Docker backend is stopped. Local API is running. `NEXT_PUBLIC_API_URL=http://127.0.0.1:4000/api`. Restart Next after `.env` edits |
| Flutter web cannot reach the API | Add the printed Flutter origin to `CORS_ALLOWED_ORIGINS` and restart the API |
| Redis will not connect | `docker compose up -d redis`, or a local Redis on **6380**. `REDIS_URL=redis://localhost:6380`. Auth is fail-open if Redis is down: JWT still works, session lock does not |
| `tsx` not found | `cd backend` and `npm install` |
| Prisma major upgrade | Both apps pin Prisma **6**. Stay on 6 unless you follow the v7 migration guide. `datasource.url` changed in v7 |
| Hasura CLI blocked on Windows | `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |

---

## Security

| Control | How it is applied |
|---|---|
| Aadhaar and PAN | AES-256-CBC at rest. Returned only by the Express API after decryption. Hasura does not expose them |
| Passwords | bcrypt, 12 rounds. Plain text is never stored or logged |
| Sessions | JWT checked against Redis on each request. Logout, password change, and permission edits drop the session at once |
| One login | A new sign-in replaces `session:<userId>` unless that account is on an open trip with a live session |
| CORS | Development allows the origins in `CORS_ALLOWED_ORIGINS`. Set that list for production |
| Uploads | An employee can write files only on their own profile. HR, ADMIN, and HOI can write for anyone |
