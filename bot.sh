#!/bin/bash

# Ensure Telegram token is provided
if [ -z "$TELEGRAM_TOKEN" ]; then
  echo "TELEGRAM_TOKEN environment variable is not set."
  exit 1
fi

API_URL="https://api.telegram.org/bot$TELEGRAM_TOKEN"
OFFSET_FILE="bot.offset"
OFFSET=0

# Initialize OFFSET from file if it exists
if [ -f "$OFFSET_FILE" ]; then
  OFFSET=$(cat "$OFFSET_FILE")
fi

# Helper to send messages
send_message() {
  local chat_id="$1"
  local text="$2"
  curl -s -X POST "$API_URL/sendMessage" -d "chat_id=$chat_id" -d "text=$text" > /dev/null
}

# Helper to get human readable time from lock file
get_time() {
  local lock_file="$1"
  if [ -f "$lock_file" ]; then
    local timestamp
    timestamp=$(cat "$lock_file")
    # Using 'date' which is available in Amazon Linux 2 (GNU date)
    date -d "@$timestamp" "+%H:%M:%S"
  fi
}

echo "Bot started..."

while true; do
  # Get updates with long polling
  RESPONSE=$(curl -s "$API_URL/getUpdates?offset=$OFFSET&timeout=30")
  echo "$RESPONSE" | jq -c '.result[]' | while read -r UPDATE_BLOCK; do
    UPDATE_ID=$(echo "$UPDATE_BLOCK" | jq -r '.update_id')
    OFFSET=$((UPDATE_ID + 1))
    CHAT_ID=$(echo "$UPDATE_BLOCK" | jq -r '.message.chat.id')
    TEXT=$(echo "$UPDATE_BLOCK" | jq -r '.message.text // ""')
    case "$TEXT" in
      /on)
        if [ -f "on.lock" ]; then
          LOCK_TIME=$(get_time "on.lock")
          send_message "$CHAT_ID" "Command /on is already running, since $LOCK_TIME UTC."
        elif [ -f "off.lock" ]; then
          LOCK_TIME=$(get_time "off.lock")
          send_message "$CHAT_ID" "Can't turn on until off is complete. It's running since $LOCK_TIME UTC."
        elif [ -f "on.state" ]; then
          STATE_TIME=$(get_time "on.state")
          send_message "$CHAT_ID" "It's already on, since $STATE_TIME UTC."
        else
          send_message "$CHAT_ID" "Triggering /on script..."
          (
            ./on.sh
            if [ $? -eq 0 ]; then
              send_message "$CHAT_ID" "/on script completed successfully."
            else
              send_message "$CHAT_ID" "/on script failed."
            fi
          ) &
        fi
        ;;
      /off)
        if [ -f "off.lock" ]; then
          LOCK_TIME=$(get_time "off.lock")
          send_message "$CHAT_ID" "Command /off is already running, since $LOCK_TIME UTC."
        elif [ -f "on.lock" ]; then
          LOCK_TIME=$(get_time "on.lock")
          send_message "$CHAT_ID" "Can't turn off until on is complete. It's running since $LOCK_TIME UTC."
        elif [ -f "off.state" ]; then
          STATE_TIME=$(get_time "off.state")
          send_message "$CHAT_ID" "It's already off, since $STATE_TIME UTC."
        else
          send_message "$CHAT_ID" "Triggering /off script..."
          (
            ./off.sh
            if [ $? -eq 0 ]; then
              send_message "$CHAT_ID" "/off script completed successfully."
            else
              send_message "$CHAT_ID" "/off script failed."
            fi
          ) &
        fi
        ;;
      *)
        send_message "$CHAT_ID" "Unknown command. Use /on or /off."
        ;;
    esac
    echo "$OFFSET" > "$OFFSET_FILE"
  done
  sleep 1
done
