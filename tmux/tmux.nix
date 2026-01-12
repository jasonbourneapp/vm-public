{ pkgs, ... }:
let
  # Nix автоматически добавит этот файл в /nix/store/HASH-tmux.remote.conf
  # и присвоит переменной remoteConf путь к нему.
  remoteConf = ./tmux.remote.conf;
in
{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    aggressiveResize = false;
    historyLimit = 100000;
    resizeAmount = 5;
    escapeTime = 0;
    secureSocket = false;
    clock24 = true;
    baseIndex = 1;
    prefix = "C-a";
    sensibleOnTop = true;
    # shell = "${pkgs.zsh}/bin/zsh";
    shell = "${pkgs.fish}/bin/fish";
    terminal = "screen-256color";
    plugins = with pkgs; [
      tmuxPlugins.copycat
      tmuxPlugins.sensible
      tmuxPlugins.yank
      tmuxPlugins.vim-tmux-navigator
      tmuxPlugins.onedark-theme
    ];
    extraConfig = ''
      set -g mouse on
      unbind -n MouseDrag1Pane
      bind -n MouseDrag1Pane if -F '#{mouse_any_flag}' 'if -F "#{pane_in_mode}" "copy-mode -M" "send-keys -M"' 'copy-mode -M'

      # Split windows (работает с обеими раскладками по умолчанию)
      bind '"' split-window -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Vim-style копирование (работает независимо от раскладки в режиме vi)
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      bind -T copy-mode-vi r send-keys -X rectangle-toggle

      # Last window (работает с обеими раскладками)
      bind a last-window
      bind ф last-window

      # Unbind navigation keys
      unbind C-l
      unbind -T root C-l
      unbind -T copy-mode-vi C-l

      # SSH check
      # Используем путь из Nix Store, который работает для любого пользователя
      if-shell 'test -n "$SSH_CLIENT"' \
        'source-file ${remoteConf}'

      # Toggle prefix key and status bar (латинские буквы)
      bind -T root M-m \
        set prefix None \;\
        set key-table off \;\
        set status-style "fg=#5c6370,bg=#282c34" \;\
        set window-status-current-format "#[fg=#282c34,bg=#5c6370]#[default] #I:#W# #[fg=#5c6370,bg=#282c34]#[default]" \;\
        set window-status-current-style "fg=#282c34,bold,bg=#5c6370" \;\
        if -F '#{pane_in_mode}' 'send-keys -X cancel' \;\
        refresh-client -S

      # Toggle prefix key and status bar (русские буквы)
      bind -T root 'M-ь' \
        set prefix None \;\
        set key-table off \;\
        set status-style "fg=#5c6370,bg=#282c34" \;\
        set window-status-current-format "#[fg=#282c34,bg=#5c6370]#[default] #I:#W# #[fg=#5c6370,bg=#282c34]#[default]" \;\
        set window-status-current-style "fg=#282c34,bold,bg=#5c6370" \;\
        if -F '#{pane_in_mode}' 'send-keys -X cancel' \;\
        refresh-client -S

      # Restore prefix key and status bar (латинские буквы)
      bind -T off M-m \
        set -u prefix \;\
        set -u key-table \;\
        set -u status-style \;\
        set -u window-status-current-style \;\
        set -u window-status-current-format \;\
        refresh-client -S

      # Restore prefix key and status bar (русские буквы)
      bind -T off 'M-ь' \
        set -u prefix \;\
        set -u key-table \;\
        set -u status-style \;\
        set -u window-status-current-style \;\
        set -u window-status-current-format \;\
        refresh-client -S

      # Unbind keys that we're redefining
      unbind -n S-Space
      unbind M-m
      unbind 'M-ь'

      # Навигация между панелями (латинские буквы)
      bind -n M-h select-pane -L
      bind -n M-j select-pane -D
      bind -n M-k select-pane -U
      bind -n M-l select-pane -R

      # Навигация между панелями (русские буквы)
      bind -n M-р select-pane -L
      bind -n M-о select-pane -D
      bind -n M-л select-pane -U
      bind -n M-д select-pane -R

      # Изменение размера панелей (латинские буквы)
      bind -n M-H resize-pane -L 5
      bind -n M-J resize-pane -D 5
      bind -n M-K resize-pane -U 5
      bind -n M-L resize-pane -R 5

      # Изменение размера панелей (русские буквы)
      bind -n M-Р resize-pane -L 5
      bind -n M-О resize-pane -D 5
      bind -n M-Л resize-pane -U 5
      bind -n M-Д resize-pane -R 5
    '';
  };
}
