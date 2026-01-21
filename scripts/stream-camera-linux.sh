#!/usr/bin/env bash
set -u

INPUT_ARG="${1:-0}"
if [[ "$INPUT_ARG" =~ ^[0-9]+$ ]]; then
    DEVICE="/dev/video$INPUT_ARG"
else
    DEVICE="$INPUT_ARG"
fi

REMOTE_HOST="${2:-127.0.0.1}"
PORT="${3:-35827}"

echo "⚡ V4L2 ZERO-LATENCY: $DEVICE -> $REMOTE_HOST:$PORT"

if [ ! -e "$DEVICE" ]; then
    echo "❌ Error: Device $DEVICE not found."
    exit 1
fi

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Streaming..."

    # Читаем raw frames из v4l2 и отправляем через netcat
    ffmpeg \
        -f v4l2 \
        -input_format mjpeg \
        -framerate 30 \
        -video_size 640x480 \
        -i "$DEVICE" \
        -c:v copy \
        -f mjpeg \
        -fflags nobuffer+flush_packets \
        - | nc "$REMOTE_HOST" "$PORT" 2>&1 | \
        grep -E "error|Error|refused" || true

    echo "❌ Connection lost."
    sleep 2
done
