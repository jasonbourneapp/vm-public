{pkgs, ...}: {
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Alt>T";
      command = "kitty";
      name = "Open Terminal";
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      natural-scroll = true;
      send-events = "enabled";
      tap-to-click = true;
      two-finger-scrolling-enabled = true;
    };
    "org/gnome/desktop/wm/keybindings" = {
      close = ["<Alt>q"];
      cycle-group = [];
      cycle-group-backward = [];
      cycle-panels = [];
      cycle-panels-backward = [];
      cycle-windows = [];
      cycle-windows-backward = [];
      move-to-monitor-down = [];
      move-to-monitor-left = [];
      move-to-monitor-right = [];
      move-to-monitor-up = [];
      move-to-workspace-1 = [];
      move-to-workspace-last = [];
      move-to-workspace-left = ["<Shift><Control><Alt>Left"];
      move-to-workspace-right = ["<Shift><Control><Alt>Right"];
      switch-panels = [];
      switch-panels-backward = [];
      switch-to-workspace-1 = ["<Alt>1"];
      switch-to-workspace-2 = ["<Alt>2"];
      switch-to-workspace-3 = ["<Alt>3"];
      switch-to-workspace-4 = ["<Alt>4"];
      switch-to-workspace-last = [];
      switch-input-source = ["<Alt>Shift_L"];
    };
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "window-calls@domandoman.xyz"
      ];
    };

    # Настройки масштабирования (если нужны)
    # Раскомментируй и настрой под свои нужды:
    # "org/gnome/desktop/interface" = {
    #   text-scaling-factor = 1.0;  # 1.0, 1.25, 1.5
    # };
    # "org/gnome/mutter" = {
    #   experimental-features = ["scale-monitor-framebuffer"];  # для fractional scaling
    # };
  };
}
