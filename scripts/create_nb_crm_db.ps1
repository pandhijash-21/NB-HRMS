# Create nb_crm_db (if missing) and apply Prisma migrations.
# Does NOT drop, alter, or read from hrms_db.
# Reuses any Postgres already bound to localhost:5434 (e.g. college HRMS stack).
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$DbName = "nb_crm_db"
$DbUser = "hrms_user"
if ($env:DATABASE_URL) {
  $DatabaseUrl = $env:DATABASE_URL
} else {
  $DatabaseUrl = "postgres://hrms_user:hrms_pass@localhost:5434/$DbName"
}

function Get-PostgresContainer {
  $name = (docker ps --filter "publish=5434" --format "{{.Names}}" | Select-Object -First 1)
  if ($name) { return $name.Trim() }
  return $null
}

Set-Location $RootDir

$PgContainer = Get-PostgresContainer
if (-not $PgContainer) {
  Write-Host "==> No Postgres on port 5434; starting this project's postgres service..."
  docker compose up -d postgres
  if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

  Write-Host "==> Waiting for Postgres to accept connections..."
  $ready = $false
  for ($i = 1; $i -le 30; $i++) {
    $PgContainer = Get-PostgresContainer
    if ($PgContainer) {
      docker exec $PgContainer pg_isready -U $DbUser 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) {
        $ready = $true
        break
      }
    }
    Start-Sleep -Seconds 1
  }
  if (-not $ready) { throw "Postgres did not become ready in time." }
} else {
  Write-Host "==> Reusing existing Postgres container on port 5434: $PgContainer"
  docker exec $PgContainer pg_isready -U $DbUser 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Postgres on 5434 is not ready." }
}

Write-Host "==> Creating database '$DbName' if it does not exist (hrms_db left untouched)..."
$existsRaw = docker exec $PgContainer psql -U $DbUser -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname = '$DbName'"
$exists = if ($null -eq $existsRaw) { "" } else { "$existsRaw".Trim() }
if ($exists -eq "1") {
  Write-Host "    Database '$DbName' already exists - skipping CREATE."
} else {
  docker exec $PgContainer psql -U $DbUser -d postgres -c "CREATE DATABASE $DbName OWNER $DbUser;"
  if ($LASTEXITCODE -ne 0) { throw "CREATE DATABASE failed" }
  Write-Host "    Created database '$DbName'."
}

Write-Host "==> Applying Prisma migrations to '$DbName' only..."
Set-Location (Join-Path $RootDir "backend")
$env:DATABASE_URL = $DatabaseUrl
npx prisma migrate deploy
if ($LASTEXITCODE -ne 0) { throw "prisma migrate deploy failed" }

Write-Host "==> Done. DATABASE_URL for this project should be:"
Write-Host "    $DatabaseUrl"
Write-Host "==> College DB hrms_db was not modified."
