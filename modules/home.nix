{ config, pkgs, lib, isFullDesktop ? true, includeProprietary ? false, isVirtualBox ? false, ... }:

{
  # Исключаем лишние пакеты GNOME из системы
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-connections
    epiphany          # Браузер
    geary             # Почта
    yelp              # Справка
    gnome-font-viewer
    gnome-calculator
    gnome-calendar
    gnome-clocks
    gnome-contacts
    gnome-maps
    gnome-music
    gnome-weather
    gnome-logs
    gnome-characters
    totem             # Видео
    tali              # Игры...
    iagno
    hitori
    atomix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {
    inherit isFullDesktop includeProprietary;
    pkgs-master = pkgs;
  };

  home-manager.users.user = { lib, isFullDesktop, includeProprietary, ... }: {
    imports = [
      ./dconf.nix # Все настройки GNOME теперь здесь
    ]
      # Условно импортируем fish и tmux только для desktop версии
      ++ lib.optionals isFullDesktop [
        ../fish/fish.nix
        ../tmux/tmux.nix
      ];

    home.username = "user";
    home.homeDirectory = "/home/user";
    home.stateVersion = "25.05";

    programs.home-manager.enable = true;

    xdg.configFile."monitors.xml" = {
      force = true;
      text = let
        # Теперь isVirtualBox доступна здесь
        connectorName = if isVirtualBox then "Virtual1" else "Virtual-1";
        width = "1920";
        height = "1080";
        rate = "60.000";
      in ''
        <monitors version="2">
          <configuration>
            <logicalmonitor>
              <x>0</x>
              <y>0</y>
              <scale>1</scale>
              <primary>yes</primary>
              <monitor>
                <monitorspec>
                  <connector>${connectorName}</connector>
                  <vendor>unknown</vendor>
                  <product>unknown</product>
                  <serial>unknown</serial>
                </monitorspec>
                <mode>
                  <width>${width}</width>
                  <height>${height}</height>
                  <rate>${rate}</rate>
                </mode>
              </monitor>
            </logicalmonitor>
          </configuration>
        </monitors>
      '';
    };

    # === AUTOSTART DEVREADY ===
    xdg.configFile."autostart/devready.desktop" = lib.mkIf includeProprietary {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=DevReady
        Exec=devready
        Terminal=false
        X-GNOME-Autostart-enabled=true
        Comment=Auto-start devready application on login
      '';
    };

    # Копирование статических файлов
    home.file = {
      ".gitconfig".source = ../gitconfig.txt;
      ".backgrounds/black.jpg".source = ../black.jpg;
    };

    # Конфигурация Chromium (Пользовательская часть Home Manager)
    programs.chromium = {
      enable = true;

      # ВАЖНО: Оставляем этот список пустым, чтобы Home Manager НЕ пытался
      # вызывать .override для нашего кастомного пакета (это уберет ошибку сборки).
      commandLineArgs = [];

      package = let
        # 1. Сначала подготавливаем Chromium со всеми флагами на уровне Nixpkgs.
        # Это заменяет commandLineArgs из модуля Home Manager.
        configuredChromium = pkgs.chromium.override {
          commandLineArgs = [
            "--ozone-platform=wayland"
            "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer"
            "--enable-gpu-rasterization"
            "--enable-zero-copy"
            "--ignore-gpu-blocklist"
            "--enable-smooth-scrolling"
            "--password-store=basic"
            "--load-extension=/etc/chrome-extension"
          ];
        };
      in
      # 2. Создаем пакет-обертку, который содержит все файлы Chromium,
      # но подменяет исполняемый файл на вызов через taskset.
      pkgs.symlinkJoin {
        name = "chromium-cpu-limited";
        paths = [ configuredChromium ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          # Удаляем симлинк на бинарник, созданный symlinkJoin
          rm $out/bin/chromium

          # Создаем новый скрипт запуска
          cat > $out/bin/chromium <<EOF
          #!${pkgs.bash}/bin/bash
          exec ${pkgs.util-linux}/bin/taskset -c 0-2 ${configuredChromium}/bin/chromium "\$@"
          EOF

          # Делаем скрипт исполняемым
          chmod +x $out/bin/chromium
        '';
      };
    };
  };

  # Конфигурация Chromium (Системная часть NixOS)
  programs.chromium  = {
    enable = true;
    extraOpts = {
      "CommandLineFlagSecurityWarningsEnabled" = false;
      "ExtensionInstallAllowlist" = [
        "igobdnholdliocagogjjbmbooijahmha"
      ];
      "ExtensionInstallSources" = [
        "file:///etc/chrome-extension/*"
      ];
      "DeveloperToolsAvailability" = 1;
    };
  };
}
