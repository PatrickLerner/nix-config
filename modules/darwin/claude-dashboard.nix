{ config, pkgs, lib, ... }:

let
  user = "patrick";

  # Source ~/.secrets-env then exec pnpm dlx claude-dashboard.
  # launchd doesn't inherit shell env, so secrets needed by the
  # dashboard (e.g. GITLAB_*) must be loaded here.
  wrapper = pkgs.writeShellScript "claude-dashboard-wrapper" ''
    if [ -f "$HOME/.secrets-env" ]; then
      set -a
      . "$HOME/.secrets-env"
      set +a
    fi
    exec ${pkgs.pnpm}/bin/pnpm dlx --allow-build=node-pty @instaffo/claude-dashboard
  '';
in {
  launchd.user.agents.claude-dashboard = {
    serviceConfig = {
      Label = "com.patrick.claude-dashboard";
      ProgramArguments = [ "${wrapper}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/${user}/Library/Logs/claude-dashboard.log";
      StandardErrorPath = "/Users/${user}/Library/Logs/claude-dashboard.log";
      EnvironmentVariables = {
        PATH = lib.concatStringsSep ":" [
          "${pkgs.pnpm}/bin"
          "${pkgs.nodejs_24}/bin"
          "${pkgs.coreutils}/bin"
          "/usr/bin"
          "/bin"
        ];
        HOME = "/Users/${user}";
      };
    };
  };
}
