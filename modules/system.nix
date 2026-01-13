{ config, pkgs, lib, ... }:

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
  networking.firewall.allowedTCPPorts = [ 22 ];

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
    extraGroups = [ "wheel" "audio" "video" "networkmanager" "docker" "input" ];
    password = "1";
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

  # === ЗАГРУЗЧИК (BOOTLOADER) ===
  boot.loader.grub = {
    enable = pkgs.stdenv.hostPlatform.isx86_64;
    device = "/dev/vda";
    forceInstall = true;
  };

  boot.loader.systemd-boot.enable = pkgs.stdenv.hostPlatform.isAarch64;
  boot.loader.efi.canTouchEfiVariables = pkgs.stdenv.hostPlatform.isAarch64;

  # === ЯДРО И SYSTEMD ===
  boot.kernelModules = [ "uvcvideo" ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
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

  documentation.enable = false;
  documentation.nixos.enable = false;

  # === КОПИРОВАНИЕ КОНФИГОВ В /etc/nixos ===
  # Используем system.activationScripts для начальной инициализации (Provisioning).
  # Это позволяет создать изменяемые (writable) файлы, в отличие от environment.etc.
  system.activationScripts.populateEtcNixos = lib.stringAfter [ "etc" ] ''
    if [ ! -e /etc/nixos/flake.nix ]; then
      echo "Initializing /etc/nixos from build config..."
      mkdir -p /etc/nixos

      # Копируем структуру файлов (--no-preserve=mode важно, чтобы файлы стали writable)
      cp -r --no-preserve=mode ${nixosConfigSources}/* /etc/nixos/

      # Копируем сгенерированные файлы
      cp --no-preserve=mode ${justFile} /etc/nixos/justfile
      cp --no-preserve=mode ${envFile} /etc/nixos/.env

      # Исправляем права доступа (делаем доступными для записи)
      chmod -R u+rwX,go+rX /etc/nixos
      chown -R user:users /etc/nixos

      echo "Configuration installed to /etc/nixos."
    fi
  '';
}
