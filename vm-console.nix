{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./modules/system.nix
    # Используем те же модули, что и в vm.nix, но с флагом isFullDesktop = false
    # это позволяет управлять составом пакетов через modules/packages.nix и modules/home.nix
    ./modules/packages.nix
    ./modules/home.nix
  ];
}
