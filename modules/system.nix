{ config, pkgs, lib, ... }:

{
  # === СЕТЕВЫЕ НАСТРОЙКИ ===
  networking.hostName = "nixos-vm";
  networking.extraHosts = ''
    localhost 127.0.0.1
  '';

  # === НАСТРОЙКИ NIX ===
  nix.settings.experimental-features = [ "nix-command" "flakes" "fetch-closure" ];

  # === БЕЗОПАСНОСТЬ И ПОЛЬЗОВАТЕЛИ ===
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        }
    });
  '';
  security.wrappers.gsr-kms-server =  lib.mkIf pkgs.stdenv.isx86_64 {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+ep";
    source = "${pkgs.gpu-screen-recorder}/bin/gsr-kms-server";
  };

  services.openssh = {
    enable = true;
    settings = {
      # Важно: разрешаем вход по паролю (т.к. у пользователя "user" пароль "1")
      PasswordAuthentication = true;
      # Можно запретить root, так как заходим под user
      PermitRootLogin = "no";
    };
  };
  networking.firewall.allowedTCPPorts = [ 22 ];

  security.sudo.wheelNeedsPassword = false;

  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "networkmanager" "docker" "input" ];
    password = "1";
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

  # === ЗАГРУЗЧИК (BOOTLOADER) ===
  # Условная логика для разной архитектуры:

  # 1. На x86_64 используем GRUB.
  # Это позволяет запускать образ в QEMU без флагов UEFI (OVMF),
  # то есть в стандартном режиме Legacy BIOS.
  boot.loader.grub = {
    enable = pkgs.stdenv.isx86_64;
    device = "/dev/vda";      # Установка в MBR виртуального диска
    forceInstall = true;      # Принудительная установка, если вдруг возникнут сомнения
  };

  # 2. На ARM64 (Apple Silicon) используем systemd-boot.
  # Там обязательно используется UEFI (EDK2/OVMF), и systemd-boot работает лучше.
  boot.loader.systemd-boot.enable = pkgs.stdenv.isAarch64;
  boot.loader.efi.canTouchEfiVariables = pkgs.stdenv.isAarch64;

  # === ЯДРО И ЗАГРУЗКА ===
  boot.kernelModules = [ "uvcvideo" ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };

  # === SYSTEMD TWEAKS ===
  systemd.services = {
    "getty@tty1".enable = false;
    "autovt@tty1".enable = false;
    NetworkManager-wait-online.enable = false;
  };
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  system.stateVersion = "25.05";

  # === КОПИРОВАНИЕ КОНФИГОВ В /etc/nixos ===
  system.activationScripts.populateEtcNixos = let
    configSource = pkgs.runCommand "nixos-config-source" {} ''
      mkdir -p $out
      mkdir -p $out/modules
      mkdir -p $out/fish
      mkdir -p $out/tmux

      # Создаем папку для исходников расширения
      mkdir -p $out/chrome-extension

      # Копируем .env ТОЛЬКО если он существует и виден Nix
      cp ${../configs/dev.env} $out/.env

      # Копируем корневые файлы
      cp ${../flake.nix} $out/flake.nix
      cp ${../flake.lock} $out/flake.lock
      cp ${../vm.nix} $out/vm.nix
      cp ${../vm-console.nix} $out/vm-console.nix
      cp ${../justfile} $out/justfile
      cp ${../black.jpg} $out/black.jpg

      # Копируем модули
      cp ${./system.nix} $out/modules/system.nix
      cp ${./desktop.nix} $out/modules/desktop.nix
      cp ${./packages.nix} $out/modules/packages.nix
      cp ${./packages-console.nix} $out/modules/packages-console.nix
      cp ${./proprietary.nix} $out/modules/proprietary.nix
      cp ${./home.nix} $out/modules/home.nix
      cp ${./home-console.nix} $out/modules/home-console.nix
      cp ${./dconf.nix} $out/modules/dconf.nix

      # Копируем папку с исходным кодом расширения (chrome-extension)
      # Важно: если папка пуста или игнорируется git, это тоже может вызвать ошибку.
      if [ -d "${../chrome-extension}" ]; then
        cp -r ${../chrome-extension}/* $out/chrome-extension/
      fi

      # Копируем fish и tmux
      cp -r ${../fish}/* $out/fish/
      cp -r ${../tmux}/* $out/tmux/
      cp ${../gitconfig.txt} $out/gitconfig.txt
    '';
  in lib.stringAfter [ "etc" ] ''
    # Скрипт выполняется только если /etc/nixos/flake.nix еще нет (первый запуск или чистая установка)
    if [ ! -e /etc/nixos/flake.nix ]; then
      echo "Populating /etc/nixos with mutable configuration files..."
      mkdir -p /etc/nixos
      cp -r ${configSource}/* /etc/nixos/

      # Обязательно даем права на запись, чтобы git и update скрипт работали
      chmod -R +w /etc/nixos

      echo "Configuration files installed to /etc/nixos."
    fi
  '';
}
