#!/usr/bin/env bash

# === НАСТРОЙКИ ===
DISK_FILE="local_working_disk.qcow2"
DEFAULT_CORES=4
DEFAULT_MEM_MB=4096

echo "🚀 Подготовка к запуску High-Performance VM..."

# 1. Проверка прав sudo
CAN_SUDO=true
if ! command -v sudo &> /dev/null || ! sudo -v 2>/dev/null; then
    echo "⚠️  Нет прав sudo. Изоляция хоста будет пропущена."
    CAN_SUDO=false
fi

# ==========================================
# 🧠 РАСЧЕТ РЕСУРСОВ
# ==========================================

if command -v nproc &> /dev/null; then
    TOTAL_CORES=$(nproc)
else
    TOTAL_CORES=$DEFAULT_CORES
fi

# Оставляем хосту минимум 1 ядро (если ядер >=8, то 2)
if [ "$TOTAL_CORES" -ge 8 ]; then
    RESERVED_FOR_HOST=2
else
    RESERVED_FOR_HOST=1
fi

VM_CORES=$((TOTAL_CORES - RESERVED_FOR_HOST))

# Лимиты ядер
if [ "$VM_CORES" -lt 4 ] && [ "$TOTAL_CORES" -gt 4 ]; then VM_CORES=4; fi
if [ "$VM_CORES" -ge "$TOTAL_CORES" ]; then VM_CORES=$((TOTAL_CORES - 1)); fi

# Лимиты RAM
if [ -f /proc/meminfo ] && command -v awk &> /dev/null; then
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
else
    TOTAL_MEM_MB=$((DEFAULT_MEM_MB + 3000))
fi

VM_MEM_MB=$((TOTAL_MEM_MB - 2560)) # Запас хосту 2.5GB
if [ "$VM_MEM_MB" -gt 8192 ]; then VM_MEM_MB=8192; fi
if [ "$VM_MEM_MB" -lt 4096 ]; then VM_MEM_MB=4096; fi

# ==========================================
# 🎯 ГЕНЕРАЦИЯ МАСОК (Для изоляции хоста)
# ==========================================
HOST_CPUS_MASK=""
ALL_CPUS_MASK="0-$((TOTAL_CORES - 1))"

# чтобы знать, куда "отселить" системные процессы.
if command -v seq &> /dev/null; then
    # VM: Верхние ядра (информационно)
    START_CORE=$((TOTAL_CORES - VM_CORES))
    END_CORE=$((TOTAL_CORES - 1))

    # HOST: Нижние ядра (для systemd изоляции)
    HOST_END_CORE=$((START_CORE - 1))
    if [ "$HOST_END_CORE" -lt 0 ]; then HOST_END_CORE=0; fi
    HOST_CPUS_MASK="0-$HOST_END_CORE"
fi

echo "📊 Конфигурация:"
echo "   ➡️ Host CPU (System Only): Ядра $HOST_CPUS_MASK"
echo "   ➡️ VM CPU (Планируемые):   Ядра $START_CORE-$END_CORE"
echo "   ➡️ VM RAM:                 $VM_MEM_MB MB"
echo "---------------------------------------------------"

# ==========================================
# 🛑 ФУНКЦИЯ ОЧИСТКИ
# ==========================================
cleanup() {
    echo ""
    echo "🛑 Завершение работы..."

    if [ "$CAN_SUDO" = true ]; then
        echo "🔙 Восстановление настроек CPU..."

        # Восстанавливаем system и init scope
        if [ -n "$ALL_CPUS_MASK" ]; then
             sudo systemctl set-property --runtime -- system.slice AllowedCPUs=$ALL_CPUS_MASK 2>/dev/null
             sudo systemctl set-property --runtime -- init.scope AllowedCPUs=$ALL_CPUS_MASK 2>/dev/null
        fi

        # Восстанавливаем Governor
        if [ -w "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]; then
             echo "powersave" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true
        fi

        if command -v powerprofilesctl &> /dev/null; then
            powerprofilesctl set balanced 2>/dev/null || true
        fi
    fi
    echo "✅ Система восстановлена."
}
trap cleanup EXIT

# ==========================================
# 🛠️ ИЗОЛЯЦИЯ ХОСТА
# ==========================================

if [ "$CAN_SUDO" = true ]; then
    # 1. Performance Mode
    if command -v powerprofilesctl &> /dev/null; then
        powerprofilesctl set performance || true
    fi
    if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
        echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true
    fi

    # 2. ИЗОЛЯЦИЯ СИСТЕМНЫХ ПРОЦЕССОВ
    if [ -n "$HOST_CPUS_MASK" ]; then
        echo "🔒 Изолируем системные службы на ядрах: $HOST_CPUS_MASK..."
        # Ограничиваем системные слайсы, чтобы освободить верхние ядра для QEMU
        sudo systemctl set-property --runtime -- system.slice AllowedCPUs=$HOST_CPUS_MASK
        sudo systemctl set-property --runtime -- init.scope AllowedCPUs=$HOST_CPUS_MASK
    fi

    # 3. Сброс кэшей
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true
    echo 1 | sudo tee /proc/sys/vm/compact_memory > /dev/null 2>&1 || true
fi

# ==========================================
# 🎮 ЗАПУСК QEMU
# ==========================================
echo "🚀 Запуск QEMU..."

# но так как host-процессы зажаты в нижних ядрах, QEMU займет свободные верхние.

qemu-system-x86_64 \
  -enable-kvm \
  -machine q35,accel=kvm \
  -cpu host,kvm=on,kvm_pv_unhalt=on,topoext=on \
  -smp "$VM_CORES",sockets=1,cores="$VM_CORES",threads=1 \
  -m "${VM_MEM_MB}M" \
  -mem-prealloc \
  -device virtio-vga-gl,blob=true,max_outputs=1,xres=1920,yres=1080 \
  -display gtk,gl=on,grab-on-hover=on,zoom-to-fit=on  \
  -device virtio-blk-pci,drive=systemdisk,iothread=io1 \
  -drive file="$DISK_FILE",if=none,id=systemdisk,format=qcow2,aio=io_uring,cache=none \
  -object iothread,id=io1 \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device qemu-xhci \
  -device usb-host,vendorid=0x04f2,productid=0xb83c \
  -device intel-hda -device hda-duplex,audiodev=snd0 \
  -audiodev pa,id=snd0 \
  -device virtio-rng-pci \
  -name "HighPerfVM"

# Скрипт ждет закрытия QEMU, затем сработает cleanup
