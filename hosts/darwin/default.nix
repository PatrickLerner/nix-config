{
  agenix,
  claude-code-nix,
  karamd,
  pkgs,
  ...
}:

let
  user = "patrick";

in
{

  imports = [
    ../../modules/darwin/secrets.nix
    ../../modules/darwin/home-manager.nix
    agenix.darwinModules.default
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
      allowInsecure = false;
      allowUnsupportedSystem = true;
    };

    overlays =
      # Apply each overlay found in the /overlays directory
      let
        path = ../../overlays;
      in
      with builtins;
      map (n: import (path + ("/" + n))) (
        filter (n: match ".*\\.nix" n != null || pathExists (path + ("/" + n + "/default.nix"))) (
          attrNames (readDir path)
        )
      )
      ++ [
        # Use claude-code from claude-code-nix flake
        (_final: prev: {
          claude-code = claude-code-nix.packages.${prev.stdenv.hostPlatform.system}.default;
        })
      ];
  };

  # Nix itself is managed by Determinate Nix (its own daemon), not nix-darwin.
  # Letting nix-darwin manage the installation too conflicts with Determinate,
  # so we hand control of the Nix installation to Determinate.
  nix.enable = false;

  # With nix.enable = false, nix-darwin no longer writes /etc/nix/nix.conf, so
  # our caches/flakes/trusted-users would be lost. Determinate's managed
  # nix.conf includes /etc/nix/nix.custom.conf, so put our settings there.
  # (cache.nixos.org is a Determinate default; we only add the extra caches.)
  environment.etc."nix/nix.custom.conf".text = ''
    experimental-features = nix-command flakes
    trusted-users = root @admin ${user}
    extra-substituters = https://nix-community.cachix.org https://claude-code.cachix.org
    extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk=
  '';

  # Turn off NIX_PATH warnings now that we're using flakes

  # Raise the open-file limit. The launchd default (256) gets inherited by
  # non-login processes, which makes large flake-input fetches (homebrew-core)
  # die with "Too many open files". This sets it system-wide at boot.
  launchd.daemons.maxfiles = {
    serviceConfig = {
      Label = "limit.maxfiles";
      ProgramArguments = [
        "launchctl"
        "limit"
        "maxfiles"
        "524288"
        "1048576"
      ];
      RunAtLoad = true;
      ServiceIPC = false;
    };
  };

  networking = {
    hostName = "dobare";
    computerName = "dobare";
    localHostName = "dobare";
  };

  # Load configuration that is shared across systems
  environment.systemPackages =
    with pkgs;
    [
      agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
      # Prebuilt release binary, no local compile.
      karamd.packages."${pkgs.stdenv.hostPlatform.system}".karamd-web
    ]
    ++ (import ../../modules/shared/packages.nix { inherit pkgs; });

  # Override TERM to prevent alacritty terminfo errors
  environment.variables = {
    TERM = "screen-256color";
  };

  system = {
    activationScripts.preActivation.text = ''
      # Install Rosetta 2 on Apple Silicon Macs
      if [ "$(uname -m)" = "arm64" ]; then
        if [ ! -f /Library/Apple/usr/libexec/oah/libRosettaRuntime ]; then
          echo "Installing Rosetta 2..."
          /usr/bin/softwareupdate --install-rosetta --agree-to-license
        fi
      fi
    '';

    checks.verifyNixPath = false;
    primaryUser = user;
    stateVersion = 5;

    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;

        # 120, 90, 60, 30, 12, 6, 2
        KeyRepeat = 2;

        # 120, 94, 68, 35, 25, 15
        InitialKeyRepeat = 30;

        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.trackpad.scaling" = 3.0;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.feedback" = 0;

        # Sidebar icon size: 1 = small, 2 = medium, 3 = large
        NSTableViewDefaultSizeMode = 1;
      };

      dock = {
        autohide = true;
        autohide-delay = 0.0;
        show-recents = false;
        launchanim = true;
        orientation = "left";
        tilesize = 38;
      };

      menuExtraClock = {
        IsAnalog = true;
      };

      controlcenter = {
        BatteryShowPercentage = true;
        Sound = true;
      };

      finder = {
        _FXShowPosixPathInTitle = false;
        ShowPathbar = true;
        FXPreferredViewStyle = "Nlsv";
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
        # Click pressure: 0 = light, 1 = medium, 2 = firm
        FirstClickThreshold = 0;
        SecondClickThreshold = 0;
      };

      CustomUserPreferences = {
        # Hide the Spotlight icon from the menu bar
        "com.apple.Spotlight" = {
          "NSStatusItem VisibleCC Item-0" = false;
        };

        # Disable clicking the wallpaper to reveal the desktop
        "com.apple.WindowManager" = {
          EnableStandardClickToShowDesktop = false;
        };
      };
    };
  };
}
