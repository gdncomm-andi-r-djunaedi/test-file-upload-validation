#!/bin/bash

# start.sh - Start the Spring Boot file upload validation application
# Usage: ./start.sh

set -e
set -u

PID_FILE=".app.pid"
PORT=8080
MAX_WAIT=30

echo "Starting Spring Boot application..."

# Check if application is already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Application is already running with PID: $OLD_PID"
        echo "Endpoint: http://localhost:$PORT/upload"
        exit 0
    else
        echo "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Check if port is already in use
if command -v lsof > /dev/null 2>&1; then
    if lsof -Pi :$PORT -sTCP:LISTEN -t > /dev/null 2>&1; then
        echo "Error: Port $PORT is already in use"
        echo "Run: lsof -ti:$PORT | xargs kill -9"
        exit 1
    fi
fi

# Check if Maven is installed
if ! command -v mvn > /dev/null 2>&1; then
    echo "Error: Maven is not installed"
    exit 1
fi

# Start the application in background
echo "Launching application with Maven..."
mvn spring-boot:run > /dev/null 2>&1 &
APP_PID=$!

# Save PID to file
echo "$APP_PID" > "$PID_FILE"
echo "PID saved to $PID_FILE: $APP_PID"

# Wait for application to start
echo "Waiting for application to start on port $PORT..."
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
    if command -v nc > /dev/null 2>&1; then
        if nc -z localhost $PORT 2>/dev/null; then
            break
        fi
    elif command -v curl > /dev/null 2>&1; then
        if curl -s http://localhost:$PORT > /dev/null 2>&1; then
            break
        fi
    fi

    # Check if process is still running
    if ! ps -p "$APP_PID" > /dev/null 2>&1; then
        echo "Error: Application process died"
        rm -f "$PID_FILE"
        exit 1
    fi

    sleep 1
    COUNTER=$((COUNTER + 1))
    echo -n "Waiting... ${COUNTER}s"
    echo -ne "\r"
done

if [ $COUNTER -eq $MAX_WAIT ]; then
    echo ""
    echo "Error: Application failed to start within ${MAX_WAIT}s"
    kill "$APP_PID" 2>/dev/null || true
    rm -f "$PID_FILE"
    exit 1
fi

echo ""
echo "Application started successfully!"
echo "  PID: $APP_PID"
echo "  Port: $PORT"
echo "  Endpoint: http://localhost:$PORT/upload"
echo ""
echo "Use ./stop.sh to stop the application"
