{ pkgs, ... }:

let
  name = "Patrick Lerner";
  user = "patrick";
  email = "ptlerner@gmail.com";
  sdModel = pkgs.fetchurl {
    name = "sd15.safetensors";
    url = "https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors";
    hash = "sha256-6UdqE3KM112Cefbsi611OmahlXyjdaFGTcY7N9tuORY=";
  };
  # FLUX.1-schnell (Apache-2.0, ungated) for photorealistic generation via sd-cli.
  # Run `build` once with fakeHash placeholders; nix prints the real hashes to paste back.
  fluxModel = pkgs.fetchurl {
    name = "flux1-schnell-Q8_0.gguf";
    url = "https://huggingface.co/city96/FLUX.1-schnell-gguf/resolve/main/flux1-schnell-Q8_0.gguf";
    hash = "sha256-9mlJQRk7EBSNvx8PSY1MzT6YdcEn/FOUYhO2hYDGbxA=";
  };
  # Names match the URL basenames so the `nix store prefetch-file` paths are reused
  # (mismatched names would re-download at build time).
  # black-forest-labs/FLUX.1-schnell is gated (401 anon); second-state mirrors the
  # identical VAE ungated, so fetchurl can pull it without a token.
  fluxVae = pkgs.fetchurl {
    name = "ae.safetensors";
    url = "https://huggingface.co/second-state/FLUX.1-schnell-GGUF/resolve/main/ae.safetensors";
    hash = "sha256-r8jignLNFds5GbrNtpGM6cHtIulssSxNXtD7qCNSnjg=";
  };
  fluxClipL = pkgs.fetchurl {
    name = "clip_l.safetensors";
    url = "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors";
    hash = "sha256-ZgxvWxq66dxJisLSHhNH0qvbDPbAwMhXbNeWSR2abN0=";
  };
  fluxT5 = pkgs.fetchurl {
    name = "t5xxl_fp16.safetensors";
    url = "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors";
    hash = "sha256-bkgLCfrgSactKoxfvMuNPpL+vrIzu+nf5yVpWKkWdjU=";
  };
