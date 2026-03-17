# HR Management System - Gandhinagar University (HRMS-GU)

## Project Overview
HRMS-GU is a comprehensive Human Resource Management System designed for Gandhinagar University. It provides tools for employee management, payroll processing, attendance tracking, and administrative workflows. The system is built with a modern, scalable tech stack to handle the university's diverse HR needs.

### Tech Stack
-   **Frontend:** Next.js (App Router, Tailwind CSS, NextAuth.js)
-   **Backend:** Node.js + Express
-   **Database:** PostgreSQL (Primary Data) + Redis (Session Management & Caching)
-   **GraphQL Layer:** Hasura GraphQL Engine
-   **Containerization:** Docker & Docker Compose

---

## Prerequisites
Ensure the following tools are installed on your system before setting up the project:
-   **Node.js (v20+):** [Download Node.js](https://nodejs.org/)
-   **Docker Desktop:** [Download Docker Desktop](https://www.docker.com/products/docker-desktop/)
-   **Git:** [Download Git](https://git-scm.com/)
-   **Hasura CLI:** [Install Hasura CLI](https://hasura.io/docs/latest/hasura-cli/install-hasura-cli/)

---

## Step-by-step Setup
Follow these steps to get the project running locally:

### 1. Clone the Repository
```bash
git clone https://github.com/Cipher-Shadow-IR/HR-Management-System.git
cd HR-Management-System
```

### 2. Configure Environment Variables
Copy the example environment file and update it with your local settings:
```bash
# In the root directory (if .env.example exists)
cp .env.example .env

# Don't forget to configure frontend environment variables
cd frontend
cp .env.example .env # Create if it doesn't exist
cd ..
```

### 3. Start Infrastructure Services
Use Docker Compose to launch PostgreSQL, Redis, and Hasura:
```bash
docker compose up -d
```

### 4. Setup Backend
Install dependencies and prepare the backend service:
```bash
cd backend
npm install
# The backend will be available via Docker or you can run it locally with 'npm run dev'
cd ..
```

### 5. Setup Frontend
Install dependencies and start the development server:
```bash
cd frontend
npm install
npm run dev
```

### 6. Apply Hasura Migrations & Metadata
Initialize the Hasura project to synchronize the database schema:
```bash
cd hasura
hasura console
```
*Wait for the console to open, this will ensure the metadata and migrations are applied.*

---

## Folder Structure
-   `frontend/`: The Next.js web application.
-   `backend/`: Express.js API server handling business logic and integrations.
-   `hasura/`: Hasura configuration, metadata, and database migrations.
-   `docker-compose.yml`: Orchestration for local development services.

---

## Available URLs
Once the services are running, you can access them at:
-   **Frontend:** [http://localhost:3000](http://localhost:3000)
-   **Backend API:** [http://localhost:4000](http://localhost:4000)
-   **Hasura Console:** [http://localhost:9695](http://localhost:9695) (opened via Hasura CLI)
-   **Hasura GraphQL Engine:** [http://localhost:8080](http://localhost:8080)

---

## Common Issues & Fixes

### Windows: `hasura-cli` execution policy
If you encounter permission issues running Hasura CLI on Windows, run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Docker: Port conflicts
If services fail to start due to port conflicts (e.g., port 5432 or 6379 already in use), ensure no local PostgreSQL or Redis instances are running on your host machine.

### Docker: Engine not running
Ensure Docker Desktop is open and the Docker Engine is fully initialized before running `docker compose up`.
