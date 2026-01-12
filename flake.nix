{
  description = "NixOS QEMU images (Proprietary/Binary Build)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-generators, ... }@inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      mkPkgsUnstable = system: import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      binaryCacheConfig = {
        nix.settings = {
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

    in
    {
      packages = forAllSystems (system: let
        pkgs = mkPkgs system;
        pkgs-unstable = mkPkgsUnstable system;
      in {
        # === FULL DESKTOP IMAGE (build) ===
        default = nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "qcow";

          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
          ];

          # isFullDesktop = true (Heavy apps)
          # includeProprietary = true (JasonBourne/Mutter)
          specialArgs = {
            inherit inputs pkgs-unstable;
            isFullDesktop = true;
            includeProprietary = true;
          };
        };

        # === LIGHT IMAGE (build-light) ===
        # Использует vm.nix, но все флаги выключены
        light = nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "qcow";

          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
          ];

          # isFullDesktop = false
          # includeProprietary = false
          specialArgs = {
            inherit inputs pkgs-unstable;
            isFullDesktop = false;
            includeProprietary = false;
          };
        };

        # === WITH PACKAGE IMAGE (New) ===
        # Основан на Light (без тяжелых приложений), но с proprietary.nix и jasonbourne
        with-package = nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "qcow";

          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
          ];

          # isFullDesktop = false (No heavy apps)
          # includeProprietary = true (Yes JasonBourne)
          specialArgs = {
            inherit inputs pkgs-unstable;
            isFullDesktop = false;
            includeProprietary = true;
          };
        };

        # === MINIMAL CONSOLE IMAGE (build-console) ===
        # Использует vm-console.nix
        console = nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "qcow";

          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm-console.nix
            binaryCacheConfig
          ];

          specialArgs = {
            inherit inputs pkgs-unstable;
            isFullDesktop = false;
            includeProprietary = false;
          };
        };
      });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          buildInputs = [
            nixpkgs.legacyPackages.${system}.nixos-rebuild
            nixos-generators.packages.${system}.nixos-generate
          ];
        };
      });

      nixosConfigurations = {
        "nixos-vm" = nixpkgs.lib.nixosSystem {
          pkgs = mkPkgs "x86_64-linux";
          specialArgs = {
            inherit inputs;
            pkgs-unstable = mkPkgsUnstable "x86_64-linux";
            isFullDesktop = true;
            includeProprietary = true;
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            ({ modulesPath, ... }: {
              imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
              # boot.loader.grub removed here to use systemd-boot from system.nix
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
            pkgs-unstable = mkPkgsUnstable "x86_64-linux";
            isFullDesktop = false;
            includeProprietary = false;
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm-console.nix
            binaryCacheConfig
            ({ modulesPath, ... }: {
              imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
              # boot.loader.grub removed here to use systemd-boot from system.nix
              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
                autoResize = true;
              };
            })
          ];
        };
      };
    };
}