in
{
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
      ignorePatterns = [
        "pwd"
        "ls"
        "cd"
        "rm *"
        "g"
        "git status"
      ];
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
        file = "share/zsh-history-substring-search/zsh-history-substring-search.zsh";
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

      # Directory shortcuts
      "@nix" = "cd ~/nix-config";
      "@workbench" = "cd ~/Workbench";
      "@downloads" = "cd ~/Downloads";
      "@instaffo" = "cd ~/Projects/Instaffo";
      "@app" = "cd ~/Projects/Instaffo/app";
      "@claude-orchestrator" = "cd ~/Projects/Instaffo/claude-orchestrator";
      "@instaffo-skills" = "cd ~/Projects/Instaffo/instaffo-skills";
      "@samira" =
        ''cd "/Users/patrick/Library/CloudStorage/GoogleDrive-ptlerner@gmail.com/My Drive/Data Files/Samira"'';
      "@sophie" =
        ''cd "/Users/patrick/Library/CloudStorage/GoogleDrive-ptlerner@gmail.com/My Drive/Data Files/Sophie"'';
      "@bara" =
        ''cd "/Users/patrick/Library/CloudStorage/GoogleDrive-ptlerner@gmail.com/My Drive/Data Files/Bára"'';
      "@notes" = "cd ~/Notes";

      # Transcription aliases
      transcribe = "whisper --fp16 False --output_format txt --output_dir /tmp";
      transcribe_german = "transcribe --language German --model base";
      transcribe_german_slow = "transcribe --language German --model small";
      transcribe_persian = "transcribe --language Persian --model base";
      transcribe_persian_slow = "transcribe --language Persian --model small";
      transcribe_english = "transcribe --language English --model base";
      transcribe_english_slow = "transcribe --language English --model small";

      # Google Workspace CLI (gws) per-account wrappers. gws reads its whole
      # config (client_secret.json, credentials.enc, token_cache.json) from
      # one dir. Point each account at its own dir via GOOGLE_WORKSPACE_CLI_CONFIG_DIR
      # -> fully isolated, no shared state, safe under concurrent invocations.
      gws-work = "GOOGLE_WORKSPACE_CLI_CONFIG_DIR=$HOME/.config/gws-work gws";
      gws-personal = "GOOGLE_WORKSPACE_CLI_CONFIG_DIR=$HOME/.config/gws-personal gws";

      # Tmuxinator aliases
      instaffo-start = "tmuxinator start instaffo";
      instaffo-stop = "tmuxinator stop instaffo";

      # Git aliases
      gp = "git push";
      gf = "git fetch";

      # Claude Manager aliases
      cm = "pnpm dlx @instaffo/claude-manager";
      cm_dev = "pnpm dlx /Users/patrick/Projects/Instaffo/claude-manager";

      # Claude Dashboard launchd controls (service: com.patrick.claude-dashboard)
      claude-dashboard-start = "launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.patrick.claude-dashboard.plist";
      claude-dashboard-stop = "launchctl bootout gui/$(id -u)/com.patrick.claude-dashboard";
      claude-dashboard-restart = "launchctl kickstart -k gui/$(id -u)/com.patrick.claude-dashboard";
    };

    sessionVariables = {
      EDITOR = "nvim";
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      TERM = "screen-256color";
      GREP_COLORS = "mt=01;34";
      DISABLE_AUTO_TITLE = "true";
      HOMEBREW_NO_ANALYTICS = "1";
      LIBRARY_PATH = "${pkgs.zstd.out}/lib:${pkgs.openssl.out}/lib";
      SD_MODEL = "${sdModel}";
      FLUX_MODEL = "${fluxModel}";
      FLUX_VAE = "${fluxVae}";
      FLUX_CLIP_L = "${fluxClipL}";
      FLUX_T5 = "${fluxT5}";
    };

    envExtra = ''
      # PATH lives in zshenv so non-interactive shells (scripts, launchd-spawned
      # services like claude-dashboard) inherit it too, not just interactive zsh.
      export PATH="$HOME/.bin:$PATH:/usr/local/bin"
      export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
      export PATH="/usr/local/sbin:$PATH"
      export PATH="$HOME/.cargo/bin:$PATH"
      export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"

      # pnpm global bin (pnpm install -g)
      export PATH="$HOME/Library/pnpm/bin:$PATH"

      # Homebrew and mise — needed in non-interactive shells too. Previously
      # these only loaded via .zprofile (brew, login-only) and .zshrc (mise,
      # interactive-only), so launchd-spawned shells got neither.
      [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
      export PATH="$HOME/.local/share/mise/shims:$PATH"
    '';

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

      # FLUX.1-schnell resident server. Loads the model once (~21GB in unified
      # memory, ~45s) and stays up. Run in its own terminal; Ctrl-C to stop and
      # free the memory. Generate against it with flux-request.
      function flux-server() {
        echo "flux-server: loading model (~21GB resident, ~45s). Ctrl-C to stop and free memory." >&2
        sd-server \
          --diffusion-model "$FLUX_MODEL" \
          --vae "$FLUX_VAE" \
          --clip_l "$FLUX_CLIP_L" \
          --t5xxl "$FLUX_T5" \
          --listen-port 1234 "$@"
      }

      # Generate one image via a running flux-server. Both flags required.
      #   flux-request -p "candid portrait photo, natural skin texture, 50mm" -o out.png
      function flux-request() {
        local OPTIND OPTARG arg p="" o=""
        while getopts "p:o:" arg; do
          case $arg in
            p) p="$OPTARG" ;;
            o) o="$OPTARG" ;;
            *) ;;
          esac
        done
        if [[ -z "$p" || -z "$o" ]]; then
          echo "usage: flux-request -p <prompt> -o <output.png>" >&2
          return 1
        fi
        if ! curl -sf -o /dev/null http://127.0.0.1:1234/sdcpp/v1/capabilities 2>/dev/null; then
          echo "flux-request: server not reachable on :1234 — start it first with flux-server" >&2
          return 1
        fi
        curl -s http://127.0.0.1:1234/sdapi/v1/txt2img -H 'Content-Type: application/json' \
          -d "$(jq -n --arg p "$p" '{prompt:$p, steps:4, cfg_scale:1.0, sampler_name:"euler", width:1024, height:1024, seed:-1}')" \
          | jq -r '.images[0]' | base64 -d > "$o" && echo "flux-request: wrote $o"
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

      # PATH modifications moved to envExtra (zshenv) so non-interactive shells see them.

      # Load version managers
      eval "$(mise activate zsh)" 2>/dev/null || true

      # Set GPG_TTY for GPG signing
      export GPG_TTY=$(tty)

      # Load Nix profiles
      if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      # nix-daemon.sh re-prepends ~/.nix-profile/bin, shoving it ahead of the
      # mise shims set in zshenv. Re-assert shims first so mise-managed tools
      # (node 22, etc.) beat nix-profile in this shell and every child it spawns
      # (git/husky/pnpm pre-commit hooks run non-interactive and inherit this PATH).
      export PATH="$HOME/.local/share/mise/shims:$PATH"

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

      # Show "now" tasks from the Notes taskmd project on interactive startup.
      if command -v taskmd >/dev/null 2>&1; then
        taskmd next --columns id,title --phase now --project Notes 2>/dev/null | tail -n '+5'
      fi

    '';
  };

  git = {
    enable = true;
    ignores = [ "*.swp" ];
    signing = {
      format = "ssh";
      key = "/Users/${user}/.ssh/id_ed25519.pub";
      signByDefault = true;
    };
    lfs = {
      enable = true;
    };
    settings = {
      user = { inherit name email; };
      init.defaultBranch = "main";
      core = {
        editor = "vim";
        autocrlf = "input";
      };
      pull.rebase = true;
      rebase.autoStash = true;
      # Move submodule working trees to the superproject's recorded SHA on
      # pull/checkout (stops vendored submodules drifting). Does not auto-init
      # newly added submodules; first checkout still needs `git submodule update --init`.
      submodule.recurse = true;
    };
  };

  ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "/Users/${user}/.ssh/config_external" ];
    settings = {
      "*" = {
        # Set the default values we want to keep
        sendEnv = [
          "LANG"
          "LC_*"
        ];
        hashKnownHosts = true;
        # Load keys into the agent on first use and pull the passphrase
        # from the macOS Keychain so it is only typed once, ever.
        # UseKeychain is Apple-ssh only; nixpkgs openssh aborts on it, so
        # tolerate it as unknown there. Renders before UseKeychain (ASCII sort).
        IgnoreUnknown = "UseKeychain";
        addKeysToAgent = "yes";
        UseKeychain = "yes";
        # Default key for all git hosts (github, gitlab, ...) and signing
        identityFile = [ "/Users/${user}/.ssh/id_ed25519" ];
      };
      "github.com" = {
        identitiesOnly = true;
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

      # Prevent garbage characters when scrolling
      set -g mouse off
      bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
      bind -n WheelDownPane select-pane -t= \; send-keys -M

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
      bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"

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
