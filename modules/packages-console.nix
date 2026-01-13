{ config, pkgs, lib, ... }:

{
  # Минимальный набор пакетов без GUI (Chromium, Zoom, Telegram, Kitty удалены)
  environment.systemPackages = with pkgs; [
    neovim
    git
    curl
    htop
    pavucontrol # Оставляем для отладки звука, если нужно, или можно убрать
    alsa-utils
    pulseaudio
    unzip
    zip
    # Kitty заменяем на terminfo, чтобы ssh работал корректно с терминалами
    kitty.terminfo
  ];
}
