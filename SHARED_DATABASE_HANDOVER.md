# Database & Server Integration Handover Guide

> **Confidential Document**: This guide contains database credentials, server configuration instructions, and operational constraints for integrating the new application on the shared server and PostgreSQL database.

---

## 1. Server Credentials (Fill in Manually)

Please enter the server access credentials below before sending this file to the other developer:

| Parameter | Details | Notes |
| :--- | :--- | :--- |
| **Server IP / Host** | `[ENTER_SERVER_IP_HERE]` | e.g., `192.168.x.x` or public VPS IP / domain |
| **SSH Port** | `[ENTER_SSH_PORT_HERE]` | Usually `22` |
| **SSH Username** | `[ENTER_SSH_USER_HERE]` | e.g., `root` or `ubuntu` |
| **SSH Password / Key**| `[ENTER_SSH_PASSWORD_OR_KEY_PATH]` | Paste password or provide `.pem` key |
| **Deployment Directory**| `[ENTER_APP_PATH]` | Suggested: `/var/www/new-app` or `/home/<user>/new-app` |

---

## 2. Database Connection Details

Both applications share the **same PostgreSQL database instance**.

### A. Local Development Environment
If developing and testing locally:
* **Host:** `localhost` (or `127.0.0.1`)
* **Port:** `5434` *(Mapped from Docker 5432)*
* **Database Name:** `nb_crm_db`
* **Username:** `hrms_user`
* **Password:** `hrms_pass`
* **Connection URL:**
  ```text
  postgresql://hrms_user:hrms_pass@localhost:5434/nb_crm_db
  ```

### B. Production / VPS Server Environment
When deployed on the live server:
* **Host:**
  * If running inside the **Docker network**: `postgres` (Port: `5432`)
  * If running directly as a **Host OS process / systemd**: `127.0.0.1` or `localhost` (Port: `5432` / `5434`)
* **Database Name:** `nb_crm_db`
* **Username:** `[ENTER_PRODUCTION_DB_USER]` *(Default: `hrms_user`)*
* **Password:** `[ENTER_PRODUCTION_DB_PASSWORD]` *(Default: `hrms_pass` or production secret)*
* **Connection URL:**
  ```text
  postgresql://[DB_USER]:[DB_PASSWORD]@[DB_HOST]:[DB_PORT]/nb_crm_db
  ```

---

## 3. Other Shared Services (Optional)

If your app needs caching, background queues, or file storage:

* **Redis:**
  * Local URL: `redis://localhost:6380`
  * Docker internal: `redis://redis:6379`
* **Object Storage (MinIO / S3 compatible):**
  * Local Endpoint: `http://127.0.0.1:9000`
  * Access Key: `minioadmin`
  * Secret Key: `minioadmin_password`
  * Bucket: `crm-files`

---

## 4. Server Port Allocation & Reverse Proxy Rules

The host server already runs the NB-CRM/HRMS stack. To avoid service disruptions, adhere strictly to the port restrictions:

### ⚠️ Occupied Ports (DO NOT USE)
| Port | Service |
| :--- | :--- |
| **80 / 443** | Traefik / Nginx Reverse Proxy |
| **3000** | NB-CRM Web App |
| **4000** | NB-HRMS Backend API |
| **5432 / 5434** | PostgreSQL Database |
| **6379 / 6380** | Redis Cache |
| **7880** | LiveKit Video Server |
| **8080** | Hasura GraphQL Engine |
| **9000** | MinIO Object Storage |

### ✅ Recommended Ports for the New App
* **New App Backend:** Port `5000` or `5001` or `8000`
* **New App Frontend:** Port `3001` or `5173`
* **Domain Routing:** The server uses Traefik/Nginx reverse proxy. Configure your app to receive traffic via a subdomain (e.g., `https://newapp.yourdomain.com`) forwarding to your internal app port.

---

## 5. Strict Database Rules & Safety Constraints

Because both applications write to the same database, you **MUST** follow these rules:

### 🚫 Rule 1: NEVER Run Destructive Database Commands
Do **NOT** execute commands that drop, recreate, or reset tables/schemas.
* ❌ Forbidden: `prisma migrate reset`
* ❌ Forbidden: `sequelize db:drop`
* ❌ Forbidden: `typeorm schema:drop`
* ❌ Forbidden: `DROP DATABASE ...` or `DROP SCHEMA public CASCADE`
* ✅ Allowed: Safe forward migrations (`CREATE TABLE`, `ADD COLUMN` with defaults, non-destructive alterations).

### 🏷️ Rule 2: Table Naming Conventions
Do **NOT** create tables with generic names that conflict with existing core tables.
* **Collision-prone names:** `users`, `employees`, `roles`, `permissions`, `departments`, `attendance`, `leaves`, `clients`, `leads`, `tasks`, `notifications`, `audit_logs`.
* **Required Practice:** Prefix all tables specific to the new application (e.g., `app2_orders`, `app2_inventory`, `app2_payments`), OR create them within a dedicated PostgreSQL schema (e.g., `CREATE SCHEMA app2;`).

### 🔗 Rule 3: Referencing Existing Data (Foreign Keys)
If the new app needs to associate data with existing employees or users:
* Refer to the existing `Employee` or `User` primary keys (`id` / `employee_id`).
* Set foreign key constraints to `ON DELETE RESTRICT` or `ON DELETE SET NULL` to avoid cascading deletes affecting shared data.

### 🏊 Rule 4: Connection Pooling Limits
PostgreSQL has a maximum connection limit.
* Do not configure unlimited connection pools.
* Cap your ORM/pool size to a maximum of **10–15 connections** (e.g., Prisma `connection_limit=10` or `pool: { max: 10 }`).

---

## 6. Detailed Synchronization Procedure

### How the New App Adds New Tables
1. Design your tables using your ORM (Prisma, TypeORM, Drizzle, Sequelize, Django, etc.).
2. Apply the migration cleanly:
   ```bash
   # Example with Prisma
   npx prisma db push --skip-generate
   # Or create forward SQL migration scripts
   ```
3. Verify that your new tables are created without modifying any of the existing tables.

### How the HRMS Backend Synchronizes with Your New Tables
Whenever you create new tables in `nb_crm_db`, the HRMS backend will pull them into its Prisma schema:
1. HRMS team runs introspection:
   ```bash
   npx prisma db pull
   ```
   *(This automatically reads your new tables and generates matching Prisma models in `prisma/schema.prisma`)*
2. HRMS team re-generates client:
   ```bash
   npx prisma generate
   ```
3. The HRMS team can now query your tables directly in TypeScript:
   ```typescript
   const data = await prisma.app2_orders.findMany();
   ```

---

## 7. Emergency Contacts & Communication
* **HRMS / CRM Tech Lead:** [ENTER_NAME / CONTACT]
* **Database Administrator:** [ENTER_NAME / CONTACT]
* Always notify the team before running major schema changes or restarts.
