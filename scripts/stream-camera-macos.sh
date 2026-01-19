#!/usr/bin/env bash
set -u

# --- ФУНКЦИЯ ПРОВЕРКИ И УСТАНОВКИ ЗАВИСИМОСТЕЙ ---
check_and_install_deps() {
    echo "🔍 Checking dependencies..."

    # 1. Проверяем Homebrew (менеджер пакетов)
    if ! command -v brew &> /dev/null; then
        echo "🍺 Homebrew not found. Installing Homebrew..."
        echo "❗ You may be prompted for your password."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Добавляем brew в PATH для текущей сессии (для Apple Silicon и Intel)
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f "/usr/local/bin/brew" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        echo "✅ Homebrew is installed."
    fi

    # 2. Список пакетов GStreamer
    REQUIRED_PKGS=("gstreamer" "gst-plugins-base" "gst-plugins-good" "gst-plugins-bad" "gst-plugins-ugly")
    MISSING_PKGS=()

    # Быстрая проверка, что установлено
    INSTALLED_FORMULAE=$(brew list --formula)

    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! echo "$INSTALLED_FORMULAE" | grep -q "^${pkg}$"; then
            MISSING_PKGS+=("$pkg")
        fi
    done

    # Если чего-то не хватает, устанавливаем
    if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
        echo "📦 Installing missing packages: ${MISSING_PKGS[*]}..."
        brew install "${MISSING_PKGS[@]}"
    else
        echo "✅ All GStreamer packages are installed."
    fi
}

# Запускаем проверку перед стартом
check_and_install_deps

# --- ОСНОВНАЯ ЛОГИКА СТРИМА ---

# В macOS камеры выбираются по индексу (0, 1...)
DEVICE_INDEX="${1:-0}"
REMOTE_HOST="${2:-127.0.0.1}"
PORT="${3:-35827}"

echo "🎥 Starting camera stream: Index $DEVICE_INDEX -> $REMOTE_HOST:$PORT"

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Connecting..."

    # Используем avfvideosrc для macOS
    gst-launch-1.0 -v \
        avfvideosrc device-index="$DEVICE_INDEX" ! \
        videoconvert ! \
        jpegenc quality=85 ! \
        gdppay ! \
        tcpclientsink host="$REMOTE_HOST" port="$PORT" sync=false \
        2>&1 | while read line; do
            if echo "$line" | grep -q "Error\|refused\|Broken pipe"; then
                echo "⚠️  Stream error: $line"
                pkill -P $$ gst-launch-1.0 || true
                break
            fi
        done

    echo "❌ Stream connection lost."
    echo "⏳ Retrying in 2 seconds..."
    sleep 2
done
