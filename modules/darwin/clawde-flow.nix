{
  pkgs,
  lib,
  ...
}:

let
  user = "patrick";
  port = "4179";

  # Same program `clawde-flow service install` writes, declared here instead of
  # its imperative plist. npx resolves @latest on every start, so a restart is
  # the update. Tokens come from ~/.secrets-env at run time, never the store;
  # `service launch` strips what portless and npx add before sessions inherit it.
  wrapper = pkgs.writeScript "clawde-flow-wrapper" ''
    #!${pkgs.zsh}/bin/zsh -l
    if [[ -f "$HOME/.secrets-env" ]]; then
      set -a
      . "$HOME/.secrets-env"
      set +a
    fi
    exec ${pkgs.portless}/bin/portless clawde-flow --app-port ${port} \
      ${pkgs.nodejs_24}/bin/npx -y @instaffo/clawde-flow@latest \
      service launch --port ${port}
  '';
in
{
  launchd.user.agents.clawde-flow = {
    serviceConfig = {
      Label = "com.patrick.clawde-flow";
      # See portless-proxy.nix: wait for the Nix volume at boot.
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path '${wrapper}' && exec '${wrapper}'"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      # A registry or proxy that is not up yet at login fails fast; don't spin.
      ThrottleInterval = 10;
      StandardOutPath = "/Users/${user}/Library/Logs/clawde-flow.log";
      StandardErrorPath = "/Users/${user}/Library/Logs/clawde-flow.log";
      EnvironmentVariables = {
        # Agent sessions inherit this: they need claude, git, glab and node.
        PATH = lib.concatStringsSep ":" [
          "/Users/${user}/.nix-profile/bin"
          "/etc/profiles/per-user/${user}/bin"
          "/run/current-system/sw/bin"
          "${pkgs.claude-code}/bin"
          "/Users/${user}/.local/share/mise/shims"
          "/opt/homebrew/bin"
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
