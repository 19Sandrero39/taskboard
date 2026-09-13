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

# ============================================================
# 2. Check project directory
# ============================================================

echo ""
echo "[2/8] Checking project directory..."

if [ ! -f "requirements.txt" ]; then
    echo "requirements.txt was not found."

    if [ -d "$APP_NAME" ]; then
        echo "Found existing $APP_NAME directory."
        cd "$APP_NAME"
        APP_DIR="$(pwd)"
    else
        echo "Cloning TaskBoard repository..."
        git clone "$REPOSITORY_URL" "$APP_NAME"
        cd "$APP_NAME"
        APP_DIR="$(pwd)"
    fi
else
    echo "TaskBoard project already exists."
fi

if [ ! -f "requirements.txt" ]; then
    echo "ERROR: requirements.txt is still missing."
    exit 1
fi

echo "Project directory: $APP_DIR"

# ============================================================
# 3. Create Python virtual environment
# ============================================================

echo ""
echo "[3/8] Checking Python virtual environment..."

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
else
    echo "Virtual environment already exists."
fi

# ============================================================
# 4. Install Python dependencies
# ============================================================

echo ""
echo "[4/8] Installing Python dependencies..."

"$APP_DIR/$VENV_DIR/bin/python" -m pip install --upgrade pip
"$APP_DIR/$VENV_DIR/bin/python" -m pip install uv
"$APP_DIR/$VENV_DIR/bin/python" -m uv pip install -r requirements.txt

echo "Python dependencies installed."

