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
