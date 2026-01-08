{ config, pkgs, ... }:

let
  user = "patrick";
  # Define the content of your file as a derivation
  sharedFiles = import ../shared/files.nix { inherit config pkgs; };
in {
  imports = [ ./dock ];

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
    brews =
      [ "aws-console" "aws-iam-authenticator" "coreutils" "libyaml" "openssl" ];
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
      "ColorSlurp" = 1287239339;
      "Day One" = 1055511498;
      "Hand Mirror" = 1502839586;
      "ICE Buddy" = 1595947689;
      "LanguageTool" = 1534275760;

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

        # Activation script to configure Claude MCP servers
        activation.setupClaudeMCP = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          # Setup Claude MCP servers for Figma, GitLab, Asana, and Sentry
          # Uses timeouts to prevent hanging during activation
          echo "Setting up Claude MCP servers..."

          CLAUDE="${pkgs.claude-code}/bin/claude"
          TIMEOUT="${pkgs.coreutils}/bin/timeout"

          # Helper function to check if MCP server exists (with timeout)
          mcp_exists() {
            $TIMEOUT 5s $CLAUDE mcp list --scope user 2>/dev/null | grep -q "$1"
          }

          # Helper function to add MCP server (with timeout)
          mcp_add() {
            $TIMEOUT 10s $CLAUDE mcp add --scope user "$@" 2>/dev/null || echo "Note: $1 MCP server setup skipped or already exists"
          }

          # Add Figma MCP server
          if ! mcp_exists "Figma"; then
            mcp_add Figma figma-developer-mcp
          fi

          # Add GitLab MCP server
          if ! mcp_exists "Gitlab"; then
            mcp_add Gitlab mcp-gitlab
          fi

          # Add Asana MCP server
          if ! mcp_exists "Asana"; then
            mcp_add Asana --transport http https://mcp.asana.com/sse
          fi

          # Add Sentry MCP server
          if ! mcp_exists "Sentry"; then
            mcp_add Sentry --transport http https://mcp.sentry.dev/mcp
          fi

          echo "Claude MCP server setup complete."
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
        { path = "/Applications/Slack.app/"; }
        { path = "/Applications/Discord.app/"; }
        { path = "/Applications/Obsidian.app/"; }
        { path = "/Applications/Anki.app/"; }
        { path = "${pkgs.alacritty}/Applications/Alacritty.app/"; }
        { path = "/Applications/Nix Apps/Pear Desktop.app"; }
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
