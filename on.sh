#!/bin/bash

LOCK_FILE="on.lock"
STATE_FILE="on.state"
OTHER_STATE_FILE="off.state"

date +%s > "$LOCK_FILE"

echo "execution start"

# Simulate work
sleep 15

echo "execution end"

# Random success/fail
if [ $((RANDOM % 2)) -eq 0 ]; then
    echo "success"
    # Write on.state and delete off.state
    date +%s > "$STATE_FILE"
    rm -f "$OTHER_STATE_FILE"
    rm -f "$LOCK_FILE"
    exit 0
else
    echo "fail"
    rm -f "$LOCK_FILE"
    exit 1
fi
