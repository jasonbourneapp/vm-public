{ config, pkgs, lib, isFullDesktop ? true, includeProprietary ? false, ... }:

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
    programs.chromium  = {
      enable = true;

      commandLineArgs = [
        "--ozone-platform=wayland"
        "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE"
        "--enable-gpu-rasterization"
        "--enable-zero-copy"
        "--ignore-gpu-blocklist"
        "--use-angle=vulkan"
        "--disable-gpu-video-decode"
        "--disable-features=GlobalMediaControls,SkiaGraphite"
        "--password-store=basic"
        # Для плавного скролла (если dconf не поможет)
        "--enable-smooth-scrolling"
        "--load-extension=/etc/chrome-extension"
      ];
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
