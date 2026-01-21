{
  description = "NixOS QEMU and VirtualBox images (Proprietary/Binary Build) + Colmena Deploy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # === ДОБАВЛЕНО: COLMENA ===
    colmena = {
      url = "github:zhaofengli/colmena/v0.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, disko, colmena, ... }@inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      binaryCacheConfig = {
        nix.settings = {
          trusted-users = [ "root" "@wheel" ];
          experimental-features = [ "nix-command" "flakes" "fetch-closure" ];
          extra-substituters = [
            "https://cache.nixos.org/"
            "https://nixpkgs-unfree.cachix.org"
            "http://devready.work:8080/system"
          ];
          extra-trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
            "system:R0BqH3u7f2NsG4ySt87TfzMecyeh1daZWDjk/8h1z8g="
          ];
        };
      };

      # === МОДУЛЬ ОБНОВЛЕНИЯ ===
      mkUpdateModule = targetFlake: ({ pkgs, ... }: {
        programs.git = {
          enable = true;
          config.safe.directory = [ "/etc/nixos" ];
        };

        environment.systemPackages = [
          pkgs.git
          (pkgs.writeShellScriptBin "update" ''
            set -e
            if [ "$(id -u)" -ne 0 ]; then
               echo "ОШИБКА: Запустите через sudo update"
               exit 1
            fi
            REPO="https://github.com/jasonbourneapp/vm-public.git"
            DIR="/etc/nixos"
            TIMESTAMP=$(date +%Y%m%d-%H%M%S)
            BACKUP_DIR="/etc/nixos-$TIMESTAMP"

            echo ">>> JasonBourne VM Update Tool (Target: ${targetFlake})"
            mkdir -p "$DIR"
            cd "$DIR"
            ${pkgs.git}/bin/git config --global --add safe.directory "$DIR" || true

            if [ ! -d ".git" ]; then
              if [ "$(ls -A "$DIR")" ]; then
                 cp -r "$DIR" "$BACKUP_DIR"
              fi
              ${pkgs.git}/bin/git init
              ${pkgs.git}/bin/git remote add origin "$REPO"
              ${pkgs.git}/bin/git fetch --depth 1 origin master
              ${pkgs.git}/bin/git reset --hard origin/master
            else
              ${pkgs.git}/bin/git fetch --depth 1 origin master
              if [ -n "$(${pkgs.git}/bin/git status --porcelain)" ]; then
                 cp -r "$DIR" "$BACKUP_DIR"
              fi
              ${pkgs.git}/bin/git reset --hard origin/master
            fi

            if [ -f ".env" ]; then
              export $(grep -v '^#' .env | xargs)
            fi

            nixos-rebuild switch --flake .#${targetFlake} --impure --show-trace
            echo ">>> Обновление завершено!"
          '')
        ];
      });

    in
    {
      # === ДОБАВЛЕНО: КОНФИГУРАЦИЯ COLMENA ===
      colmena = {
        meta = {
          # Используем pkgs для архитектуры сервера
          nixpkgs = mkPkgs "x86_64-linux";
          specialArgs = {
            inherit inputs;
            # Параметры должны совпадать с nixos-beget
            isFullDesktop = true;
            includeProprietary = true;
            isVirtualBox = false;
          };
        };

        # Имя хоста для Colmena (на него ссылаемся в justfile: --on nixos-beget)
        "nixos-beget" = { name, nodes, pkgs, ... }: {
          deployment = {
            targetUser = "root";
            # ЛОГИКА IP:
            # 1. Если запущено через Just с IP (export BEGET_AUTOGEN_IP=...), берем его.
            # 2. Иначе берем дефолтный алиас из SSH config.
            targetHost = let
              envIp = builtins.getEnv "BEGET_AUTOGEN_IP";
            in if envIp != "" then envIp else "beget_autogen";
          };

          imports = [
            # Те же модули, что в nixosConfigurations."nixos-beget"
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-beget")
            disko.nixosModules.disko
            ./modules/beget-server.nix
          ];
        };
      };

      packages = forAllSystems (system: let
        pkgs = mkPkgs system;
      in {
        # === FULL DESKTOP IMAGE (build) ===
        default = nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "qcow";

          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")
          ];
          specialArgs = {
            inherit inputs;
            isFullDesktop = true;
            includeProprietary = true;
            isVirtualBox = false;
          };
        };

        # === VIRTUALBOX IMAGE (build-vbox) ===
        vbox = nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "virtualbox";

          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")

            ({ lib, ... }: {
               boot.loader.grub.device = lib.mkForce "/dev/sda";
               virtualisation.diskSize = 21200;
            })
          ];

          specialArgs = {
            inherit inputs;
            isFullDesktop = true;
            includeProprietary = true;
            isVirtualBox = true;
          };
        };

        # === LIGHT IMAGE (build-light) ===
        light = nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "qcow";

          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")
          ];
          specialArgs = {
            inherit inputs;
            isFullDesktop = false;
            includeProprietary = false;
            isVirtualBox = false;
          };
        };

        # === WITH PACKAGE IMAGE ===
        with-package = nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "qcow";
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")
          ];
          specialArgs = {
            inherit inputs;
            isFullDesktop = false;
            includeProprietary = true;
            isVirtualBox = false;
          };
        };

        # === MINIMAL CONSOLE IMAGE (build-console) ===
        console = nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "qcow";

          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm-console.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")
          ];

          specialArgs = {
            inherit inputs;
            isFullDesktop = false;
            includeProprietary = false;
            isVirtualBox = false;
          };
        };

        # === ISO INSTALLER IMAGE (build-iso) ===
        iso = nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "install-iso";

          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")
          ];
          specialArgs = {
            inherit inputs;
            isFullDesktop = true;
            includeProprietary = true;
            isVirtualBox = false;
          };
        };
      });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          buildInputs = [
            nixpkgs.legacyPackages.${system}.nixos-rebuild
            nixos-generators.packages.${system}.nixos-generate
            colmena.packages.${system}.colmena

            # === MEDIA TOOLS FOR HOST ===
            nixpkgs.legacyPackages.${system}.gst_all_1.gstreamer
            nixpkgs.legacyPackages.${system}.gst_all_1.gst-plugins-base
            nixpkgs.legacyPackages.${system}.gst_all_1.gst-plugins-good
            nixpkgs.legacyPackages.${system}.gst_all_1.gst-plugins-bad
            nixpkgs.legacyPackages.${system}.gst_all_1.gst-plugins-ugly
          ];
        };
      });

      nixosConfigurations = {
        "with-package" = nixpkgs.lib.nixosSystem {
          pkgs = mkPkgs "x86_64-linux";
          specialArgs = {
            inherit inputs;
            isFullDesktop = false;       # ВАЖНО: Отключает тяжелый софт (Zoom, Telegram)
            includeProprietary = true;   # ВАЖНО: Оставляет JasonBourne/DevReady
            isVirtualBox = false;
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "with-package") # Обновляем имя цели для скрипта update
            ({ modulesPath, ... }: {
              imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
                autoResize = true;
              };
            })
          ];
        };

        "nixos-vm" = nixpkgs.lib.nixosSystem {
          pkgs = mkPkgs "x86_64-linux";
          specialArgs = {
            inherit inputs;
            isFullDesktop = true;
            includeProprietary = true;
            isVirtualBox = false;
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")
            ({ modulesPath, ... }: {
              imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
                autoResize = true;
              };
            })
          ];
        };

        "nixos-light" = nixpkgs.lib.nixosSystem {
          pkgs = mkPkgs "x86_64-linux";
          specialArgs = {
            inherit inputs;
            isFullDesktop = false;
            includeProprietary = false;
            isVirtualBox = false;
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")
            ({ modulesPath, ... }: {
              imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
                autoResize = true;
              };
            })
          ];
        };

        "nixos-console" = nixpkgs.lib.nixosSystem {
          pkgs = mkPkgs "x86_64-linux";
          specialArgs = {
            inherit inputs;
            isFullDesktop = false;
            includeProprietary = false;
            isVirtualBox = false;
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm-console.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")
            ({ modulesPath, ... }: {
              imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
                autoResize = true;
              };
            })
          ];
        };

        # === ЦЕЛЕВАЯ КОНФИГУРАЦИЯ ДЛЯ BEGET ===
        "nixos-beget" = nixpkgs.lib.nixosSystem {
          pkgs = mkPkgs "x86_64-linux";
          specialArgs = {
            inherit inputs;
            isFullDesktop = true;
            includeProprietary = true;
            isVirtualBox = false;
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-beget")

            disko.nixosModules.disko
            ./modules/beget-server.nix
          ];
        };
      };
    };
}
