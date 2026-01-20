{ config, pkgs, lib, isVirtualBox ? false, ... }:

let
  # === ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ (СБОРКА) ===
  # Получаем переменные во время сборки на хосте
  mutterPath = builtins.getEnv "MUTTER_PATH";
  gnomeShellPath = builtins.getEnv "GNOME_SHELL_PATH";
  jasonbournePath = builtins.getEnv "JASONBOURNE_PATH";
  mutterPathArm = builtins.getEnv "MUTTER_PATH_ARM";
  gnomeShellPathArm = builtins.getEnv "GNOME_SHELL_PATH_ARM";
  jasonbournePathArm = builtins.getEnv "JASONBOURNE_PATH_ARM";

  # === ГЕНЕРАЦИЯ ФАЙЛОВ КОНФИГУРАЦИИ ===

  # 1. Генерируем .env файл
  envFile = pkgs.writeText "dotenv" ''
    MUTTER_PATH=${mutterPath}
    GNOME_SHELL_PATH=${gnomeShellPath}
    JASONBOURNE_PATH=${jasonbournePath}
    MUTTER_PATH_ARM=${mutterPathArm}
    GNOME_SHELL_PATH_ARM=${gnomeShellPathArm}
    JASONBOURNE_PATH_ARM=${jasonbournePathArm}
  '';

  # 2. Генерируем justfile
  justFile = pkgs.writeText "justfile" ''
    set dotenv-load := true

    pull-cache:
      nix-store --realise \
        --option substituters 'http://devready.work:8080/system https://cache.nixos.org' \
        --option trusted-public-keys 'system:R0BqH3u7f2NsG4ySt87TfzMecyeh1daZWDjk/8h1z8g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=' \
        $MUTTER_PATH \
        $GNOME_SHELL_PATH \
        $JASONBOURNE_PATH

    nixupdate: pull-cache
      sudo --preserve-env=MUTTER_PATH,GNOME_SHELL_PATH,JASONBOURNE_PATH,MUTTER_PATH_ARM,GNOME_SHELL_PATH_ARM,JASONBOURNE_PATH_ARM \
      nixos-rebuild switch --flake /etc/nixos#nixos-vm --impure
  '';

  # 3. Собираем структуру исходников конфига в одну директорию (в Nix Store)
  nixosConfigSources = pkgs.runCommand "nixos-config-src" {} ''
    mkdir -p $out
    mkdir -p $out/modules
    mkdir -p $out/fish
    mkdir -p $out/tmux
    mkdir -p $out/chrome-extension
    mkdir -p $out/scripts

    # Копируем корневые файлы
    cp ${../flake.nix} $out/flake.nix
    cp ${../flake.lock} $out/flake.lock
    cp ${../vm.nix} $out/vm.nix
    cp ${../vm-console.nix} $out/vm-console.nix
    cp ${../black.jpg} $out/black.jpg
    cp ${../gitconfig.txt} $out/gitconfig.txt

    # Копируем модули
    cp ${./system.nix} $out/modules/system.nix
    cp ${./desktop.nix} $out/modules/desktop.nix
    cp ${./packages.nix} $out/modules/packages.nix
    cp ${./packages-console.nix} $out/modules/packages-console.nix
    cp ${./proprietary.nix} $out/modules/proprietary.nix
    cp ${./home.nix} $out/modules/home.nix
    cp ${./home-console.nix} $out/modules/home-console.nix
    cp ${./dconf.nix} $out/modules/dconf.nix

    # Копируем директории (если существуют)
    if [ -d "${../chrome-extension}" ]; then
      cp -r ${../chrome-extension}/* $out/chrome-extension/
    fi

    cp -r ${../fish}/* $out/fish/
    cp -r ${../tmux}/* $out/tmux/
    cp -r ${../scripts}/* $out/scripts/
  '';

in
{
  # === НАСТРОЙКИ СИСТЕМЫ (SYSTEM STATE) ===
  system.stateVersion = "25.05";

  # === СЕТЕВЫЕ НАСТРОЙКИ ===
  networking.hostName = "nixos-vm";
  networking.extraHosts = ''
    localhost 127.0.0.1
  '';
  networking.firewall.allowedTCPPorts = [ 22 35827 ]; # Открываем порт для камеры

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

  security.wrappers.gsr-kms-server = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+ep";
    source = "${pkgs.gpu-screen-recorder}/bin/gsr-kms-server";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  security.sudo.wheelNeedsPassword = false;

  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "networkmanager" "docker" "input" "vboxsf" ];
    password = "1";
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

  # === ЗАГРУЗЧИК (BOOTLOADER) ===
  boot.loader.grub = {
    enable = pkgs.stdenv.hostPlatform.isx86_64;
    # [FIX] Используем lib.mkDefault, чтобы VirtualBox мог переопределить это на /dev/sda
    # QEMU (по умолчанию) будет использовать vda, а VirtualBox — sda.
    device = lib.mkDefault "/dev/vda";
    forceInstall = true;
  };

  boot.loader.systemd-boot.enable = pkgs.stdenv.hostPlatform.isAarch64;
  boot.loader.efi.canTouchEfiVariables = pkgs.stdenv.hostPlatform.isAarch64;

  # === VIRTUALBOX CONFIGURATION ===
  # Применяется только если передан флаг isVirtualBox = true (через flake.nix)
  virtualisation.virtualbox.guest = lib.mkIf isVirtualBox {
    enable = true;
    dragAndDrop = true;
    clipboard = true;
  };

  services.xserver.videoDrivers = lib.mkIf isVirtualBox [ "virtualbox" "modesetting" ];

  # === ЯДРО И МОДУЛИ (Single Source of Truth) ===
  # Определяем конфигурацию v4l2loopback здесь, а не в скриптах
  boot.kernelModules = [ "uvcvideo" "v4l2loopback" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    # exclusive_caps=1 нужен для Chrome/WebRTC
    # video_nr=10 создает /dev/video10
    options v4l2loopback video_nr=10 card_label="NetworkCamera" exclusive_caps=1
  '';

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };

  # === SYSTEMD SERVICES ===

  # Сервис для приема камеры
  systemd.services.camera-receiver = {
    description = "Virtual Camera Receiver (TCP -> /dev/video10)";
    after = [ "network.target" "systemd-modules-load.service" ];
    wants = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    # === [FIX] Добавляем бинарники в PATH сервиса ===
    path = with pkgs; [
      bash
      coreutils  # date, sleep, echo
      gnugrep    # grep
      procps     # pkill
      ffmpeg
      v4l-utils
      netcat
    ];

    # === [FIX] Явно задаем пути к плагинам GStreamer ===
    # environment = {
    #   GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" (with pkgs.gst_all_1; [
    #     gstreamer
    #     gst-plugins-base
    #     gst-plugins-good
    #     gst-plugins-bad
    #     gst-plugins-ugly
    #   ]);
    # };

    serviceConfig = {
      # === [FIX] Запускаем через явный путь к bash ===
      ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/scripts/receive-camera.sh 35827 /dev/video10";

      # Перезапускаем всегда (если gstreamer упадет или скрипт завершится)
      Restart = "always";
      RestartSec = "3";

      # Запускаем от пользователя, но с правами на видео
      User = "user";
      Group = "video";

      # Логирование (Observability)
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.services = {
    "getty@tty1".enable = false;
    "autovt@tty1".enable = false;
    NetworkManager-wait-online.enable = false;
  };

  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  documentation = {
    enable = false;
    nixos.enable = false;
    man.enable = false;
    info.enable = false;
    doc.enable = false;
    # Для разработки иногда нужны маны, но в минимизированном образе отключаем
  };

  nix.optimise.automatic = true;

  # Удалить ненужные локали
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "ru_RU.UTF-8/UTF-8" ];

  # === КОПИРОВАНИЕ КОНФИГОВ В /etc/nixos ===
  system.activationScripts.populateEtcNixos = lib.stringAfter [ "etc" ] ''
    if [ ! -e /etc/nixos/flake.nix ]; then
      echo "Initializing /etc/nixos from build config..."
      mkdir -p /etc/nixos

      # Копируем структуру файлов
      cp -r --no-preserve=mode ${nixosConfigSources}/* /etc/nixos/

      # Копируем сгенерированные файлы
      cp --no-preserve=mode ${justFile} /etc/nixos/justfile
      cp --no-preserve=mode ${envFile} /etc/nixos/.env

      # Исправляем права доступа (скриптам нужен +x)
      chmod -R u+rwX,go+rX /etc/nixos
      chmod +x /etc/nixos/scripts/*.sh

      chown -R user:users /etc/nixos

      echo "Configuration installed to /etc/nixos."
    fi
  '';
}
