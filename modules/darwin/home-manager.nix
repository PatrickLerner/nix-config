{ config, pkgs, ... }:

let
  user = "patrick";
  # Define the content of your file as a derivation
  sharedFiles = import ../shared/files.nix { inherit config pkgs; };
in {
  imports = [ ./dock ./mcp-proxy.nix ./claude-dashboard.nix ];

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
      "gemini-cli"
      "gitlab-ci-local"
      "libyaml"
      "ocrmypdf"
      "openai-whisper"
      "openssl"
      "rtk"
      "tesseract-lang"
      "yt-dlp"
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
    users.${user} = { pkgs, config, lib, ... }: {
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

          # stdio MCPs fronted by the local mcp-proxy launchd agent
          update_server Gitlab              sse  http://127.0.0.1:8765/servers/Gitlab/sse
          update_server claude-orchestrator sse  http://127.0.0.1:8765/servers/claude-orchestrator/sse
          update_server google-docs         sse  http://127.0.0.1:8765/servers/google-docs/sse
          update_server google-calendar     sse  http://127.0.0.1:8765/servers/google-calendar/sse

          # Already hosted remotely, no proxy needed
          update_server Jam                 http https://mcp.jam.dev/mcp
        '';
      };
      programs = { }
        // import ../shared/home-manager.nix { inherit config pkgs lib; };

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
        # Safari Web App (must be created manually in Safari: File > Add to Dock)
        {
          path =
            "${config.users.users.${user}.home}/Applications/Google Gemini.app";
        }
        { path = "/Applications/Claude.app"; }
        { path = "/Applications/WhatsApp.app/"; }
        { path = "/Applications/Telegram.app/"; }
        { path = "/Applications/Slack.app/"; }
        { path = "/Applications/Discord.app/"; }
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
