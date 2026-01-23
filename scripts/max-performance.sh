#!/usr/bin/env bash

# === НАСТРОЙКИ ===
DISK_FILE="local_working_disk.qcow2"
DEFAULT_CORES=4
DEFAULT_MEM_MB=4096

echo "🚀 Подготовка к запуску High-Performance VM (Robust Edition)..."

# 1. Проверка прав sudo (не блокирующая)
CAN_SUDO=true
if ! command -v sudo &> /dev/null || ! sudo -v 2>/dev/null; then
    echo "⚠️  Нет прав sudo или sudo не установлен."
    echo "    Оптимизации (CPU governor, сброс кэшей) будут пропущены."
    CAN_SUDO=false
fi

# ==========================================
# 🧠 ДИНАМИЧЕСКИЙ РАСЧЕТ РЕСУРСОВ
# ==========================================

# --- РАСЧЕТ CPU ---
if command -v nproc &> /dev/null; then
    TOTAL_CORES=$(nproc)
else
    echo "⚠️  'nproc' не найден. Используем значение по умолчанию: $DEFAULT_CORES ядра."
    TOTAL_CORES=$DEFAULT_CORES
fi

# Правило: Максимум - 1 ядро
VM_CORES=$((TOTAL_CORES - 1))

# Правило: Минимально 4 ядра
if [ "$VM_CORES" -lt 4 ]; then
    VM_CORES=4
fi
# Если физически ядер меньше 4, берем сколько есть
if [ "$VM_CORES" -gt "$TOTAL_CORES" ]; then
    VM_CORES=$TOTAL_CORES
fi


# --- РАСЧЕТ RAM ---
if [ -f /proc/meminfo ] && command -v awk &> /dev/null; then
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
else
    echo "⚠️  Не удалось определить RAM (/proc/meminfo или awk отсутствуют). Используем: $DEFAULT_MEM_MB MB."
    TOTAL_MEM_MB=$((DEFAULT_MEM_MB + 3000)) # Чтобы логика ниже не сломалась, эмулируем запас
fi

# Правило: Выделять Максимум - 2.5GB (2560 MB)
VM_MEM_MB=$((TOTAL_MEM_MB - 2560))

# Правило: Лимит 8 GB
if [ "$VM_MEM_MB" -gt 8192 ]; then
    VM_MEM_MB=8192
fi

# Правило: Минимально 4 GB
if [ "$VM_MEM_MB" -lt 4096 ]; then
    VM_MEM_MB=4096
fi


# --- РАСЧЕТ TASKSET (Привязка ядер) ---
RUN_PREFIX=""
PIN_MASK=""

if command -v taskset &> /dev/null && command -v seq &> /dev/null; then
    START_CORE=$((TOTAL_CORES - VM_CORES))
    # Защита от отрицательных чисел
    if [ "$START_CORE" -lt 0 ]; then START_CORE=0; fi

    END_CORE=$((TOTAL_CORES - 1))

    # Генерируем маску
    PIN_MASK=$(seq -s, $START_CORE $END_CORE 2>/dev/null)

    if [ -n "$PIN_MASK" ]; then
        RUN_PREFIX="taskset -c $PIN_MASK"
    fi
else
    echo "ℹ️  'taskset' или 'seq' не найдены. Запуск без привязки ядер."
fi

echo "📊 Конфигурация VM:"
echo "   ➡️ VM CPU: $VM_CORES (Host Total: $TOTAL_CORES)"
echo "   ➡️ VM RAM: $VM_MEM_MB MB"
if [ -n "$RUN_PREFIX" ]; then
    echo "   ➡️ Pinning: ВКЛЮЧЕН ($PIN_MASK)"
else
    echo "   ➡️ Pinning: ВЫКЛЮЧЕН (Система сама распределит потоки)"
fi
echo "---------------------------------------------------"

# ==========================================
# 🛠️ НАСТРОЙКА ХОСТА (Только если есть sudo)
# ==========================================

if [ "$CAN_SUDO" = true ]; then
    # 1. Power Profile
    if command -v powerprofilesctl &> /dev/null; then
        powerprofilesctl set performance || true
    fi

    # 2. CPU Governor
    if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
        echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true
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

# Используем $RUN_PREFIX перед командой qemu.
# Если taskset нет, переменная пустая и команда выполнится напрямую.

$RUN_PREFIX qemu-system-x86_64 \
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

# ==========================================
# 🛑 ОЧИСТКА
# ==========================================
echo "🛑 VM выключена."

if [ "$CAN_SUDO" = true ]; then
    echo "🔙 Возвращаем настройки..."

    if [ "$POWER_MANAGED_BY_DAEMON" = true ]; then
        powerprofilesctl set balanced 2>/dev/null || true
    else
        # Возвращаем powersave только если мы управляли через sysfs
        if [ -w "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]; then
             echo "powersave" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true
        fi
    fi
fi

echo "✅ Готово."
