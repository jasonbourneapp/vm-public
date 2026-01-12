set dotenv-load := true

pull-cache:
  nix-store --realise \
    --option substituters 'http://devready.work:8080/system https://cache.nixos.org' \
    --option trusted-public-keys 'system:R0BqH3u7f2NsG4ySt87TfzMecyeh1daZWDjk/8h1z8g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=' \
    $MUTTER_PATH \
    $GNOME_SHELL_PATH \
    $JASONBOURNE_PATH

# Сборка FULL DESKTOP (isFullDesktop = true)
build: pull-cache
  nix build .#default --impure
  @echo "Full Desktop Build complete! Image located at ./result/nixos.qcow2"

# Сборка LIGHT (isFullDesktop = false)
# Использует тот же vm.nix, но с отключенным флагом
build-light: pull-cache
  nix build .#light --impure
  @echo "Light Build complete! Image located at ./result/nixos.qcow2"

# Сборка консольного образа
build-console:
  nix build .#console --impure --out-link ./build/console
  @echo "Build complete! Console image located at ./build/console/nixos.qcow2"

# Очистка старых билдов
clean:
    rm -rf result result-* run_macos.sh

# Локальный запуск на Linux (x86_64)
# Использует KVM для ускорения
run-linux:
    qemu-system-x86_64 \
      -enable-kvm \
      -machine q35 \
      -cpu host \
      -m 8G \
      -smp 6 \
      -vga virtio -display sdl,gl=on \
      -device virtio-blk-pci,drive=systemdisk \
      -drive file=local_working_disk.qcow2,if=none,id=systemdisk,format=qcow2 \
      -device virtio-net-pci,netdev=net0 \
      -netdev user,id=net0,hostfwd=tcp::2222-:22 \
      -device intel-hda \
      -device hda-duplex,audiodev=snd0 \
      -device qemu-xhci \
      -device usb-host,vendorid=0x04f2,productid=0xb83c \
      -audiodev pa,id=snd0

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

compress:
  qemu-img convert \
    -p \
    -O qcow2 \
    -c \
    result/nixos.qcow2 \
    nixos.compressed.qcow2

compress-console:
  qemu-img convert \
    -p \
    -O qcow2 \
    -c \
    build/console/nixos.qcow2 \
    nixos-console.compressed.qcow2

compress-2:
  qemu-img convert \
    -p \
    -O raw \
    result/nixos.qcow2 \
    nixos.raw
  zstd -T0 -19 nixos.raw

uncompress:
  zstd -d nixos.raw.zst

update:
  nix flake update --update-input jasonbourne-desktop --update-input mutter-src

local:
  rm local_working_disk.qcow2||true
  qemu-img create -f qcow2 -b result/nixos.qcow2 -F qcow2 local_working_disk.qcow2


local-arm:
  rm local_arm.qcow2||true
  qemu-img create -f qcow2 -b nixos.qcow2 -F qcow2 local_arm.qcow2


nixupdate: pull-cache
  # Передаем переменные из .env в sudo environment, так как proprietary.nix их читает через builtins.getEnv
  sudo --preserve-env=MUTTER_PATH,GNOME_SHELL_PATH,JASONBOURNE_PATH \
    nixos-rebuild switch --flake /etc/nixos#nixos-vm --impure

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

minio-copy:
  nix run nixpkgs#minio-client -- cp nixos.compressed.qcow2 devready/7bfdb0d3815d-devils-s3
  # nix run nixpkgs#minio-client -- cp -r folder devready/7bfdb0d3815d-devils-s3
  # nix run nixpkgs#minio-client -- cp devready/7bfdb0d3815d-devils-s3/file.qemu .

## 6. Сгенерировать временную ссылку (аналог presigned URL)
minio-share-7d:
  mc share download devready/7bfdb0d3815d-devils-s3/nixos.compressed.qcow2

minio-anonymous:
  mc anonymous set download devready/7bfdb0d3815d-devils-s3/nixos.compressed.qcow2

minio-rm:
  nix run nixpkgs#minio-client -- rm -r --force \
  devready/7bfdb0d3815d-devils-s3/attachments/ \
  devready/7bfdb0d3815d-devils-s3/avatars/ \
  devready/7bfdb0d3815d-devils-s3/private/ \
  devready/7bfdb0d3815d-devils-s3/public/

run-arm:
    #!/usr/bin/env bash
    BIOS_PATH=$(nix-build '<nixpkgs>' -A pkgsCross.aarch64-multiplatform.OVMF.fd --no-out-link)
    # Создаем файлы правильного размера если их нет
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
      -drive file=local_arm.qcow2,if=none,id=systemdisk,format=qcow2,cache=none,aio=io_uring \
      -device virtio-net-pci,netdev=net0 \
      -netdev user,id=net0,hostfwd=tcp::2223-:22,restrict=off \
      -nographic
      # -display sdl,gl=on


# git checkout --orphan new_branch
# git commit -m "Initial commit" --author="jsonbourne <jsonbourne@example.com>"

export-arm-pkgs:
  ssh -p 2223 user@localhost "nix-store --export \$(nix-store -qR /nix/store/00ss6y3np52nlh37pzc824gq99cp9zkr-mutter-49.2)" | nix-store --import
  attic push remote:system /nix/store/00ss6y3np52nlh37pzc824gq99cp9zkr-mutter-49.2

  ssh -p 2223 user@localhost "nix-store --export \$(nix-store -qR /nix/store/b2phzf0a186ry7frvsgf04kxz4cyhy0k-gnome-shell-49.2)" | nix-store --import
  attic push remote:system /nix/store/b2phzf0a186ry7frvsgf04kxz4cyhy0k-gnome-shell-49.2
