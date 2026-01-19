#!/usr/bin/env bash
# Убираем set -e, чтобы скрипт перезапускался при разрыве соединения
set -uo pipefail

# Устройство на хосте
DEVICE="${1:-/dev/video0}"
REMOTE_HOST="${2:-127.0.0.1}"
PORT="${3:-35827}"

echo "🎥 Starting camera stream: $DEVICE -> $REMOTE_HOST:$PORT"

if [ ! -e "$DEVICE" ]; then
    echo "❌ Error: Source device $DEVICE not found!"
    exit 1
fi

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Connecting to VM..."

    # === УПРОЩЕННЫЙ ПАЙПЛАЙН ===
    # 1. v4l2src: берем нативное изображение с камеры (обычно 640x480)
    # 2. videoconvert: на случай если камера отдает странный формат цвета
    # 3. jpegenc: кодируем в JPEG (quality=85 - баланс качества/скорости)
    # 4. gdppay: добавляем заголовки (receiver их ждет: gdpdepay)
    # 5. tcpclientsink: отправляем
    gst-launch-1.0 -v \
        v4l2src device="$DEVICE" ! \
        videoconvert ! \
        jpegenc quality=85 ! \
        gdppay ! \
        tcpclientsink host="$REMOTE_HOST" port="$PORT" sync=false \
        2>&1 | while read line; do
            # Фильтруем вывод, показываем только ошибки
            if echo "$line" | grep -q "Error\|refused\|Broken pipe"; then
                echo "⚠️  Stream error: $line"
                # Убиваем процесс для перезапуска
                pkill -P $$ gst-launch-1.0 || true
                break
            fi
        done

    echo "❌ Stream connection lost."
    echo "⏳ Retrying in 2 seconds..."
    sleep 2
done
