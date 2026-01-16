{ config, lib, pkgs, modulesPath, ... }:

let
  # === НАСТРОЙКИ СЕТИ (INFRASTRUCTURE LAYER) ===
  # Получаем IP из ENV (через justfile) или используем fallback из старого проекта
  envIp = builtins.getEnv "BEGET_AUTOGEN_IP";
  # Получаем приватный IP из ENV (ens9), если он передан
  envPrivateIp = builtins.getEnv "BEGET_AUTOGEN_PRIVATE_IP";

  publicIface = {
    name = "ens3";
    # Fallback IP из hosts/beget-autogen/network.nix
    ipAddress = if envIp != "" then envIp else "31.207.77.3";
    prefixLength = 32;
    gateway = "100.100.1.1"; # Стандартный шлюз Beget
  };

in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # === 1. DISK CONFIGURATION (Disko) ===
  # Перенесено из hosts/beget-autogen/disk.nix
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # BIOS boot
              priority = 1;
            };
            ESP = {
              size = "512M";
              type = "EF00"; # EFI System
              priority = 2;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0077" "dmask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [ "defaults" "noatime" ];
              };
            };
          };
        };
      };
    };
  };

  # === 2. NETWORK CONFIGURATION (CRITICAL HACKS) ===
  # Переопределяем настройки сети из system.nix, так как на сервере нужен systemd-networkd
  # и специфическая маршрутизация.
  networking = {
    hostName = lib.mkForce "beget-autogen";
    useDHCP = false;
    useNetworkd = true; # Включаем systemd-networkd (как в vps-common.nix)

    # Отключаем NetworkManager, если он включен в desktop.nix, чтобы не конфликтовал на сервере
    networkmanager.enable = lib.mkForce false;

    nameservers = [ "1.1.1.1" "8.8.8.8" ];

    interfaces.${publicIface.name} = {
      useDHCP = false;
      ipv4.addresses = [{
        address = publicIface.ipAddress;
        prefixLength = publicIface.prefixLength;
      }];

      # === ВАЖНЫЙ ХАК ИЗ MODULES/VPS-COMMON.NIX ===
      # Без этого маршрутизация на Beget работать не будет из-за /32 маски и шлюза
      ipv4.routes = [
        # 1. Говорим системе, что шлюз доступен "напрямую" (on-link)
        {
          address = publicIface.gateway;
          prefixLength = 32;
        }
        # 2. Устанавливаем маршрут по умолчанию через этот шлюз
        {
          address = "0.0.0.0";
          prefixLength = 0;
          via = publicIface.gateway;
        }
      ];
    };

    # === НАСТРОЙКА ПРИВАТНОЙ СЕТИ (ENS9) ===
    # Включается только если передан IP через just deploy-beget-autogen ... private_ip=...
    interfaces.ens9 = lib.mkIf (envPrivateIp != "") {
      useDHCP = false;
      ipv4.addresses = [{
        address = envPrivateIp;
        prefixLength = 24; # Стандартная маска для приватных сетей
      }];
    };
  };

  # Авторасширение разделов при ресайзе диска провайдером
  boot.growPartition = true;

  # === 3. SSH & ACCESS CONTROL (CRITICAL) ===
  # В modules/system.nix стоит PermitRootLogin = "no".
  # Нам нужно ПЕРЕОПРЕДЕЛИТЬ это, иначе мы не попадем на сервер после прошивки.

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      # Перебиваем настройки из system.nix
      PermitRootLogin = lib.mkForce "prohibit-password";
      PasswordAuthentication = lib.mkForce false;
    };
  };

  users.users.root = {
    # Ключи из configuration.nix проекта-прошивальщика
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/Pm3dni/sg8gvQrO8nZGCYLxlPMwO3RfY92msE3zICVyu0ycCUIiRB1KW4JSOdkwglt2wbrhQcb1FdUKAnNNybp78abA8NXUcM5oSDrq4ZVyKTm/qKENpLg7ajni8BXwV3fr0p55nKc+sfl1/Pqcl0X8yHXm4Nr18z9kwy70yS4+F+6rHaVnOfcE+/2ms8q0eG/hxYuTqt47BMfaD5UqFB0MfS7147GqnHfJfzuUn0TMueFvE9V/zZS/0Ner/Pi/5iz+g8AASRkZQvNhCjWXOqCOSqhkrvo3a9M5V03+1CJ4tefhdHt/HvrHbUaxb6HkD8vqbU6P6p01BrzB6F4awq9VeJ9SfrEEZaLWbtg1nn0NBjdNlMaimaP7uSF2HL4K+V4qbfFV58SXbs1EyHwH0nsWVrgtmPK7KrAUgWyBG2AnGAkrTvUEb465KVNa4YQp9FKD8uy3kkpXIzdumXhWLwKayssEPri2kg36uTFkEjq8jTIeltjyueTK8KuSFfAJ//emBqrZC1FKnwXR+uQ1FB7dfUDKCkhXUpdBLHT1DOrkofMoOFDETP9gJghTza+sfEMU/lQSOnMBsn5aAGKs+62EsM2kTfq0JRicPOyX7m5TlH6Rv7qWSYYy0or7CqVf/rZqS0NC6KILWDo9H3T3ZZ7/EHGrAsHnzhjbFsD+PhQ== bg@nixos"
    ];
  };

  # === 4. HARDWARE SPECIFICS ===
  # Модули ядра из configuration.nix / common.nix для поддержки виртуализации
  boot.initrd.availableKernelModules = [
    "virtio_net"
    "virtio_pci"
    "virtio_mmio"
    "virtio_blk"
    "virtio_scsi"
    "ata_piix"
    "uhci_hcd"
    "virtio_rng"
  ];
  boot.initrd.kernelModules = [ "nvme" "virtio_balloon" "virtio_console" ];

  # Включаем форвардинг (из configuration.nix)
  boot.kernel.sysctl."net.ipv4.ip_forward" = true;

  # === FIX: GRUB DUPLICATED DEVICES ===
  # Используем 'devices' (множественное число) и mkForce, чтобы NixOS не пыталась
  # объединить это с настройкой 'device' из system.nix, создавая дубликат.
  boot.loader.grub = {
    enable = true;
    devices = lib.mkForce [ "/dev/vda" ];
  };
}
