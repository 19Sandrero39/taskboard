#!/bin/sh

# ============================================================
# TaskBoard deployment script
# ============================================================

# Stop the script when an unexpected command fails.
set -e

# ============================================================
# Configuration
# ============================================================

APP_NAME="taskboard"
APP_DIR="$(pwd)"
REPOSITORY_URL="https://github.com/sharton/taskboard"

DB_NAME="taskboard"
DB_USER="taskboard"
DB_PASSWORD="taskboard"

APP_HOST="0.0.0.0"
APP_PORT="8080"

VENV_DIR=".venv"
PID_FILE="$APP_DIR/uvicorn.pid"
LOG_FILE="$APP_DIR/uvicorn.log"

echo "========================================"
echo " TaskBoard deployment"
echo "========================================"

# ============================================================
# 1. Check and install system dependencies
# ============================================================

echo ""
echo "[1/8] Checking system dependencies..."

PACKAGES=""

if ! command -v git >/dev/null 2>&1; then
    PACKAGES="$PACKAGES git"
fi

if ! command -v python3 >/dev/null 2>&1; then
    PACKAGES="$PACKAGES python3"
fi

if ! command -v psql >/dev/null 2>&1; then
    PACKAGES="$PACKAGES postgresql"
fi

if ! command -v curl >/dev/null 2>&1; then
    PACKAGES="$PACKAGES curl"
fi

# python3-venv is required to create a virtual environment.
if ! python3 -m venv --help >/dev/null 2>&1; then
    PACKAGES="$PACKAGES python3-venv"
fi

if [ -n "$PACKAGES" ]; then
    echo "Installing missing packages:$PACKAGES"

    sudo apt-get update
    sudo apt-get install -y $PACKAGES
else
    echo "All required system programs are already installed."
fi