#!/bin/bash

# stop.sh - Stop the Spring Boot file upload validation application
# Usage: ./stop.sh

set -u

PID_FILE=".app.pid"

echo "Stopping application..."

# Method 1: Try to read PID from file
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    echo "Found PID file: $PID"

    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Sending SIGTERM to PID $PID..."
        kill "$PID"

        # Wait for graceful shutdown
        WAIT_COUNT=0
        while ps -p "$PID" > /dev/null 2>&1 && [ $WAIT_COUNT -lt 5 ]; do
            sleep 1
            WAIT_COUNT=$((WAIT_COUNT + 1))
            echo -n "Waiting for shutdown... ${WAIT_COUNT}s"
            echo -ne "\r"
        done

        # Force kill if still running
        if ps -p "$PID" > /dev/null 2>&1; then
            echo ""
            echo "Process still running, sending SIGKILL..."
            kill -9 "$PID"
            sleep 1
        fi

        if ps -p "$PID" > /dev/null 2>&1; then
            echo ""
            echo "Error: Failed to stop process $PID"
            exit 1
        else
            echo ""
            echo "Application stopped (PID: $PID)"
            rm -f "$PID_FILE"
            exit 0
        fi
    else
        echo "Process $PID is not running"
        rm -f "$PID_FILE"
    fi
fi

# Method 2: Fallback - Find process by name
echo "Searching for application by process name..."

# Find Maven process
MAVEN_PIDS=$(pgrep -f "mvn spring-boot:run" || true)

# Find Java process with our application
JAVA_PIDS=$(pgrep -f "file-upload-validation" || true)

# Combine PIDs
ALL_PIDS="$MAVEN_PIDS $JAVA_PIDS"

if [ -z "$ALL_PIDS" ] || [ "$ALL_PIDS" = " " ]; then
    echo "No application processes found"
    rm -f "$PID_FILE"
    exit 0
fi

# Kill all found processes
for PID in $ALL_PIDS; do
    if [ -n "$PID" ] && ps -p "$PID" > /dev/null 2>&1; then
        echo "Stopping process: $PID"
        kill "$PID" 2>/dev/null || true
        sleep 1

        # Force kill if needed
        if ps -p "$PID" > /dev/null 2>&1; then
            kill -9 "$PID" 2>/dev/null || true
        fi
    fi
done

# Clean up PID file
rm -f "$PID_FILE"

echo "Application stopped"
