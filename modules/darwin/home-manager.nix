{ config, pkgs, ... }:

let
  user = "patrick";
  # Define the content of your file as a derivation
  sharedFiles = import ../shared/files.nix { inherit config pkgs; };
in
{
  imports = [
    ./dock
    ./mcp-proxy.nix
    ./claude-dashboard.nix
    ./claude-oauth-gitlab.nix
  ];

  # It me
  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.zsh;
  };

  homebrew = {
    enable = true;
    casks = pkgs.callPackage ./casks.nix { };
    brews = [
      "aws-console"
      "aws-iam-authenticator"
      "awscli"
      "coreutils"
      "dockutil"
      "driangle/tap/taskmd"
      "gemini-cli"
      "gitlab-ci-local"
      "libyaml"
      "ocrmypdf"
      "openai-whisper"
      "openssl"
      "rtk"
      "tesseract-lang"
    ];
    onActivation.cleanup = "uninstall";

    # These app IDs are from using the mas CLI app
    # mas = mac app store
    # https://github.com/mas-cli/mas
    #
    # $ nix shell nixpkgs#mas
    # $ mas search <app name>
    #
    # If you have previously added these apps to your Mac App Store profile (but not installed them on this system),
    # you may receive an error message "Redownload Unavailable with This Apple ID".
    # This message is safe to ignore. (https://github.com/dustinlyons/nixos-config/issues/83)

    masApps = {
      # Development Tools
      "Xcode" = 497799835;

      # Productivity & Utilities
      "Amphetamine" = 937984704;
      "AusweisApp" = 948660805;
      "ColorSlurp" = 1287239339;
      "ICE Buddy" = 1595947689;
      "LanguageTool" = 1534275760;
      "Pocket Yoga" = 409206073;

      # Apple Productivity Suite
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;

      # Media & Content Creation
      "Pixea" = 1507782672;
      "Pixelmator Pro" = 1289583905;

      # Gaming & Entertainment
      "Steam Link" = 1246969117;
    };
  };

  # Enable home-manager
  home-manager = {
    useGlobalPkgs = true;
    users.${user} =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      {
        home = {
          enableNixpkgsReleaseCheck = false;
          packages = pkgs.callPackage ../shared/packages.nix { };
          file = sharedFiles;

          stateVersion = "23.11";

          # Activation script to configure Claude MCP servers.
          # Idempotent: only mutates ~/.claude.json when an entry differs
          # from the declared transport/URL. Writes JSON directly via jq
          # rather than going through `claude mcp add/remove`, which proved
          # flaky during activation (silent failures on remove leaving stale
          # stdio entries that then collided with the new add).
          activation.setupClaudeMCP = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            JQ="${pkgs.jq}/bin/jq"
            CLAUDE_JSON="/Users/${user}/.claude.json"

            if [ ! -f "$CLAUDE_JSON" ]; then
              echo "{}" > "$CLAUDE_JSON"
            fi

            _backed_up=0
            backup_once() {
              if [ "$_backed_up" -eq 0 ]; then
                cp "$CLAUDE_JSON" "$CLAUDE_JSON.bak.$(date +%s)" || true
                _backed_up=1
              fi
            }

            # Set .mcpServers[name] to {type, url} preserving any existing
            # headers (e.g. Jam's Authorization). Drops stdio-only fields
            # (command/args/env) on transport switch.
            update_server() {
              local name="$1" type="$2" url="$3"
              local cur_type cur_url
              cur_type=$($JQ -r --arg n "$name" '.mcpServers[$n].type // ""' "$CLAUDE_JSON")
              cur_url=$($JQ -r --arg n "$name" '.mcpServers[$n].url // ""' "$CLAUDE_JSON")
              if [ "$cur_type" = "$type" ] && [ "$cur_url" = "$url" ]; then
                return 0
              fi
              echo "MCP $name: updating ($cur_type $cur_url -> $type $url)"
              backup_once
              $JQ --arg n "$name" --arg t "$type" --arg u "$url" \
                '.mcpServers[$n] = ({type: $t, url: $u} + (if .mcpServers[$n].headers then {headers: .mcpServers[$n].headers} else {} end))' \
                "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
            }

            # stdio MCPs fronted by the local mcp-proxy launchd agent. Both Google
            # accounts use @a-bonus/google-docs-mcp (Docs/Drive/Gmail/Calendar);
            # the work instance just selects a different OAuth profile.
            update_server Gitlab              sse  http://127.0.0.1:8765/servers/Gitlab/sse
            update_server claude-orchestrator sse  http://127.0.0.1:8765/servers/claude-orchestrator/sse
            update_server google-private      sse  http://127.0.0.1:8765/servers/google-private/sse
            update_server google-work         sse  http://127.0.0.1:8765/servers/google-work/sse

            # Already hosted remotely, no proxy needed
            update_server Jam                 http https://mcp.jam.dev/mcp
          '';

          # Ensure selected Instaffo GitLab repos are checked out under
          # ~/Projects/Instaffo, mirroring the GitLab group structure. Clones
          # only when the target dir is missing; never pulls or updates an
          # existing checkout. The repo list is an agenix secret (one path per
          # line, relative to gitlab.com/Instaffo) so the private group
          # structure stays out of this public config.
          activation.cloneInstaffoRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            BASE="/Users/${user}/Projects/Instaffo"
            REPO_LIST="/Users/${user}/.config/instaffo-repos"
            ${pkgs.coreutils}/bin/mkdir -p "$BASE"

            if [ ! -r "$REPO_LIST" ]; then
              echo "cloneInstaffoRepos: $REPO_LIST not readable yet, skipping"
              exit 0
            fi

            clone_repo() {
              local path="$1"
              local dest="$BASE/$path"
              if [ -d "$dest/.git" ]; then
                return 0
              fi
              # instaffo-skills is the only project hosted on GitHub
              # (InstaffoGmbH org); everything else lives in the GitLab group.
              local url="git@gitlab.com:Instaffo/$path.git"
              if [ "$path" = "instaffo-skills" ]; then
                url="git@github.com:InstaffoGmbH/instaffo-skills.git"
              fi
              echo "cloneInstaffoRepos: cloning $path"
              ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$dest")"
              GIT_SSH_COMMAND="/usr/bin/ssh -o StrictHostKeyChecking=accept-new" \
                ${pkgs.git}/bin/git clone "$url" "$dest" || true
            }

            # Skip blank lines and # comments
            while IFS= read -r line || [ -n "$line" ]; do
              line="''${line%%#*}"
              line="$(echo "$line" | ${pkgs.coreutils}/bin/tr -d '[:space:]')"
              [ -z "$line" ] && continue
              clone_repo "$line"
            done < "$REPO_LIST"
          '';

          # Ensure selected personal GitHub repos are checked out under
          # ~/Projects. Clones only when the target dir is missing; never pulls
          # or updates an existing checkout. The repo list is an agenix secret
          # (one `owner/repo` per line, relative to github.com) so private repo
          # names stay out of this public config. Each repo lands in
          # ~/Projects/<repo-basename>.
          activation.cloneGithubRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            BASE="/Users/${user}/Projects"
            REPO_LIST="/Users/${user}/.config/github-repos"
            ${pkgs.coreutils}/bin/mkdir -p "$BASE"

            if [ ! -r "$REPO_LIST" ]; then
              echo "cloneGithubRepos: $REPO_LIST not readable yet, skipping"
              exit 0
            fi

            # Skip blank lines and # comments
            while IFS= read -r line || [ -n "$line" ]; do
              line="''${line%%#*}"
              line="$(echo "$line" | ${pkgs.coreutils}/bin/tr -d '[:space:]')"
              [ -z "$line" ] && continue
              dest="$BASE/''${line##*/}"
              [ -d "$dest/.git" ] && continue
              echo "cloneGithubRepos: cloning $line"
              GIT_SSH_COMMAND="/usr/bin/ssh -o StrictHostKeyChecking=accept-new" \
                ${pkgs.git}/bin/git clone "git@github.com:$line.git" "$dest" || true
            done < "$REPO_LIST"
          '';

          # Register checked-out Instaffo repos in ~/.claude-orchestrator.json so
          # the claude-orchestrator dashboard/MCP knows their local paths. ONLY
          # adds missing entries under .repos, keyed by each repo's GitLab project
          # path (derived from `git remote get-url origin`); never modifies an
          # existing entry or any other part of the file (dashboard plugin config
          # stays user-managed). The file is created as {} only if absent.
          activation.registerOrchestratorRepos = lib.hm.dag.entryAfter [ "cloneInstaffoRepos" ] ''
            JQ="${pkgs.jq}/bin/jq"
            GIT="${pkgs.git}/bin/git"
            BASE="/Users/${user}/Projects/Instaffo"
            CFG="/Users/${user}/.claude-orchestrator.json"

            [ -d "$BASE" ] || exit 0

            # Create with only a repos key when absent; never seed the dashboard
            # config (that stays user-managed). If the file exists, touch nothing
            # but .repos below.
            [ -f "$CFG" ] || echo '{"repos":{}}' > "$CFG"

            ${pkgs.findutils}/bin/find "$BASE" -maxdepth 6 -type d -name .git | while IFS= read -r gitdir; do
              repo="$(${pkgs.coreutils}/bin/dirname "$gitdir")"
              url="$("$GIT" -C "$repo" remote get-url origin 2>/dev/null)" || continue
              case "$url" in
                *gitlab.com[:/]Instaffo/*) ;;
                *) continue ;;
              esac
              # git@gitlab.com:Instaffo/Product/app.git -> Instaffo/Product/app
              key="''${url#*gitlab.com[:/]}"
              key="''${key%.git}"
              if "$JQ" -e --arg k "$key" '.repos[$k]' "$CFG" >/dev/null 2>&1; then
                continue
              fi
              echo "registerOrchestratorRepos: adding $key -> $repo"
              "$JQ" --arg k "$key" --arg p "$repo" \
                '.repos = ((.repos // {}) + {($k): {path: $p}})' \
                "$CFG" > "$CFG.tmp" && ${pkgs.coreutils}/bin/mv "$CFG.tmp" "$CFG"
            done
          '';

          # Register the Instaffo plugin marketplace and enable the team
          # plugins for the user. Idempotent: skips the marketplace add when
          # already known, and skips each plugin when already enabled in
          # ~/.claude.json. Never breaks activation (all steps `|| true`).
          activation.setupClaudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            JQ="${pkgs.jq}/bin/jq"
            CLAUDE="${pkgs.claude-code}/bin/claude"
            KNOWN="/Users/${user}/.claude/plugins/known_marketplaces.json"
            CLAUDE_JSON="/Users/${user}/.claude.json"
            MARKET="instaffo-skills"
            SOURCE="git@github.com:InstaffoGmbH/instaffo-skills.git"
            export GIT_SSH_COMMAND="/usr/bin/ssh -o StrictHostKeyChecking=accept-new"

            # Add the marketplace if not already registered.
            if [ ! -f "$KNOWN" ] || ! $JQ -e --arg m "$MARKET" '.[$m]' "$KNOWN" >/dev/null 2>&1; then
              echo "setupClaudePlugins: adding marketplace $MARKET"
              "$CLAUDE" plugin marketplace add "$SOURCE" || true
            fi

            # Enable each team plugin (user scope) if not already enabled.
            for plugin in instaffo-dev instaffo-pm instaffo-amex instaffo-leadership instaffo-shared; do
              ref="$plugin@$MARKET"
              if [ -f "$CLAUDE_JSON" ] && $JQ -e --arg p "$ref" '.enabledPlugins[$p] == true' "$CLAUDE_JSON" >/dev/null 2>&1; then
                continue
              fi
              echo "setupClaudePlugins: installing $ref"
              "$CLAUDE" plugin install --scope user "$ref" || true
            done
          '';

          # Disable the Spotlight Cmd+Space shortcut (symbolichotkey 64).
          # Uses -dict-add so it merges into AppleSymbolicHotKeys rather than
          # replacing the whole dict (which would reset every other hotkey).
          activation.disableSpotlightShortcut = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
              -dict-add 64 '{enabled=0;value={parameters=(32,49,1048576);type="standard";};}' || true
          '';

          # Set the desktop wallpaper from the repo-managed image.
          activation.setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            WALLPAPER="/Users/${user}/.config/wallpaper.jpg"
            if [ -f "$WALLPAPER" ]; then
              /usr/bin/osascript -e "tell application \"System Events\" to set picture of every desktop to \"$WALLPAPER\"" || true
            fi
          '';

          # Declaratively set the Finder sidebar Favorites via mysides.
          # Ensures backing dirs exist, clears the existing favorites, then
          # re-adds the desired list in order. Google Drive paths are URL-encoded.
          activation.setFinderSidebar = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            HOME_DIR="/Users/${user}"
            GD="file:///Users/${user}/Library/CloudStorage/GoogleDrive-ptlerner@gmail.com/My%20Drive"

            # Ensure backing directories exist (always, independent of mysides)
            if [ ! -d "$HOME_DIR/Notes" ]; then
              GIT_SSH_COMMAND="/usr/bin/ssh -o StrictHostKeyChecking=accept-new" \
                ${pkgs.git}/bin/git clone git@github.com:PatrickLerner/Notes.git "$HOME_DIR/Notes" || true
            fi
            mkdir -p "$HOME_DIR/Workbench"

            # Favorites require mysides (Homebrew cask). If it isn't installed
            # yet (e.g. brew bundle runs after this on a first switch), skip the
            # favorites step; the next rebuild will apply them.
            MYSIDES="/usr/local/bin/mysides"
            if [ ! -x "$MYSIDES" ]; then
              echo "setFinderSidebar: mysides not installed yet, skipping favorites (will apply on next rebuild)"
              exit 0
            fi

            # Clear all existing favorites
            "$MYSIDES" list 2>/dev/null | while IFS= read -r line; do
              name="''${line%% -> *}"
              [ -n "$name" ] && "$MYSIDES" remove "$name" >/dev/null 2>&1 || true
            done

            # Re-add in the desired order
            "$MYSIDES" add Applications        "file:///Applications/"            >/dev/null 2>&1 || true
            "$MYSIDES" add Downloads           "file://$HOME_DIR/Downloads/"       >/dev/null 2>&1 || true
            "$MYSIDES" add Desktop             "file://$HOME_DIR/Desktop/"         >/dev/null 2>&1 || true
            "$MYSIDES" add "Data Files"        "$GD/Data%20Files/"                 >/dev/null 2>&1 || true
            "$MYSIDES" add Notes               "file://$HOME_DIR/Notes/"           >/dev/null 2>&1 || true
            "$MYSIDES" add "Language Learning" "$GD/Language%20Learning/"          >/dev/null 2>&1 || true
            "$MYSIDES" add Workbench           "file://$HOME_DIR/Workbench/"       >/dev/null 2>&1 || true

            /usr/bin/killall Finder >/dev/null 2>&1 || true
          '';
        };
        programs = { } // import ../shared/home-manager.nix { inherit config pkgs lib; };

        # Marked broken Oct 20, 2022 check later to remove this
        # https://github.com/nix-community/home-manager/issues/3344
        manual.manpages.enable = false;
      };
  };

  # Fully declarative dock using the latest from Nix Store
  local = {
    dock = {
      enable = true;
      username = user;
      entries = [
        { path = "/System/Applications/Mail.app"; }
        { path = "/System/Applications/Calendar.app"; }
        {
          path = "/Applications/Microsoft Edge.app";
        }
        # Edge Web App (must be created manually in Edge: ... > Apps > Install)
        {
          path = "${config.users.users.${user}.home}/Applications/Edge Apps.localized/Google Gemini.app";
        }
        { path = "/Applications/Claude.app"; }
        { path = "/Applications/WhatsApp.app/"; }
        { path = "/Applications/Telegram.app/"; }
        { path = "/Applications/Slack.app/"; }
        { path = "/Applications/Obsidian.app/"; }
        { path = "/Applications/Anki.app/"; }
        { path = "/Applications/Nix Apps/Alacritty.app"; }
        { path = "/Applications/Nix Apps/YouTube Music.app"; }
        { path = "/Applications/Pocket Casts.app"; }
        {
          path = "${config.users.users.${user}.home}";
          section = "others";
          options = "--sort name --view list --display folder";
        }
        {
          path = "${config.users.users.${user}.home}/Downloads";
          section = "others";
          options = "--sort name --view list --display folder";
        }
      ];
    };
  };
}
