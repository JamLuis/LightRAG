@echo off
REM LightRAG Quick Restart Script - Windows Batch Version
REM Fast restart without rebuilding image

setlocal enabledelayedexpansion

echo.
echo ======================================================
echo  LightRAG Quick Restart Script
echo ======================================================
echo.

REM Check Docker
echo Checking Docker...
docker --version >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not installed or not running
    exit /b 1
)
echo Docker found successfully

REM Stop existing containers
echo.
echo Stopping existing containers...
for /f "tokens=*" %%i in ('docker ps -q --filter "name=lightrag" 2^>nul') do (
    docker stop %%i >nul 2>&1
)
timeout /t 2 /nobreak >nul
echo Containers stopped

REM Clean old containers
echo Cleaning old containers...
for /f "tokens=*" %%i in ('docker ps -a -q --filter "name=lightrag" 2^>nul') do (
    docker rm %%i >nul 2>&1
)
echo Cleanup complete

REM Start containers
echo.
echo Starting Docker containers...
docker compose up -d --remove-orphans
if errorlevel 1 (
    echo Error: Failed to start containers
    exit /b 1
)

REM Wait for service
echo Waiting for service to be ready...
timeout /t 3 /nobreak >nul

REM Check health
set port=9621
for /f "tokens=*" %%i in ('findstr /R "^PORT=" .env 2^>nul') do (
    for /f "tokens=2 delims==" %%p in ("%%i") do set port=%%p
)

echo.
echo ======================================================
echo  Service Information
echo ======================================================
echo.
echo API URL: http://localhost:!port!
echo WebUI URL: http://localhost:!port!/docs
echo.
docker ps --filter "name=lightrag" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo.
echo To view logs, run: docker compose logs -f lightrag
echo.
echo ======================================================
echo  Restart Complete!
echo ======================================================
echo.
