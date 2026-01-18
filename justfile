set dotenv-load := true

pull-cache:
  nix-store --realise \
    --option substituters 'http://devready.work:8080/system https://cache.nixos.org' \
    --option trusted-public-keys 'system:R0BqH3u7f2NsG4ySt87TfzMecyeh1daZWDjk/8h1z8g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=' \
    $MUTTER_PATH \
    $GNOME_SHELL_PATH \
    $JASONBOURNE_PATH

# Сборка FULL DESKTOP -> result-desktop
build: pull-cache
  nix build .#default --impure --out-link result-desktop
  @echo "Full Desktop Build complete! Image located at ./result-desktop/nixos.qcow2"

# Сборка для VirtualBox (OVA) -> result-vbox
build-vbox: pull-cache
  nix build .#vbox --impure --out-link result-vbox
  @echo "VirtualBox Build complete! OVA image located at ./result-vbox/*.ova"

# Сборка с пакетом -> result-with-package
build-with-package: pull-cache
  nix build .#with-package --impure -L --out-link result-with-package

# Сборка LIGHT -> result-light
build-light: pull-cache
  nix build .#light --impure --out-link result-light
  @echo "Light Build complete! Image located at ./result-light/nixos.qcow2"

# Сборка консольного образа -> build/console (уже было настроено отдельно)
build-console:
  nix build .#console --impure --out-link ./build/console
  @echo "Build complete! Console image located at ./build/console/nixos.qcow2"

# Сборка ISO -> result-iso
build-iso: pull-cache
  nix build .#iso --impure --out-link result-iso
  @echo "ISO Build complete! Image located at ./result-iso/*.iso"

# Очистка старых билдов (удалит result, result-desktop, result-vbox и т.д.)
clean:
    rm -rf result result-* run_macos.sh

# Локальный запуск на Linux (x86_64)
run-linux:
    qemu-system-x86_64 \
      -enable-kvm \
      -machine q35 \
      -cpu host \
      -m 8G \
      -smp 6 \
      -vga virtio \
      -device virtio-blk-pci,drive=systemdisk \
      -drive file=local_working_disk.qcow2,if=none,id=systemdisk,format=qcow2 \
      -device virtio-net-pci,netdev=net0 \
      -netdev user,id=net0,hostfwd=tcp::2222-:22 \
      -device intel-hda \
      -device hda-duplex,audiodev=snd0 \
      -device qemu-xhci \
      -device usb-host,vendorid=0x04f2,productid=0xb83c \
      -audiodev pa,id=snd0 \
      -display gtk,gl=on,grab-on-hover=on
    # -nographic
    # -display sdl,gl=on


# Запуск консольного образа (без GL и лишних устройств)
run-console:
    qemu-system-x86_64 \
      -enable-kvm \
      -machine q35 \
      -cpu host \
      -m 2G \
      -smp 2 \
      -nographic \
      -device virtio-blk-pci,drive=systemdisk \
      -drive file=local_working_disk.qcow2,if=none,id=systemdisk,format=qcow2 \
      -device virtio-net-pci,netdev=net0 \
      -netdev user,id=net0,hostfwd=tcp::2222-:22


# Сжатие: берем из result-desktop (основной билд)
compress:
  qemu-img convert \
    -p \
    -O qcow2 \
    -c \
    result-with-package/nixos.qcow2 \
    nixos-x86_64.qcow2

compress-console:
  qemu-img convert \
    -p \
    -O qcow2 \
    -c \
    build/console/nixos.qcow2 \
    nixos-console.compressed.qcow2

compress-arm64:
  qemu-img convert \
    -p \
    -O qcow2 \
    -c \
    arm/nixos.qcow2 \
    nixos-arm64.qcow2

# Сжатие 2: берем из result-desktop
compress-2:
  qemu-img convert \
    -p \
    -O raw \
    result-desktop/nixos.qcow2 \
    nixos.raw
  zstd -T0 -19 nixos.raw

uncompress:
  zstd -d nixos.raw.zst

update:
  nix flake update --update-input jasonbourne-desktop --update-input mutter-src

# Создание локального диска: берем из result-desktop
local:
  rm local_working_disk.qcow2||true
  qemu-img create -f qcow2 -b result-with-package/nixos.qcow2 -F qcow2 local_working_disk.qcow2


local-arm:
  rm local_arm.qcow2||true
  qemu-img create -f qcow2 -b nixos.compressed.arm.qcow2 -F qcow2 local.compressed.arm.qcow2

nixupdate: pull-cache
  sudo --preserve-env=MUTTER_PATH,GNOME_SHELL_PATH,JASONBOURNE_PATH,MUTTER_PATH_ARM,GNOME_SHELL_PATH_ARM,JASONBOURNE_PATH_ARM \
    nixos-rebuild switch --flake /etc/nixos#nixos-vm --impure

live-cd-update:
  sudo --preserve-env=MUTTER_PATH,GNOME_SHELL_PATH,JASONBOURNE_PATH \
    nixos-rebuild test --flake /etc/nixos#nixos-vm --impure

nixupdate-console:
  sudo nixos-rebuild switch --flake /etc/nixos#nixos-console --impure

minio:
  nix run nixpkgs#minio-client

minio-init:
  nix run nixpkgs#minio-client -- alias set devready \
    https://s3.ru1.storage.beget.cloud \
    655X6UM0JPBHMVJFDWPZ \
    sOKxQNf6nP2LnEkUlm5J6Tq2dHn9yDCf49vmfhso

minio-alias-ls:
  nix run nixpkgs#minio-client -- alias ls

minio-ls:
  nix run nixpkgs#minio-client -- ls devready/7bfdb0d3815d-devils-s3

