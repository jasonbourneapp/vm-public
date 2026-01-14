{
  description = "NixOS QEMU images (Proprietary/Binary Build)";

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
  };

  outputs = { self, nixpkgs, nixos-generators, ... }@inputs:
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
      # Генерирует скрипт update, который подтягивает конфиг из git
      # и пересобирает систему.
      mkUpdateModule = targetFlake: ({ pkgs, ... }: {

        # РЕШЕНИЕ ПРОБЛЕМЫ "dubious ownership":
        programs.git = {
          enable = true;
          config.safe.directory = [ "/etc/nixos" ];
        };

        environment.systemPackages = [
          pkgs.git
          (pkgs.writeShellScriptBin "update" ''
            set -e

            # === ПРОВЕРКА ПРАВ ROOT ===
            # Используем id -u, так как это работает в любой оболочке (sh/bash/zsh)
            if [ "$(id -u)" -ne 0 ]; then
               echo "----------------------------------------------------------------"
               echo "ОШИБКА: У вас нет прав для выполнения обновления!"
               echo "Пожалуйста, запустите эту команду через sudo:"
               echo ""
               echo "    sudo update"
               echo "----------------------------------------------------------------"
               exit 1
            fi

            REPO="https://github.com/jasonbourneapp/vm-public.git"
            DIR="/etc/nixos"
            TIMESTAMP=$(date +%Y%m%d-%H%M%S)
            BACKUP_DIR="/etc/nixos-$TIMESTAMP"

            echo "======================================================="
            echo ">>> JasonBourne VM Update Tool"
            echo ">>> Цель: ${targetFlake}"
            echo "======================================================="

            mkdir -p "$DIR"
            cd "$DIR"

            # Разрешаем git в текущей сессии
            ${pkgs.git}/bin/git config --global --add safe.directory "$DIR" || true

            # 1. Проверка Git и создание бэкапов
            if [ ! -d ".git" ]; then
              # Если папка не пуста и не git — делаем бэкап
              if [ "$(ls -A "$DIR")" ]; then
                 echo ">>> Папка содержит файлы, но не является git-репозиторием."
                 echo ">>> Создание бэкапа в $BACKUP_DIR..."
                 cp -r "$DIR" "$BACKUP_DIR"
              fi

              echo ">>> Инициализация из $REPO (Shallow clone)..."
              ${pkgs.git}/bin/git init
              ${pkgs.git}/bin/git remote add origin "$REPO"
              # --depth 1 берет только последний коммит
              ${pkgs.git}/bin/git fetch --depth 1 origin master
              ${pkgs.git}/bin/git reset --hard origin/master

            else
              echo ">>> Скачивание изменений (Shallow fetch)..."
              # --depth 1 берет только последний коммит
              ${pkgs.git}/bin/git fetch --depth 1 origin master

              # Если есть локальные изменения — делаем бэкап перед сбросом
              if [ -n "$(${pkgs.git}/bin/git status --porcelain)" ]; then
                 echo ">>> Обнаружены локальные изменения."
                 echo ">>> Создание бэкапа в $BACKUP_DIR..."
                 cp -r "$DIR" "$BACKUP_DIR"
              fi

              ${pkgs.git}/bin/git reset --hard origin/master
            fi

            # 2. Загрузка переменных окружения с явным экспортом
            if [ -f ".env" ]; then
              echo ">>> Загрузка конфигурации из .env..."
              # Экспортируем все переменные из .env
              export $(grep -v '^#' .env | xargs)
            fi

            # 3. Пересборка системы
            echo ">>> Запуск пересборки системы (NixOS Rebuild)..."
            # Используем --impure для доступа к переменным и --show-trace для деталей ошибок
            nixos-rebuild switch --flake .#${targetFlake} --impure --show-trace

            echo "======================================================="
            echo ">>> Обновление успешно завершено!"
            echo ">>> Для применения изменений ядра или драйверов перезагрузитесь:"
            echo ">>> sudo reboot"
            echo "======================================================="
          '')
        ];
      });

      formatQcowCompressed = { config, lib, pkgs, modulesPath, ... }: {
        imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

        # Указываем генератору, какой атрибут забирать как результат
        formatAttr = "qcow-compressed";

        # === ВОТ ЭТОГО НЕ ХВАТАЛО ===
        # Мы должны сообщить конфигурации NixOS, где будет ее корень.
        # make-disk-image.nix создаст раздел с меткой "nixos", поэтому мы ссылаемся на него.
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
          autoResize = true;
        };

        # Сама сборка образа
        system.build.qcow-compressed = import (modulesPath + "/../lib/make-disk-image.nix") {
          inherit lib config pkgs;
          format = "qcow2-compressed";
          # diskSize = "auto"; # Можно раскомментировать, если нужно авто-расширение под контент
        };
      };

    in
    {
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

          # isFullDesktop = true (Heavy apps)
          # includeProprietary = true (JasonBourne/Mutter)
          specialArgs = {
            inherit inputs;
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
            (mkUpdateModule "nixos-light")
          ];

          # isFullDesktop = false
          # includeProprietary = false
          specialArgs = {
            inherit inputs;
            isFullDesktop = false;
            includeProprietary = false;
          };
        };

        # === WITH PACKAGE IMAGE (New) ===
        # Основан на Light (без тяжелых приложений), но с proprietary.nix и jasonbourne
        with-package = nixos-generators.nixosGenerate {
          inherit pkgs;

          format = "qcow";
          # format = "qcow-compressed";
          # customFormats = {
          #   "qcow-compressed" = formatQcowCompressed;
          # };

          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")
          ];

          # isFullDesktop = false (No heavy apps)
          # includeProprietary = true (Yes JasonBourne)
          specialArgs = {
            inherit inputs;
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
            (mkUpdateModule "nixos-console")
          ];

          specialArgs = {
            inherit inputs;
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
            isFullDesktop = true;
            includeProprietary = true;
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-vm")
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

        "nixos-light" = nixpkgs.lib.nixosSystem {
          pkgs = mkPkgs "x86_64-linux";
          specialArgs = {
            inherit inputs;
            isFullDesktop = false;
            includeProprietary = false;
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-light")
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
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./vm-console.nix
            binaryCacheConfig
            (mkUpdateModule "nixos-console")
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
