#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-35827}"
OUTPUT_DEVICE="${2:-/dev/video10}"

echo "⚡ V4L2 ZERO-LATENCY RECEIVER: port $PORT -> $OUTPUT_DEVICE"

if [ ! -e "$OUTPUT_DEVICE" ]; then
    echo "❌ Error: Device $OUTPUT_DEVICE not found."
    echo "💡 Create v4l2loopback device:"
    echo "   sudo modprobe v4l2loopback devices=1 video_nr=10 card_label='VirtualCam' exclusive_caps=1"
    exit 1
fi

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting for stream..."

    # OpenBSD netcat использует другой синтаксис
    # Используем ncat (nmap) или socat если доступны, иначе стандартный netcat
    if command -v ncat &> /dev/null; then
        ncat -l "$PORT" | ffmpeg \
            -fflags nobuffer \
            -flags low_delay \
            -f mjpeg \
            -i pipe:0 \
            -c:v copy \
            -f v4l2 \
            "$OUTPUT_DEVICE" 2>&1 | \
            grep -E "error|Error" || true
    elif command -v socat &> /dev/null; then
        socat TCP-LISTEN:"$PORT",reuseaddr,fork - | ffmpeg \
            -fflags nobuffer \
            -flags low_delay \
            -f mjpeg \
            -i pipe:0 \
            -c:v copy \
            -f v4l2 \
            "$OUTPUT_DEVICE" 2>&1 | \
            grep -E "error|Error" || true
    else
        # GNU netcat
        nc -l "$PORT" | ffmpeg \
            -fflags nobuffer \
            -flags low_delay \
            -f mjpeg \
            -i pipe:0 \
            -c:v copy \
            -f v4l2 \
            "$OUTPUT_DEVICE" 2>&1 | \
            grep -E "error|Error" || true
    fi

    echo "❌ Stream stopped."
    sleep 2
done
