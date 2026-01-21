#!/usr/bin/env bash
set -u

DEVICE_INDEX="${1:-0}"
REMOTE_HOST="${2:-127.0.0.1}"
PORT="${3:-35827}"

# Функция проверки и установки зависимостей
check_and_install_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        echo "❌ FFmpeg not found."

        # Проверяем наличие Homebrew
        if ! command -v brew &> /dev/null; then
            echo "🍺 Homebrew not found. Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Добавляем brew в PATH для текущей сессии (для Apple Silicon и Intel)
            if [[ -f /opt/homebrew/bin/brew ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -f /usr/local/bin/brew ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        fi

        echo "⬇️ Installing FFmpeg via Homebrew..."
        brew install ffmpeg

        # Проверяем успешность установки
        if ! command -v ffmpeg &> /dev/null; then
            echo "❌ Fatal Error: FFmpeg installation failed."
            echo "Please install manually: brew install ffmpeg"
            exit 1
        fi
        echo "✅ FFmpeg installed successfully!"
    fi
}

# Запуск проверки перед стартом стрима
check_and_install_ffmpeg

echo "🎥 Starting low-latency FFmpeg stream: Device $DEVICE_INDEX -> $REMOTE_HOST:$PORT"

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Connecting..."

    ffmpeg \
        -f avfoundation \
        -framerate 30 \
        -video_size 640x480 \
        -i "$DEVICE_INDEX" \
        -c:v mjpeg \
        -q:v 8 \
        -preset ultrafast \
        -tune zerolatency \
        -fflags nobuffer \
        -flags low_delay \
        -strict experimental \
        -f mpjpeg \
        -flush_packets 1 \
        "tcp://$REMOTE_HOST:$PORT" 2>&1 | \
        grep -E "error|Error|refused|Connection" || true

    echo "❌ Stream connection lost."
    echo "⏳ Retrying in 2 seconds..."
    sleep 2
done
