# HR Management System — Gandhinagar University (HRMS-GU)

## Project Overview

HRMS-GU is a comprehensive Human Resource Management System for Gandhinagar University. It covers employee profile management, sensitive data handling with encryption, document uploads, family & academic records, audit logging, and role-based access for Admin/HR and Employee roles.

### Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Next.js 16 (App Router), TypeScript, Tailwind CSS v4, Shadcn/ui |
| Auth | NextAuth.js v4 (Credentials provider, JWT sessions) |
| GraphQL Client | Apollo Client v4 → Hasura |
| REST Client | Axios → Express backend |
| Backend | Node.js + Express, TypeScript, Prisma v6 |
| Database | PostgreSQL 15 |
| GraphQL Engine | Hasura GraphQL Engine |
| Cache / Sessions | Redis |
| File Storage | Cloudinary (via Multer) |
| Encryption | AES-256 (Node.js `crypto`) for Aadhaar & PAN at rest |
| Audit | Custom `AuditLog` table; logged on every sensitive write |
| Containerization | Docker & Docker Compose |

---

## Prerequisites

- **Node.js v20+** — [nodejs.org](https://nodejs.org/)
- **Docker Desktop** — [docker.com](https://www.docker.com/products/docker-desktop/)
- **Git** — [git-scm.com](https://git-scm.com/)
- **Hasura CLI** — [hasura.io/docs/latest/hasura-cli/install-hasura-cli](https://hasura.io/docs/latest/hasura-cli/install-hasura-cli/)

---

## Step-by-step Setup

### 1. Clone the repository

```bash
git clone https://github.com/Cipher-Shadow-IR/HR-Management-System.git
cd HR-Management-System
```

### 2. Configure environment variables

**Backend:**
```bash
cd backend
cp .env.example .env
# Edit backend/.env with your values (JWT_SECRET, ENCRYPTION_KEY, Cloudinary, etc.)
cd ..
```

**Frontend** — create `frontend/.env`:
```env
DATABASE_URL=postgres://hrms_user:hrms_pass@localhost:5433/hrms_db
NEXT_PUBLIC_HASURA_URL=http://localhost:8080/v1/graphql
NEXT_PUBLIC_API_URL=http://localhost:4000/api
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=change_me_to_a_random_secret
```

### 3. Start infrastructure (Docker)

```bash
docker compose up -d
```

This starts: **PostgreSQL** (port `5433`), **Redis**, **Hasura** (port `8080`), and the **Express backend** (port `4000`).

> **Note for Windows users:** If port 5432 conflicts with a local PostgreSQL install, the compose file already maps Postgres to host port **5433**.

### 4. Run Prisma migrations

```bash
cd frontend
npx prisma migrate dev --name init
cd ..
```

### 5. Apply Hasura metadata

```bash
cd hasura
hasura metadata apply
cd ..
```

Or open the Hasura console to verify:
```bash
cd hasura
hasura console   # opens at http://localhost:9695
```

### 6. Install frontend dependencies & start dev server

```bash
cd frontend
npm install
npm run dev      # http://localhost:3000
```

### 7. (Optional) Run backend locally instead of Docker

```bash
docker compose stop backend   # free port 4000
cd backend
npm install
npm run dev      # http://localhost:4000
```

---

## Accessing the Application

Once everything is running, open **[http://localhost:3000](http://localhost:3000)**.

### URLs at a Glance

| Service | URL |
|---|---|
| **Landing page** | http://localhost:3000 |
| **Login** | http://localhost:3000/login |
| **Employee Portal** | http://localhost:3000/profile |
| **Admin Dashboard** | http://localhost:3000/admin/dashboard |
| **Employee List (Admin)** | http://localhost:3000/admin/employees |
| **Employee Profile (Admin)** | http://localhost:3000/admin/employees/`<id>` |
| **Backend API** | http://localhost:4000/api |
| **Backend Health** | http://localhost:4000/api/health |
| **Hasura GraphQL** | http://localhost:8080/v1/graphql |
| **Hasura Console** | http://localhost:8080 (or `hasura console` → 9695) |

### Login Credentials (Development)

The dev login fallback accepts **any email/password**. Role is assigned based on the email address:

| Role | Email pattern | Example | Redirect |
|---|---|---|---|
| **Admin / HR** | email contains `admin` or `hr` | `admin@example.com` | `/admin/dashboard` |
| **Employee** | any other email | `john.doe@university.ac.in` | `/profile` |

> Once the backend `/api/auth/login` endpoint is wired with real credentials, the dev fallback is automatically bypassed.

---

## Module 1 — Personal & Education (Implemented)

### Backend REST endpoints (`/api/personal-education`)

| Method | Path | Description |
|---|---|---|
| POST | `/employee` | Create employee record |
| GET | `/employees/:id` | Get employee by ID |
| PUT | `/employees/:id` | Update general info |
| GET/PUT | `/employees/:id/personal` | Sensitive personal info (encrypted Aadhaar/PAN) |
| GET/PUT | `/employees/:id/address` | Local & permanent addresses |
| GET/POST/PUT/DELETE | `/employees/:id/family` | Family members (soft-delete, encrypted Aadhaar) |
| GET/POST/PUT/DELETE | `/employees/:id/academic` | Academic qualifications |
| POST | `/employees/:id/upload/:type` | File uploads → Cloudinary |
| GET | `/employees/:id/audit` | Audit log (HR/Admin only) |

### Frontend pages

| Page | Path | Access |
|---|---|---|
| Landing | `/` | Public |
| Login | `/login` | Public |
| My Profile | `/profile` | Employee |
| Admin Dashboard | `/admin/dashboard` | Admin / HR |
| Employee List | `/admin/employees` | Admin / HR |
| Employee Profile | `/admin/employees/:id` | Admin / HR |

### Profile tabs (per employee)

`General` · `Personal` · `Address` · `Other (Bank/IDs)` · `Family` · `Education` · `Documents`

---

## Folder Structure

```
HR-Management-System/
├── frontend/               # Next.js 16 app
│   ├── app/                # App Router pages & layouts
│   │   ├── (auth)/login/   # Login page
│   │   ├── (employee)/     # Employee portal (/profile)
│   │   ├── admin/          # Admin portal (/admin/*)
│   │   └── api/auth/       # NextAuth route
│   ├── components/
│   │   ├── layout/         # Sidebar, Topbar, PageWrapper
│   │   ├── profile/        # ProfileHeader, ProfileTabs, tab components
│   │   └── shared/         # FileUploadInput, MaskedInput, AuditLogDrawer, etc.
│   ├── lib/
│   │   ├── apollo-client.ts
│   │   ├── axios.ts
│   │   ├── graphql/        # GQL queries & mutations
│   │   ├── hooks/          # useEmployee, usePersonalInfo, useAddress, etc.
│   │   └── validators/     # Zod schemas
│   └── prisma/             # Prisma schema & migrations
├── backend/                # Express + TypeScript API
│   ├── src/
│   │   ├── config/         # env, prisma, redis, cloudinary
│   │   ├── middleware/     # auth (JWT), rbac, audit
│   │   ├── utils/          # crypto (AES-256), response helpers
│   │   └── modules/
│   │       └── personal-education/  # All Module 1 routes/controllers/services
│   └── prisma/             # Prisma schema
├── hasura/                 # Hasura metadata & migrations
├── docker-compose.yml
└── schema.prisma           # Source-of-truth DB schema
```

---

## Common Issues & Fixes

### Windows: `hasura-cli` execution policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Docker: Port 5432 already in use
The compose file maps Postgres to host port **5433** to avoid conflict with local PostgreSQL installs. Your `DATABASE_URL` should use `localhost:5433`.

### Docker: Port 6379 (Redis) already in use
Redis is only exposed internally inside Docker. No host port is mapped, so this should not conflict.

### Prisma version
Both `frontend` and `backend` pin `prisma` and `@prisma/client` to **v6** (`^6`). Do not upgrade to v7 without reviewing the migration guide.

### Backend: `ENCRYPTION_KEY` error
The `ENCRYPTION_KEY` in `backend/.env` must be exactly **64 hex characters** (32 bytes). Generate one with:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### `npm run dev` on backend: `tsx not found`
```bash
cd backend && npm install
```
`tsx` is listed as a dev dependency and must be installed locally.
