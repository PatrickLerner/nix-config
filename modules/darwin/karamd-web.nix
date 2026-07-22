{
  pkgs,
  lib,
  karamd,
  ...
}:

let
  user = "patrick";

  karamd-web = karamd.packages.${pkgs.stdenv.hostPlatform.system}.karamd-web;

  # karamd web binds a fixed loopback port; portless is what turns that into a
  # stable https://karamd.localhost URL. karamd isn't a portless-managed dev
  # server, so it can't self-register — we add a static alias (idempotent, so
  # re-running on every launch is safe and survives a portless state reset).
  # Moved off 8787 so headroom's proxy can take the default port; portless
  # re-aliases karamd.localhost to whatever this is, so the URL is unaffected.
  port = "8788";
  vault = "/Users/${user}/Notes";

  wrapper = pkgs.writeScript "karamd-web-wrapper" ''
    #!${pkgs.zsh}/bin/zsh -l
    [[ -f "$HOME/.zshenv" ]] && . "$HOME/.zshenv"
    # Register the portless route to the loopback port. --force keeps it
    # correct if the port ever changes. Failure here (proxy not up yet) must
    # not stop karamd from serving, so swallow errors.
    ${pkgs.portless}/bin/portless alias karamd ${port} --force || true
    exec ${karamd-web}/bin/karamd web \
      --vault ${vault} \
      --bind 127.0.0.1:${port}
  '';
in
{
  launchd.user.agents.karamd-web = {
    serviceConfig = {
      Label = "com.patrick.karamd-web";
      ProgramArguments = [ "${wrapper}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/${user}/Library/Logs/karamd-web.log";
      StandardErrorPath = "/Users/${user}/Library/Logs/karamd-web.log";
      EnvironmentVariables = {
        # claude must be on PATH: karamd's "run" sessions spawn it in a PTY
        # (--run-command default). zshenv extends this further.
        PATH = lib.concatStringsSep ":" [
          "/Users/${user}/.nix-profile/bin"
          "${pkgs.claude-code}/bin"
          "${pkgs.coreutils}/bin"
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
