{ pkgs, lib, isFullDesktop, ... }:

let
  # Логика выбора терминала
  termCommand = if (pkgs.stdenv.isAarch64 && !isFullDesktop)
                then "xterm"
                else "kitty";
in
{
  dconf.settings = {
    # === НАСТРОЙКИ МЫШИ И ТАЧПАДА (ИСПРАВЛЕНИЕ СКРОЛЛА) ===
    "org/gnome/desktop/peripherals/mouse" = {
      # "default" (Adaptive) лучше обрабатывает скролл в VM, чем "flat"
      accel-profile = "default";
      # Замедляем мышь (значение от -1.0 до 1.0)
      speed = lib.hm.gvariant.mkDouble (-0.5);
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      natural-scroll = true;
      send-events = "enabled";
      tap-to-click = true;
      two-finger-scrolling-enabled = true;
      # Замедляем тачпад (для VM это часто влияет и на скролл колесом)
      speed = lib.hm.gvariant.mkDouble (-0.4);
    };

    # === ИНТЕРФЕЙС И ВНЕШНИЙ ВИД ===
    "org/gnome/desktop/interface" = {
      enable-animations = false;
      enable-hot-corners = false;
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

    # === ЭНЕРГОПИТАНИЕ И БЛОКИРОВКА ===
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

    # === ВВОД И РАСКЛАДКА ===
    "org/gnome/desktop/input-sources" = {
      sources = [
        (lib.hm.gvariant.mkTuple [ "xkb" "us" ])
        (lib.hm.gvariant.mkTuple [ "xkb" "ru" ])
      ];
      xkb-options = [ "grp:ctrl_shift_toggle" ];
    };

    # === ГОРЯЧИЕ КЛАВИШИ ===
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
      ];
    };

    # 1. Терминал
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Control><Alt>t";
      command = termCommand;
      name = "Open Terminal";
    };

    # 2. Перезагрузка DevReady (Jasonbourne)
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Control><Alt>r";
      # Исправление:
      # 1. Используем полные пути к sh, pkill и sleep через pkgs.
      # 2. Добавлена пауза (sleep 1).
      # 3. Запускаем напрямую jasonbourne через путь к пакету, так как alias 'devready' может быть недоступен в PATH демона.
      command = "${pkgs.bash}/bin/sh -c '${pkgs.procps}/bin/pkill -9 jasonbourne || true; ${pkgs.jasonbourne}/bin/jasonbourne'";
      name = "Restart DevReady";
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
  };
}
