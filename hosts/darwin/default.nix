{ agenix, claude-code-nix, pkgs, ... }:

let user = "patrick";

in {

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
      let path = ../../overlays;
      in with builtins;
      map (n: import (path + ("/" + n))) (filter (n:
        match ".*\\.nix" n != null
        || pathExists (path + ("/" + n + "/default.nix")))
        (attrNames (readDir path)))
      ++ [
        # Use claude-code from claude-code-nix flake
        (final: prev: {
          claude-code = claude-code-nix.packages.${prev.system}.default;
        })
      ];
  };

  # Setup user, packages, programs
  nix = {
    package = pkgs.nix;

    settings = {
      trusted-users = [ "@admin" "${user}" ];
      substituters =
        [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Turn off NIX_PATH warnings now that we're using flakes

  # Load configuration that is shared across systems
  environment.systemPackages = with pkgs;
    [ agenix.packages."${pkgs.system}".default ]
    ++ (import ../../modules/shared/packages.nix { inherit pkgs; });

  # Override TERM to prevent alacritty terminfo errors
  environment.variables = { TERM = "screen-256color"; };

  system = {
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
        InitialKeyRepeat = 15;

        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.feedback" = 0;
      };

      dock = {
        autohide = true;
        autohide-delay = 0.0;
        show-recents = false;
        launchanim = true;
        orientation = "left";
        tilesize = 38;
      };

      finder = { _FXShowPosixPathInTitle = false; };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
    };
  };
}
