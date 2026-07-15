# Execution Guide for HRMS Application

This guide provides step-by-step instructions to set up and run the HRMS application (Backend + Frontend) seamlessly.

## Prerequisites

- **Node.js**: Version 18 or higher (Recommended: 20+)
- **Docker & Docker Compose**: For running PostgreSQL, Redis, and Hasura
- **Git**: For version control

---

## 🐳 Docker Setup (Recommended)

The easiest way to start the infrastructure (DB, Redis, Hasura) is using Docker Compose.

1.  **Run the containers**:
    ```bash
    docker-compose up -d
    ```
    This will start:
    - **PostgreSQL**: `localhost:5434` (User: `hrms_user`, Pass: `hrms_pass`)
      - `nb_crm_db` — **this** NB Developer project (required)
      - `hrms_db` — college HRMS only; do **not** point this app at it
    - **Redis**: `localhost:6380`
    - **Hasura GraphQL Engine**: `http://localhost:8080`

    Create/migrate the NB database (never touches `hrms_db`):

    ```powershell
    .\scripts\create_nb_crm_db.ps1
    ```

    ```bash
    bash scripts/create_nb_crm_db.sh
    ```

---

## 🚀 Hasura Setup

Hasura acts as the GraphQL API layer for the database.

1.  **Console URL**: [http://localhost:8080/console](http://localhost:8080/console)
2.  **Admin Secret**: `myadminsecret` (defined in `docker-compose.yml`)
3.  **Applying Metadata/Migrations**:
    If you have the Hasura CLI installed:
    ```bash
    cd hasura
    hasura metadata apply
    hasura migrate apply --database-name default
    hasura metadata reload
    ```
    *Note: If icons or fields are missing in the frontend, ensure all tables in the `public` schema are **Tracked** in the Hasura Console.*

---

## 🚀 Backend Setup

1.  **Navigate to the backend directory**:
    ```bash
    cd backend
    ```

2.  **Install dependencies**:
    ```bash
    npm install
    ```

3.  **Configure environment variables**:
    - Create a `.env` file (copy from `.env.example`).
    - Ensure `DATABASE_URL` is `postgres://hrms_user:hrms_pass@localhost:5434/nb_crm_db` (never `hrms_db`).
    - Optional: keep the college URL in `backend/.env.hrms` for the old project only.
    - Ensure `REDIS_URL` or relevant Redis settings are correct.

4.  **Initialize Database (Prisma)** — prefer the setup script first:
    ```powershell
    # from repo root
    .\scripts\create_nb_crm_db.ps1
    ```
    Then:
    ```bash
    # Generate Prisma Client
    npx prisma generate

    # Seed the database (Important for initial admin user and roles)
    npx prisma db seed
    ```

5.  **Run Development Server**:
    ```bash
    npm run dev
    ```
    The backend should now be running on `http://localhost:4000`.
    API base: `http://localhost:4000/api`

---

## 🎨 Frontend Setup

1.  **Navigate to the frontend directory**:
    ```bash
    cd ../frontend
    ```

2.  **Install dependencies**:
    ```bash
    npm install
    ```

3.  **Configure Environment Variables**:
    - Ensure `.env` contains the correct `NEXT_PUBLIC_API_URL` pointing to your backend.

4.  **Run Development Server**:
    ```bash
    npm run dev
    ```
    The frontend will be available at `http://localhost:3000`.

---

## 🛠️ Common Fixes & Troubleshooting

### 1. `rootDir` Conflicts
If you encounter errors about `seed.ts` not being under `src`, ensure `backend/tsconfig.json` does **not** include `prisma/seed.ts` in its `include` array. (Fixed in current version).

### 2. Missing `process` Types
If the IDE shows errors for `process`, ensure `@types/node` is installed in the respective directory:
```bash
cd backend
npm install --save-dev @types/node
```

### 3. Database Connection Issues
Ensure PostgreSQL is running and the credentials in `.env` are correct. If using Docker, ensure the container name is resolvable.

### 4. Prisma Out of Sync
If you change the schema, always run:
```bash
npx prisma generate
```

---

## 🔑 Initial Login
After seeding, use the following to log in:
- **Employee ID**: `1` or `2` or `3`
- **Password**: `01011998`
- *Note: You will be prompted to change your password on first login for both admin and employee.*


## New Login Info

- **Employee ID**: `1`
- **Password**: `admin1234`

- **Employee ID**: `2`
- **Password**: `user1234`

- **Employee ID**: `3`
- **Password**: `employee3333`
