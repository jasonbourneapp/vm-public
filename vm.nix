{ config, pkgs, lib, inputs, isFullDesktop ? true, includeProprietary ? false, isVirtualBox ? false, ... }:

{
  imports = [
    ./modules/system.nix
    ./modules/desktop.nix
    ./modules/packages.nix
    ./modules/home.nix
    ] ++ lib.optionals includeProprietary [
      # Подключаем proprietary модуль только если установлен флаг includeProprietary
      # (используется для build и with-package)
      ./modules/proprietary.nix
    ];
}
