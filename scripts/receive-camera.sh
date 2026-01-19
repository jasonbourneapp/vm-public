#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-35827}"
OUTPUT_DEVICE="${2:-/dev/video10}"

echo "📡 Starting camera receiver (FFmpeg): port $PORT -> $OUTPUT_DEVICE"

if [ ! -e "$OUTPUT_DEVICE" ]; then
    echo "❌ Error: Device $OUTPUT_DEVICE not found."
    exit 1
fi

echo "✅ Device $OUTPUT_DEVICE detected."

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting for FFmpeg stream on port $PORT..."

    # Принимаем MJPEG поток и декодируем в v4l2
    ffmpeg \
        -f mpjpeg \
        -i "tcp://0.0.0.0:$PORT?listen=1" \
        -f v4l2 \
        -pix_fmt yuv420p \
        "$OUTPUT_DEVICE" 2>&1 | \
        grep -E "error|Error" || true

    EXIT_CODE=$?
    echo "❌ Pipeline stopped with code: $EXIT_CODE"

    if [ $EXIT_CODE -gt 128 ]; then
        exit $EXIT_CODE
    fi

    echo "⏳ Restarting in 2 seconds..."
    sleep 2
done
