{
  pkgs,
  ...
}:

let
  user = "patrick";
  # Default headroom port; freed up by moving karamd-web to 8788. Claude Code
  # is routed here via ANTHROPIC_BASE_URL (set in shared/home-manager.nix).
  port = "8787";

  # headroom is a uv-managed tool at ~/.local/bin (installed by the
  # installHeadroom activation hook), not a nix store path.
  headroom = "/Users/${user}/.local/bin/headroom";

  # Login shell so the uv shim finds its python and the bundled CLI tools.
  # Unset the client routing vars from zshenv so the proxy never targets itself.
  wrapper = pkgs.writeScript "headroom-proxy-wrapper" ''
    #!${pkgs.zsh}/bin/zsh -l
    [[ -f "$HOME/.zshenv" ]] && . "$HOME/.zshenv"
    unset ANTHROPIC_BASE_URL OPENAI_BASE_URL
    exec ${headroom} proxy --port ${port}
  '';
in
{
  launchd.user.agents.headroom-proxy = {
    serviceConfig = {
      Label = "com.patrick.headroom-proxy";
      ProgramArguments = [ "${wrapper}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/${user}/Library/Logs/headroom-proxy.log";
      StandardErrorPath = "/Users/${user}/Library/Logs/headroom-proxy.log";
      EnvironmentVariables = {
        HOME = "/Users/${user}";
      };
    };
  };
}
