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
  ]
  ++ lib.optionals (pkgs.stdenv.hostPlatform.isx86_64 && !isFullDesktop) [
    kitty
    htop
  ]
  # Пакеты, которые устанавливаются только если isFullDesktop = true (Тяжелый софт)
  ++ lib.optionals isFullDesktop ([
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
  # Это условие срабатывает и для 'default' (full), и для 'with-package'
  ++ lib.optionals includeProprietary [
    pkgs.jasonbourne
  ];

  # Пробрасываем папку с расширением в /etc/chrome-extension
  environment.etc."chrome-extension".source = extensionSource;
}
