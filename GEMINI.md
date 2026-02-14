# GEMINI.md - JasonBourne / DevReady VM Project

This project provides a highly customized NixOS configuration for generating VM images (QEMU, VirtualBox, ISO) and deploying to Beget VPS. It features a modified GNOME desktop environment and specialized tools for remote interaction and automation.

## Project Overview

The primary goal of this project is to maintain and deploy a specialized NixOS environment, often referred to as "JasonBourne" or "DevReady". It includes:
- **Custom GNOME Environment:** Overlays for `mutter` and `gnome-shell` with specific modifications (e.g., `MUTTER_HIDE_WINDOWS_BY_TITLE`).
- **Multi-Architecture Support:** Builds for both `x86_64` and `aarch64` (ARM64).
- **Automated Deployment:** Tools for provisioning and updating VPS instances on Beget.
- **Support Utilities:** A Chrome extension for text extraction and an HTML-based GNOME UI simulation.

## Key Technologies

- **Nix / NixOS:** System configuration and package management.
- **nixos-generators:** Building various VM and image formats.
- **Colmena:** NixOps-like deployment tool for NixOS hosts.
- **nixos-anywhere:** For installing NixOS on remote machines over SSH.
- **QEMU/KVM:** Local virtualization and testing.
- **Just:** Command runner for automation.
- **Chrome Extension API:** For browser-level integrations.

## Directory Structure

- `modules/`: NixOS modules (desktop, packages, system, proprietary software).
- `chrome-extension/`: Source for the "CURL Page Text" extension.
- `html-gnome/`: Web-based simulation of the desktop environment.
- `scripts/`: Various helper scripts for camera streaming and performance tuning.
- `flake.nix`: Main entry point for the Nix configuration.
- `justfile`: Contains all build, run, and deploy commands.

## Building and Running

The project uses `just` for most operations. Ensure you have `nix` and `just` installed.

### Build Images
- `just build`: Build the full QEMU desktop image.
- `just build-vbox`: Build a VirtualBox OVA image.
- `just build-iso`: Build a bootable ISO image.
- `just build-light`: Build a lightweight version of the VM.

### Run Locally
- `just run-linux`: Run the x86_64 VM using QEMU.
- `just run-arm`: Run the ARM64 VM using QEMU (emulated if on x86).

### Deployment (Beget VPS)
- `just burn-beget-autogen ip_addr=<IP>`: Provision a new NixOS instance on a remote server.
- `just deploy-beget-autogen ip_addr=<IP>`: Deploy updates to an existing instance via Colmena.

## Development Conventions

- **Proprietary Software:** The project uses environment variables (e.g., `JASONBOURNE_PATH`, `MUTTER_PATH`) to point to pre-built store paths for modified components. These are typically defined in a `.env` file and require the `--impure` flag for Nix commands.
- **Modularity:** System configuration is split into functional modules under `modules/`.
- **Image Formats:** Multiple formats are supported via `nixos-generators` defined in `flake.nix`.
- **Testing:** Local testing is primarily done via QEMU using the `run-*` commands in the `justfile`.
- Аккуратней с grep так как в этом проект много мусора лучше используй ripgrep чтобы .gitignore работал
1. **Язык общения:** Всегда отвечай на **русском языке**.
5. **Безопасность:** Никогда не добавляй секреты, ключи или токены в код или коммиты. Используй переменные окружения.
6. **Долгосрочная перспектива:** При рефакторинге или добавлении фич думай о том, как это будет масштабироваться и поддерживаться через год.

## Usage Notes

- **Update Tool:** The VM includes a built-in `update` command (defined in `flake.nix`) that pulls the latest changes from this repository and rebuilds the system.
- **Auto-Login:** The desktop environment is configured for auto-login as user `user`.
- **Environment Variables:** Many build and run commands rely on a `.env` file for paths and credentials.