# Копирование в Minio: исправлены пути к result-vbox и result-iso
minio-copy:
  nix run nixpkgs#minio-client -- cp nixos-arm64.qcow2 devready/7bfdb0d3815d-devils-s3
  nix run nixpkgs#minio-client -- cp nixos-x86_64.qcow2 devready/7bfdb0d3815d-devils-s3
  nix run nixpkgs#minio-client -- cp result-vbox/*.ova devready/7bfdb0d3815d-devils-s3
  nix run nixpkgs#minio-client -- cp result-iso/iso/*.iso devready/7bfdb0d3815d-devils-s3

## 6. Сгенерировать временную ссылку (аналог presigned URL)
minio-share-7d:
  mc share download devready/7bfdb0d3815d-devils-s3/nixos.compressed.qcow2

minio-anonymous:
  mc anonymous set download devready/7bfdb0d3815d-devils-s3/nixos.compressed.qcow2

minio-rm:
  nix run nixpkgs#minio-client -- rm -r --force \
  devready/7bfdb0d3815d-devils-s3/nixos.compressed.qcow2 \
  devready/7bfdb0d3815d-devils-s3/nixos.compressed.arm.qcow2

resize:
  qemu-img resize local.compressed.arm.qcow2 +20G

run-arm:
    #!/usr/bin/env bash
    BIOS_PATH=$(nix-build '<nixpkgs>' -A pkgsCross.aarch64-multiplatform.OVMF.fd --no-out-link)
    if [ ! -f flash0.img ]; then \
      dd if=/dev/zero of=flash0.img bs=1M count=64; \
      dd if="$BIOS_PATH/FV/QEMU_EFI.fd" of=flash0.img conv=notrunc; \
    fi
    if [ ! -f flash1.img ]; then \
      dd if=/dev/zero of=flash1.img bs=1M count=64; \
    fi
    # -cpu cortex-a72
    qemu-system-aarch64 \
      -machine virt \
      -cpu neoverse-n1 \
      -accel tcg,thread=multi \
      -m 20G \
      -object memory-backend-ram,size=20G,id=mem0 \
      -numa node,memdev=mem0 \
      -smp 6,threads=1,cores=6 \
      -drive if=pflash,format=raw,readonly=on,file=flash0.img \
      -drive if=pflash,format=raw,file=flash1.img \
      -device virtio-gpu-pci \
      -device qemu-xhci \
      -device usb-kbd \
      -device usb-tablet \
      -device virtio-scsi-pci,id=scsi0 \
      -device scsi-hd,drive=systemdisk \
      -drive file=local.compressed.arm.qcow2,if=none,id=systemdisk,format=qcow2,cache=none,aio=io_uring \
      -device virtio-net-pci,netdev=net0 \
      -netdev user,id=net0,hostfwd=tcp::2223-:22,restrict=off \
      -nographic
      # -display sdl,gl=on


# git checkout --orphan new_branch
# git commit -m "Initial commit" --author="jsonbourne <jsonbourne@example.com>"

export-arm-pkgs:
    #!/usr/bin/env bash
    # Используем $VAR, так как .env загружает их в переменные окружения
    pkgs=(
        "$JASONBOURNE_PATH_ARM"
        "$MUTTER_PATH_ARM"
        "$GNOME_SHELL_PATH_ARM"
    )

    for pkg in "${pkgs[@]}"; do
        [[ -z "$pkg" ]] && continue
        echo "---------------------------------------------------"
        echo "Processing: $pkg"
        ssh -p 2223 user@localhost "nix-store --export \$(nix-store -qR $pkg)" | nix-store --import
        attic push remote:system "$pkg"
    done

# === ПРОШИВКА SERVER (VPS BEGET) ===

burn-beget-autogen ip_addr="" private_ip="": pull-cache
    @echo "Подготовка к прошивке beget-autogen..."
    export BEGET_AUTOGEN_IP="{{ip_addr}}"; \
    export BEGET_AUTOGEN_PRIVATE_IP="{{private_ip}}"; \
    if [ -z "{{ip_addr}}" ]; then \
        echo "Сборка конфигурации (IP: 31.207.77.3 по умолчанию)..."; \
    else \
        echo "Сборка конфигурации (IP: {{ip_addr}}, Private IP: {{private_ip}})..."; \
    fi; \
    echo "1. Сборка Disko скрипта..."; \
    nix build .#nixosConfigurations.nixos-beget.config.system.build.diskoScript --impure --out-link result-disko; \
    echo "2. Сборка системы..."; \
    nix build .#nixosConfigurations.nixos-beget.config.system.build.toplevel --impure --out-link result-system; \
    if [ -z "{{ip_addr}}" ]; then \
        echo "IP не передан, используем SSH alias: beget_autogen"; \
        nix run github:nix-community/nixos-anywhere -- --store-paths ./result-disko ./result-system beget_autogen; \
    else \
        echo "Прошиваем на указанный IP: {{ip_addr}}"; \
        nix run github:nix-community/nixos-anywhere -- --store-paths ./result-disko ./result-system root@{{ip_addr}}; \
    fi

# === DEPLOY / UPDATE (BEGET VPS) ===

deploy-beget-autogen ip_addr="" private_ip="": pull-cache
    @echo "Deploying to Beget (Colmena)... IP: {{ if ip_addr == "" { "SSH Alias (beget_autogen)" } else { ip_addr } }}"
    export BEGET_AUTOGEN_IP="{{ip_addr}}"; \
    export BEGET_AUTOGEN_PRIVATE_IP="{{private_ip}}"; \
    nix develop -c colmena apply --on nixos-beget --impure
