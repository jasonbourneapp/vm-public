{ config, pkgs, lib, inputs, isFullDesktop ? true, ... }:

{
  imports = [
    ./modules/system.nix
    ./modules/desktop.nix
    ./modules/packages.nix
    ./modules/home.nix
    ] ++ lib.optionals isFullDesktop [
      ./modules/proprietary.nix
    ];
}
