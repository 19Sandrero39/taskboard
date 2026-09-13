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

# ============================================================
# 5. Start PostgreSQL
# ============================================================

echo ""
echo "[5/8] Checking PostgreSQL..."

if ! sudo systemctl is-active --quiet postgresql; then
    echo "PostgreSQL is not running. Starting PostgreSQL..."
    sudo systemctl start postgresql
else
    echo "PostgreSQL is already running."
fi

# Check that PostgreSQL accepts connections.
if ! sudo -u postgres pg_isready >/dev/null 2>&1; then
    echo "ERROR: PostgreSQL is not ready."
    exit 1
fi

echo "PostgreSQL is ready."

# ============================================================
# 6. Create database and user
# ============================================================

echo ""
echo "[6/8] Configuring PostgreSQL database..."

# Check whether the PostgreSQL user exists.
if sudo -u postgres psql -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then

    echo "PostgreSQL user '$DB_USER' already exists."
else
    echo "Creating PostgreSQL user '$DB_USER'..."

    sudo -u postgres psql -v ON_ERROR_STOP=1 -c \
        "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
fi

# Check whether the database exists.
if sudo -u postgres psql -tAc \
    "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then

    echo "Database '$DB_NAME' already exists."
else
    echo "Creating database '$DB_NAME'..."

    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
fi

echo "PostgreSQL configuration completed."

# ============================================================
# 7. Start FastAPI / Uvicorn
# ============================================================

echo ""
echo "[7/8] Starting FastAPI application..."

# Stop the previous TaskBoard process if its PID file exists.
if [ -f "$PID_FILE" ]; then
    OLD_PID="$(cat "$PID_FILE")"

    if kill -0 "$OLD_PID" >/dev/null 2>&1; then
        echo "Stopping previous TaskBoard process (PID: $OLD_PID)..."
        kill "$OLD_PID"
        sleep 1
    fi

    rm -f "$PID_FILE"
fi

echo "Starting Uvicorn..."

nohup "$APP_DIR/$VENV_DIR/bin/uvicorn" \
    app.main:app \
    --host "$APP_HOST" \
    --port "$APP_PORT" \
    > "$LOG_FILE" 2>&1 &

UVICORN_PID=$!

echo "$UVICORN_PID" > "$PID_FILE"

echo "Uvicorn started."
echo "PID: $UVICORN_PID"
echo "Log: $LOG_FILE"

# ============================================================
# 8. Health check
# ============================================================

echo ""
echo "[8/8] Checking application health..."

HEALTH_URL="http://localhost:$APP_PORT/api/health"

echo "Waiting for application to start..."
sleep 3

if curl -s -f "$HEALTH_URL" > /dev/null; then
    echo ""
    echo "========================================"
    echo " TaskBoard deployed successfully!"
    echo "========================================"
    echo ""
    echo "Application: http://localhost:$APP_PORT/"
    echo "API docs:    http://localhost:$APP_PORT/docs"
    echo "Health:      $HEALTH_URL"
    echo ""
    echo "Uvicorn PID: $UVICORN_PID"
    echo "Log file:    $LOG_FILE"
else
    echo ""
    echo "========================================"
    echo " ERROR: TaskBoard failed to start!"
    echo "========================================"
    echo ""
    echo "Uvicorn log:"
    echo "----------------------------------------"

    cat "$LOG_FILE"

    echo "----------------------------------------"
    exit 1
fi
