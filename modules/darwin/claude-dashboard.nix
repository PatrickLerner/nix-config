{
  config,
  pkgs,
  lib,
  ...
}:

let
  user = "patrick";

  # Run as a login shell so ~/.zprofile is sourced (brew shellenv lives there,
  # which is what puts /opt/homebrew/bin on PATH). Non-login zsh would only
  # see ~/.zshenv, missing homebrew tools like rtk.
  wrapper = pkgs.writeScript "claude-dashboard-wrapper" ''
    #!${pkgs.zsh}/bin/zsh -l
    [[ -f "$HOME/.zshenv" ]] && . "$HOME/.zshenv"
    if [[ -f "$HOME/.secrets-env" ]]; then
      set -a
      . "$HOME/.secrets-env"
      set +a
    fi
    exec ${pkgs.pnpm}/bin/pnpm dlx --allow-build=node-pty @instaffo/claude-dashboard
  '';
in
{
  # The dashboard serves on a high port; the portless proxy fronts it at
  # https://clawde.localhost on 443. `proxy start` daemonizes and needs sudo
  # for the privileged port, so it can't be launched from the (no-TTY) user
  # agent and doesn't survive reboot on its own. Run it as a root LaunchDaemon
  # in --foreground (launchd owns the process; KeepAlive restarts it). HOME is
  # pinned to the user so root reuses the existing ~/.portless CA — the one
  # already trusted in the System keychain — instead of minting a fresh one.
  launchd.daemons.portless-proxy = {
    serviceConfig = {
      Label = "com.patrick.portless-proxy";
      # /nix is a separate APFS volume mounted by its own daemon at boot. A root
      # LaunchDaemon pointing straight at a /nix/store path can fire before that
      # mount completes; launchd then logs "Missing executable", parks the job
      # inactive, and KeepAlive does NOT retry a missing-executable failure, so
      # the proxy silently never comes up until a manual bootout/bootstrap.
      # Gate the exec on the store path existing, using only boot-volume binaries
      # (/bin/sh, /bin/wait4path) so launchd can always spawn argv[0].
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path '${pkgs.portless}/bin/portless' && exec '${pkgs.portless}/bin/portless' proxy start --foreground"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/${user}/Library/Logs/portless-proxy.log";
      StandardErrorPath = "/Users/${user}/Library/Logs/portless-proxy.log";
      EnvironmentVariables = {
        HOME = "/Users/${user}";
        PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  launchd.user.agents.claude-dashboard = {
    serviceConfig = {
      Label = "com.patrick.claude-dashboard";
      ProgramArguments = [ "${wrapper}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/${user}/Library/Logs/claude-dashboard.log";
      StandardErrorPath = "/Users/${user}/Library/Logs/claude-dashboard.log";
      EnvironmentVariables = {
        # Bootstrap PATH so zsh and pnpm load; zshenv extends it. /usr/local/bin
        # is included as a belt-and-suspenders fallback for Docker Desktop.
        PATH = lib.concatStringsSep ":" [
          "/Users/${user}/.nix-profile/bin"
          "${pkgs.pnpm}/bin"
          "${pkgs.nodejs_24}/bin"
          "${pkgs.coreutils}/bin"
          "/Users/${user}/.local/share/mise/shims"
          "/opt/homebrew/bin"
          "/usr/local/bin"
          "/usr/local/sbin"
          "/usr/bin"
          "/bin"
          "/usr/sbin"
          "/sbin"
        ];
        HOME = "/Users/${user}";
      };
    };
  };
}
