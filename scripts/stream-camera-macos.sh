#!/usr/bin/env bash
set -u

DEVICE_INDEX="${1:-0}"
REMOTE_HOST="${2:-127.0.0.1}"
PORT="${3:-35827}"

echo "🎥 Starting FFmpeg camera stream: Device $DEVICE_INDEX -> $REMOTE_HOST:$PORT"

# Проверяем ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ Error: ffmpeg not found!"
    echo "💡 Install: brew install ffmpeg"
    exit 1
fi

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Connecting..."

    # Стримим через ffmpeg
    # -f avfoundation: захват с камеры macOS
    # -framerate 30: 30 fps
    # -video_size 640x480: разрешение
    # -i "$DEVICE_INDEX": индекс камеры
    # -c:v mjpeg: кодек MJPEG
    # -q:v 5: качество (2-31, меньше=лучше)
    # -f mpjpeg: формат Motion JPEG
    # tcp://: отправка по TCP
    ffmpeg \
        -f avfoundation \
        -framerate 30 \
        -video_size 640x480 \
        -i "$DEVICE_INDEX" \
        -c:v mjpeg \
        -q:v 5 \
        -f mpjpeg \
        "tcp://$REMOTE_HOST:$PORT" 2>&1 | \
        grep -E "error|Error|refused|Connection" || true

    echo "❌ Stream connection lost."
    echo "⏳ Retrying in 2 seconds..."
    sleep 2
done
