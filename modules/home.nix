{ config, pkgs, lib, pkgs-unstable, isFullDesktop ? true, ... }:

{
  # Исключаем пакет gnome-tour из системы
  environment.gnome.excludePackages = [ pkgs.gnome-tour ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {
    inherit pkgs-unstable isFullDesktop;
    pkgs-master = pkgs-unstable;
  };

  home-manager.users.user = { lib, isFullDesktop, ... }: {
    imports = [
      ./dconf.nix
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

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        enable-animations = false;
        enable-hot-corners = false;
      };
      "org/gnome/desktop/peripherals/mouse" = {
        accel-profile = "flat";
      };
      "org/gnome/desktop/wm/preferences" = {
        button-layout = "close:";
        num-workspaces = 1;
      };
      "org/gnome/mutter" = {
        dynamic-workspaces = false;
        edge-tiling = false;
      };
      "org/gnome/shell" = {
        disable-user-extensions = true;
      };
      "org/gnome/desktop/background" = {
        primary-color = "#000000";
        picture-uri = "file:///home/user/.backgrounds/black.jpg";
        picture-uri-dark = "file:///home/user/.backgrounds/black.jpg";
      };

      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-type = "nothing";
        power-button-action = "nothing";
        idle-brightness = false;
      };

      "org/gnome/desktop/session" = {
        idle-delay = lib.hm.gvariant.mkUint32 0;
      };

      "org/gnome/desktop/screensaver" = {
        lock-enabled = false;
        idle-activation-enabled = false;
      };
    };

    home.file = {
      ".gitconfig".source = ../gitconfig.txt;
      ".backgrounds/black.jpg".source = ../black.jpg;
    };


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
        # Загружаем распакованное расширение из папки /etc/chrome-extension
        "--load-extension=/etc/chrome-extension"
      ];
    };

  };


  programs.chromium  = {
    enable = true;

    # Здесь мы "легализуем" расширение и отключаем предупреждения
    extraOpts = {
      "CommandLineFlagSecurityWarningsEnabled" = false;
      "ExtensionInstallAllowlist" = [
        "igobdnholdliocagogjjbmbooijahmha" # Ваш ID из ключа
      ];
      "ExtensionInstallSources" = [
        "file:///etc/chrome-extension/*"
      ];
      "DeveloperToolsAvailability" = 1;
    };
  };
}
