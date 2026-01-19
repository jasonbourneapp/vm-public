#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-35827}"
OUTPUT_DEVICE="${2:-/dev/video10}"

echo "📡 Starting camera receiver service: port $PORT -> $OUTPUT_DEVICE"

# Проверка наличия устройства. Устройство должно создаваться через boot.extraModprobeConfig в NixOS.
# Мы не пытаемся создавать его здесь, следуя принципу Single Responsibility.
if [ ! -e "$OUTPUT_DEVICE" ]; then
    echo "❌ Error: Device $OUTPUT_DEVICE not found."
    echo "   Ensure 'v4l2loopback' is in boot.kernelModules and configured correctly in system.nix."
    exit 1
fi

echo "✅ Device $OUTPUT_DEVICE detected."

# Бесконечный цикл внутри скрипта нужен для быстрого перезапуска пайплайна
# без триггера StartLimitBurst в systemd (если соединения часто рвутся).
while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting for TCP stream on port $PORT..."

    # Запускаем GStreamer
    # tcpserversrc: ждет входящее подключение
    # gdpdepay: распаковывает GDP заголовки (если используются на передающей стороне)
    # jpegdec: декодирует MJPEG поток
    # videoconvert: приводит формат пикселей к нужному для v4l2sink
    gst-launch-1.0 -v \
        tcpserversrc host=0.0.0.0 port="$PORT" ! \
        gdpdepay ! \
        jpegdec ! \
        videoconvert ! \
        v4l2sink device="$OUTPUT_DEVICE" sync=false \
        2>&1 | while read line; do
            # Логируем только важное, чтобы не спамить в journald
            if echo "$line" | grep -q "Setting pipeline to PAUSED\|Setting pipeline to PLAYING\|Error\|Warning"; then
                echo "$line"
            fi

            # Ловим критические ошибки потока для быстрого перезапуска
            if echo "$line" | grep -q "Internal data stream error\|Could not write\|Connection refused"; then
                echo "⚠️  Critical error detected in pipeline."
                # pkill убьет gst-launch, цикл bash перезапустит его
                pkill -P $$ gst-launch-1.0 || true
            fi
        done

    EXIT_CODE=$?
    echo "❌ Pipeline stopped with code: $EXIT_CODE"

    # Если это был системный сбой или остановка сервиса - выходим, systemd перезапустит скрипт целиком
    if [ $EXIT_CODE -gt 128 ]; then
        exit $EXIT_CODE
    fi

    echo "⏳ Restarting pipeline in 2 seconds..."
    sleep 2
done
