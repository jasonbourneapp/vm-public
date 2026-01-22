{ config, pkgs, lib, isFullDesktop ? true, includeProprietary ? false, ... }:
let
  # Создаем пакет, содержащий все файлы расширения из папки chrome-extension
  extensionSource = pkgs.runCommand "chrome-extension-source" {} ''
    mkdir -p $out
    # Копируем содержимое папки chrome-extension (находится на уровень выше modules)
    cp -r ${../chrome-extension}/* $out/
  '';

in {
  environment.systemPackages = with pkgs; [
    vim
    git
    pavucontrol
    alsa-utils
    pulseaudio
    xdotool
    wmctrl
    gnomeExtensions.window-calls
    just
    direnv
    # Базовые пакеты всегда нужны, terminfo для корректной работы ssh
    kitty.terminfo
    xclip

    # === MEDIA / GSTREAMER ===
    # Необходимы для работы скрипта приема камеры
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    v4l-utils # Для управления видеоустройствами (v4l2-ctl)
  ]
  ++ lib.optionals (pkgs.stdenv.hostPlatform.isx86_64 && !isFullDesktop) [
    kitty
    htop
  ]
  # Пакеты, которые устанавливаются только если isFullDesktop = true (Тяжелый софт)
  ++ lib.optionals isFullDesktop ([
    eza
    unzip
    zip
    curl
    htop
    neovim
    pcmanfm
    kitty
    pkgs.telegram-desktop
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    # Zoom только для x86_64
    zoom-us
    gpu-screen-recorder
  ])
  # Пакеты, которые нужны при включенном proprietary стеке (jasonbourne)
  ++ lib.optionals includeProprietary [
    pkgs.jasonbourne

    # === Добавлено: скрипт-обертка devready ===
    # 1. Убивает старый процесс jasonbourne (если есть).
    # 2. Запускает новый экземпляр.
    (pkgs.writeShellScriptBin "devready" ''
      # Используем pkill из пакета procps по абсолютному пути.
      # -x : точное совпадение имени процесса (jasonbourne), чтобы не задеть лишнее.
      # || true : чтобы скрипт не падал, если процесс не найден.
      ${pkgs.procps}/bin/pkill -9 jasonbourne || true

      # Запускаем бинарник jasonbourne, подменяя текущий процесс шелла (exec).
      # Передаем все аргументы "$@".
      exec ${pkgs.jasonbourne}/bin/jasonbourne "$@"
    '')
  ];

  # Пробрасываем папку с расширением в /etc/chrome-extension
  environment.etc."chrome-extension".source = extensionSource;
}
