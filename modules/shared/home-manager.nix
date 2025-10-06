{ pkgs, ... }:

let
  name = "Patrick Lerner";
  user = "patrick";
  email = "ptlerner@gmail.com";
in {
  # Shared shell configuration
  zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    autocd = true;

    history = {
      size = 10000;
      ignoreDups = true;
      ignoreSpace = true;
      path = "$HOME/.zsh_history";
      ignorePatterns = [ "pwd" "ls" "cd" "rm *" "g" "git status" ];
    };

    plugins = [
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      }
      {
        name = "zsh-history-substring-search";
        src = pkgs.zsh-history-substring-search;
        file =
          "share/zsh-history-substring-search/zsh-history-substring-search.zsh";
      }
    ];

    shellAliases = {
      # Basic aliases
      de = "cd ~/Desktop";
      ls = "eza";
      ll = "eza -lh";
      cat = "bat";
      bro = "tldr";
      real_nano = "/usr/bin/nano";
      nano = "nvim";
      vim = "nvim";
      nvim = "rbenv shell 3.2.0 && nvim";

      # Directory shortcuts
      "@nix" = "cd ~/nix-config";
      "@workbench" = "cd ~/Workbench";
      "@downloads" = "cd ~/Downloads";
      "@instaffo" = "cd ~/Projects/Instaffo";
      "@app" = "cd ~/Projects/Instaffo/Product/app";
      "@samira" = ''
        cd "/Users/patrick/Library/CloudStorage/GoogleDrive-ptlerner@gmail.com/My Drive/Data Files/Samira"'';
      "@sophie" = ''
        cd "/Users/patrick/Library/CloudStorage/GoogleDrive-ptlerner@gmail.com/My Drive/Data Files/Sophie"'';
      "@bara" = ''
        cd "/Users/patrick/Library/CloudStorage/GoogleDrive-ptlerner@gmail.com/My Drive/Data Files/Bára"'';

      # Transcription aliases
      transcribe_german = "whisper --language German --model small";
      transcribe_persian = "whisper --language Persian --model small";
      transcribe_english = "whisper --language English --model small";

      # Tmuxinator aliases
      instaffo-start = "tmuxinator start instaffo";
      instaffo-stop = "tmuxinator stop instaffo";

      # Git aliases
      gp = "git push";
      gf = "git fetch";
    };

    sessionVariables = {
      EDITOR = "nvim";
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      TERM = "screen-256color";
      GREP_COLORS = "mt=01;34";
      DISABLE_AUTO_TITLE = "true";
      HOMEBREW_NO_ANALYTICS = "1";
    };

    initContent = ''
      # Add SSH key to agent
      /usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_rsa 2>/dev/null

      # Source secrets if they exist
      [[ -f ~/.secrets-env ]] && source ~/.secrets-env

      # Custom git function
      unalias g 2>/dev/null || true
      function g() {
        if [[ $# -gt 0 ]]; then
          git "$@"
        else
          git status
        fi
      }
      compdef g='git'

      # Git prompt function
      function git_prompt_info() {
        local ref
        local full
        local branch_color
        if [[ "$(command git config --get oh-my-zsh.hide-status 2>/dev/null)" != "1" ]]; then
          full=$(command git symbolic-ref HEAD 2> /dev/null) || \
          full=$(command git rev-parse --short HEAD 2> /dev/null) || return 0
          ref=$(echo $full | cut -c 1-35)
          if [[ "$ref" != "$full" ]]; then
            ref="''${ref}…"
          fi

          # Check if repo is dirty and set branch color
          local STATUS
          local -a FLAGS
          FLAGS=('--porcelain')
          if [[ "$DISABLE_UNTRACKED_FILES_DIRTY" == "true" ]]; then
            FLAGS+='--untracked-files=no'
          fi
          STATUS=$(command git status ''${FLAGS} 2> /dev/null | tail -1)
          if [[ -n $STATUS ]]; then
            branch_color="%F{yellow}"
          else
            branch_color="%F{green}"
          fi

          echo "%F{magenta}($branch_color''${ref#refs/heads/}%F{magenta})%F{blue} "
        fi
      }

      # Source shrink-path plugin for fish-style paths
      source ~/.config/zsh/shrink-path.zsh

      # Enable prompt substitution and set custom prompt (Gentoo-style)
      setopt PROMPT_SUBST
      export PROMPT='%(!.%B%F{red}.%B%F{green}%n@)%m %F{blue}$(shrink_path -f) $(git_prompt_info)%F{blue}%(!.#.$)%k%b%f '

      # History substring search key bindings
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      bindkey -M vicmd 'k' history-substring-search-up
      bindkey -M vicmd 'j' history-substring-search-down

      # Shift+Tab for reverse menu completion
      bindkey '^[[Z' reverse-menu-complete

      # Disable history substring search highlighting
      unset HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
      unset HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND

      # Path modifications
      export PATH=~/.bin:$PATH:/usr/local/bin
      export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
      export PATH="/usr/local/sbin:$PATH"
      export PATH="$HOME/.cargo/bin:$PATH"

      # Load version managers
      eval "$(rbenv init -)" 2>/dev/null || true

      # Set GPG_TTY for GPG signing
      export GPG_TTY=$(tty)

      # Load Nix profiles
      if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      # Add Homebrew completions to fpath and fix broken symlinks
      if [[ -d /opt/homebrew/share/zsh/site-functions ]]; then
        # Remove broken brew completion symlink if it exists
        if [[ -L /opt/homebrew/share/zsh/site-functions/_brew && ! -f /opt/homebrew/share/zsh/site-functions/_brew ]]; then
          rm -f /opt/homebrew/share/zsh/site-functions/_brew
        fi

        # Re-link homebrew completions if brew is available
        if command -v brew >/dev/null 2>&1; then
          brew completions link >/dev/null 2>&1 || true
        fi

        fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
      fi

      # Enable fuzzy completion matching
      setopt COMPLETE_IN_WORD
      setopt LIST_AMBIGUOUS

      # Configure completion matching (simple case insensitive)
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

      # Fix completion menu colors and prevent background color bleeding
      zstyle ':completion:*' menu select
      zstyle ':completion:*' list-colors ""

      # Reset terminal colors to prevent autosuggestion color bleeding
      export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
      export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

      # Clear autosuggestion when command is accepted
      export ZSH_AUTOSUGGEST_CLEAR_WIDGETS=(
        history-search-forward
        history-search-backward
        history-beginning-search-forward
        history-beginning-search-backward
        history-substring-search-up
        history-substring-search-down
        up-line-or-beginning-search
        down-line-or-beginning-search
        accept-line
        copy-earlier-word
      )

    '';
  };

  git = {
    enable = true;
    ignores = [ "*.swp" ];
    userName = name;
    userEmail = email;
    lfs = { enable = true; };
    extraConfig = {
      init.defaultBranch = "main";
      core = {
        editor = "vim";
        autocrlf = "input";
      };
      commit.gpgsign = false;
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };

  ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "/Users/${user}/.ssh/config_external" ];
    matchBlocks = {
      "*" = {
        # Set the default values we want to keep
        sendEnv = [ "LANG" "LC_*" ];
        hashKnownHosts = true;
      };
      "github.com" = {
        identitiesOnly = true;
        identityFile = [ "/Users/${user}/.ssh/id_ed25519" ];
      };
    };
  };

  tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      prefix-highlight
      {
        plugin = nord;
        extraConfig = ''
          # Nord theme configuration
        '';
      }
      {
        plugin = resurrect; # Used by tmux-continuum

        # Use XDG data directory
        # https://github.com/tmux-plugins/tmux-resurrect/issues/348
        extraConfig = ''
          set -g @resurrect-dir '$HOME/.cache/tmux/resurrect'
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-pane-contents-area 'visible'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5' # minutes
        '';
      }
    ];
    terminal = "screen-256color";
    prefix = "C-a";
    escapeTime = 10;
    historyLimit = 50000;
    baseIndex = 1;
    extraConfig = ''
      # Status bar on top like old config
      set -g status-position top

      # Start pane index at 1 (matches baseIndex = 1)
      setw -g pane-base-index 1

      # Highlight window when it has new activity
      setw -g monitor-activity on

      # Re-number windows when one is closed
      set -g renumber-windows on

      # Visual activity/bell settings (quiet mode like old config)
      set-option -g visual-activity off
      set-option -g visual-bell off
      set-option -g visual-silence off
      set-window-option -g monitor-activity off
      set-option -g bell-action none

      # Terminal overrides for proper colors and key support
      set -g default-terminal "screen-256color"
      set-option -ga terminal-overrides ",alacritty:RGB"
      set-option -ga terminal-overrides ",screen-256color:Tc"

      # Enable extended keys for proper Shift+Enter and other key combos
      set -s extended-keys on
      set -as terminal-features 'xterm*:extkeys'
      set-option -ga terminal-overrides ",xterm*:kEND=\E[1;2F,kHOM=\E[1;2H"

      # Allow tmux to pass through escape sequences for shift/ctrl modifiers
      set-window-option -g xterm-keys on

      # Ensure proper shell initialization with Nix zsh
      set-option -g default-command "/Users/patrick/.nix-profile/bin/zsh"

      # Remove Vim mode delays
      set -g focus-events on

      # Mouse configuration (start with mouse off, but allow toggle like old config)
      set -g mouse off

      # Mouse wheel scrolling (from old config)
      bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
      bind -n WheelDownPane select-pane -t= \; send-keys -M

      # Toggle mouse mode (from old config)
      bind m \
          set -g mouse on \;\
          display 'Mouse: ON'
      bind M \
          set -g mouse off \;\
          display 'Mouse: OFF'

      # Force reload of config file (from old config)
      unbind r
      bind r source-file ~/.tmux.conf \; display "Reloaded!"

      # -----------------------------------------------------------------------------
      # Key bindings
      # -----------------------------------------------------------------------------

      # Unbind default keys
      unbind C-b
      unbind '"'
      unbind %

      # Direct window switching with Ctrl + number (from old config)
      bind-key -n C-1 select-window -t :1
      bind-key -n C-2 select-window -t :2
      bind-key -n C-3 select-window -t :3
      bind-key -n C-4 select-window -t :4
      bind-key -n C-5 select-window -t :5
      bind-key -n C-6 select-window -t :6
      bind-key -n C-7 select-window -t :7
      bind-key -n C-8 select-window -t :8
      bind-key -n C-9 select-window -t :9
      bind-key -n C-0 select-window -t :10

      # Window swapping (from old config)
      bind-key -n C-S-Left swap-window -t -1\; select-window -t -1
      bind-key -n C-S-Right swap-window -t +1\; select-window -t +1

      # Split panes, vertical or horizontal
      bind-key x split-window -v
      bind-key v split-window -h

      # Move around panes with vim-like bindings (h,j,k,l)
      bind-key -n M-k select-pane -U
      bind-key -n M-h select-pane -L
      bind-key -n M-j select-pane -D
      bind-key -n M-l select-pane -R
    '';
  };
}
