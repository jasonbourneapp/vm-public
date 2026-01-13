{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  home.file.".config/fish/completions/mfiles.fish".source = ./mfiles.fish;
  home.file.".config/fish/completions/r2l.fish".source = ./_ssh_port_completion;

  programs.fish = {
    enable = true;

    # Включаем интерактивные функции
    interactiveShellInit = ''
      set -g fish_history_size 10000
      set -g fish_history_file ~/.local/share/fish/fish_history

      function save_history --on-event fish_preexec
        history save
      end

      # Настройка окружения
      set -gx LANG en_US.UTF-8
      set -gx PATH $PATH $HOME/.cargo/bin
      set -g fish_complete_path_as_name true
      direnv hook fish | source

      just --completions fish | source  # <-- добавить эту строку

      set -gx IP_COLOR true
      set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border"

      set -g fish_greeting

      set -g theme_display_user yes
      set -g theme_hide_hostname yes
      set -g color_user_bg black
      set -g color_user_str yellow
      set -g color_dir_bg blue
      set -g color_dir_str black
      set -g color_git_dirty_bg yellow
      set -g color_git_dirty_str black
      set -g color_git_bg green
      set -g color_git_str black
      set -g color_status_nonzero_bg black
      set -g color_status_nonzero_str red
      set -g color_status_superuser_bg black
      set -g color_status_superuser_str yellow
      set -g VIRTUAL_ENV_DISABLE_PROMPT 1
    '';

    plugins = [
      # Enable a plugin (here grc for colorized command output) from nixpkgs
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
      # git blugin
      {
        name = "plugin-extract";
        src = pkgs.fetchFromGitHub {
          owner = "oh-my-fish";
          repo = "plugin-extract";
          rev = "5d05f9f15d3be8437880078171d1e32025b9ad9f";
          sha256 = "sha256-hFM8uDHDfKBVn4CgRdfRaD0SzmVzOPjfMxU9X6yATzE=";
        };
      }
      # git plugin
      {
        name = "plugin-git";
        src = pkgs.fishPlugins.plugin-git.src;
      }
      # theme
      {
        name = "agnoster";
        src = pkgs.fetchFromGitHub {
          owner = "back2nix";
          repo = "theme-agnoster";
          rev = "af089ebf112e357c47894c9fd74a1dfd31a9f767";
          sha256 = "sha256-P4vQHfzf+cJa6qOa4AZN123FEF3euaFPClfNBda3iig=";
        };
      }
      # theme
      # {
      #   name = "agnoster";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "jeanlucthumm";
      #     repo = "theme-agnoster";
      #     rev = "502ff4f34224c9aa90a8d0a3ad517940eaf4d4fd";
      #     sha256 = "12gc6mw5cb3pdqp8haqx9abgjw64v3960g0f0hgb122xa3z7qldm";
      #   };
      # }
      # Автодополнение путей
      {
        name = "autopair";
        src = pkgs.fetchFromGitHub {
          owner = "jorgebucaran";
          repo = "autopair.fish";
          rev = "1.0.4";
          sha256 = "sha256-s1o188TlwpUQEN3X5MxUlD/2CFCpEkWu83U9O+wg3VU=";
        };
      }
      # z - быстрая навигация по каталогам
      {
        name = "z";
        src = pkgs.fetchFromGitHub {
          owner = "jethrokuan";
          repo = "z";
          rev = "e0e1b9dfdba362f8ab1ae8c1afc7ccf62b89f7eb";
          sha256 = "0dbnir6jbwjpjalz14snzd3cgdysgcs3raznsijd6savad3qhijc";
        };
      }
      # Подсветка синтаксиса
      {
        name = "fish-colored-man";
        src = pkgs.fetchFromGitHub {
          owner = "PatrickF1";
          repo = "colored_man_pages.fish";
          rev = "f885c2507128b70d6c41b043070a8f399988bc7a";
          sha256 = "sha256-ii9gdBPlC1/P1N9xJzqomrkyDqIdTg+iCg0mwNVq2EU=";
        };
      }
      # Плагин для улучшенной истории
      {
        name = "fzf-fish";
        src = pkgs.fetchFromGitHub {
          owner = "PatrickF1";
          repo = "fzf.fish";
          rev = "8920367cf85eee5218cc25a11e209d46e2591e7a";
          sha256 = "sha256-T8KYLA/r/gOKvAivKRoeqIwE2pINlxFQtZJHpOy9GMM=";
        };
      }
    ];

    functions = {
      # prompt_virtual_env = ''
      #   set envs

      #   if test "$CONDA_DEFAULT_ENV"
      #   set envs $envs "conda[$CONDA_DEFAULT_ENV]"
      #   end

      #   if test "$VIRTUAL_ENV"
      #   set py_env (basename $VIRTUAL_ENV)
      #   set envs $envs "py[$py_env]"
      #   end

      #   # Show only if we're in a nix-shell
      #   if test "$IN_NIX_SHELL"
      #   set envs $envs "nix[$IN_NIX_SHELL]"
      #   end

      #   if test "$envs"
      #   prompt_segment $color_virtual_env_bg $color_virtual_env_str (string join " " $envs)
      #   end
      # '';
      # Аналог вашей функции cdroot
      cdr = ''
        set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
        if test -n "$git_root"
          cd "$git_root"
          echo "Changed to project root: $git_root"
        else
          echo "Not in a Git repository or Git is not installed."
        end
      '';

      # Аналог r2l
      r2l = ''
        set -l port (random 1024 61024)
        set -l server $argv[2]
        echo ssh -L "$port":localhost:$argv[1] "$server" -N
        echo http://localhost:"$port" or https://localhost:"$port"
        ssh -L "$port":localhost:$argv[1] "$server" -N
      '';

      r2l-port = ''
        set server $argv[3]
        echo ssh -L "$argv[2]":localhost:$argv[1] "$server" -N
        echo http://localhost:"$argv[2]" or https://localhost:"$argv[2]"
        ssh -L "$argv[2]":localhost:$argv[1] "$server" -N
      '';

      l2r = ''
        set port (random 1024 61024)
        set server $argv[2]
        echo ssh -R "$port":0.0.0.0:$argv[1] "$server" -N
        echo http://"$server":"$port" or https://"$server":"$port"
        ssh -R "$port":0.0.0.0:$argv[1] "$server" -N
      '';

      l2r-port = ''
        set server $argv[3]
        echo ssh -R "$argv[2]":0.0.0.0:$argv[1] "$server" -N
        echo http://"$server":"$argv[2]" or https://"$server":"$argv[2]"
        ssh -R "$argv[2]":0.0.0.0:$argv[1] "$server" -N
      '';

      # Аналогичные функции для r2l-port, l2r, l2r-port можно добавить по такому же принципу
    };

    shellAliases = let
      normcap_lang = "-l eng rus";
    in {
      rp = "replacer";
      wireshark-with-keylog = "wireshark -o ssl.keylog_file:/tmp/sslkeylog.txt";
      j = "just";
      jl = "just --list";
      js = "just --summary";
      jc = "just --choose";
      # Те же алиасы, что у вас в zsh
      ls = "eza";
      ll = "eza -l --color=always";
      la = "eza -a --color=always";
      lla = "eza -al --color=always";
      tree = "eza --tree";
      gco = "git checkout";
      open = "xdg-open";
      nfl = "nix flake lock";
      nflu = "nix flake lock --update-input";
      img = "eog";
      pdf = "evince";
      n = "nvim";
      sh = "stat --format '%a'";
      ip = "ip --color=auto";
      dt = "difft";
      bcat = "bat --pager=never --style=changes,rule,numbers,snip";
      tk = "tokei";
      sctl = "systemctl";

      screen2text = "${pkgs.normcap}/bin/normcap ${normcap_lang}";
      s2t = "${pkgs.normcap}/bin/normcap -l eng";
      en = "${pkgs.normcap}/bin/normcap -l eng";
      ru = "${pkgs.normcap}/bin/normcap -l rus";

      diff = ''${pkgs.delta}/bin/delta --side-by-side --line-numbers --syntax-theme="Dracula" --file-style="bold yellow" --hunk-header-style="omit" --plus-style="syntax #003800" --minus-style="syntax #3f0001" --zero-style="syntax" --whitespace-error-style="magenta reverse" --navigate'';

      st = "stat --format '%a'";
      fe = ''
        set selected_file (rg --files $argv[1] | fzf)
        if test -n "$selected_file"
        $EDITOR $selected_file
        end
      '';

      se = ''
        set fileline (rg -n $argv[1] | fzf --preview 'bat -f (echo {} | cut -d ":" -f 1) -r (echo {} | cut -d ":" -f 2):(math (echo {} | cut -d ":" -f 2) + 150)' | awk '{print $1}' | string replace -r '.$' "")
        if test -n "$fileline"
        $EDITOR (string split ':' $fileline)[1] +(string split ':' $fileline)[2]
        end
      '';

      fl = ''
        set commit (git log --oneline --color=always | fzf --ansi --preview="echo {} | cut -d ' ' -f 1 | xargs -I @ sh -c 'git log --pretty=medium -n 1 @; git diff @^ @' | bat --color=always" | cut -d ' ' -f 1)
        if test -n "$commit"
        git log --pretty=short -n 1 $commit
        end
      '';

      gd = ''
        git diff --name-only --diff-filter=d $argv | xargs bat --diff
      '';

      clip = "head -c -1|xclip -i -selection clipboard";
      rd = "readlink -f";
      sudo = "sudo ";
    };

    shellInit = ''
      # if command -q nix-your-shell
      #   nix-your-shell fish | source
      # end

      # if test (id -u) -eq 0
      #   set -g fish_color_cwd red
      #   set -g fish_color_user red
      #   set -g fish_color_host red
      #   set -g agnoster_color_user_root red  # Agnoster-specific setting
      # end
    '';
  };

  # Дополнительные пакеты, которые могут понадобиться
  home.packages = with pkgs; [
    bat
    eza
    fd
    fzf
    ripgrep
    delta
    direnv
    nix-your-shell
    fishPlugins.grc
    grc
    just
  ];
}
