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

    # === Добавлено: создаем команду devready как ссылку на jasonbourne ===
    (pkgs.runCommand "devready-alias" {} ''
      mkdir -p $out/bin
      # Создаем символическую ссылку: devready -> путь_к_jasonbourne
      ln -s ${pkgs.jasonbourne}/bin/jasonbourne $out/bin/devready
    '')
  ];

  # Пробрасываем папку с расширением в /etc/chrome-extension
  environment.etc."chrome-extension".source = extensionSource;
}
