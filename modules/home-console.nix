{ config, pkgs, lib, ... }:

{
  # Исключаем пакет gnome-tour из системы (на всякий случай)
  environment.gnome.excludePackages = [ pkgs.gnome-tour ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {
    pkgs-master = pkgs;
  };

  home-manager.users.user = { lib, ... }: {
    imports = [
      ../fish/fish.nix
      ../tmux/tmux.nix
    ];

    home.username = "user";
    home.homeDirectory = "/home/user";
    home.stateVersion = "25.05";

    programs.home-manager.enable = true;

    # Конфигурация dconf и Chrome удалена.
    # Оставляем только базовые файлы
    home.file = {
      ".gitconfig".source = ../gitconfig.txt;
    };
  };
}
