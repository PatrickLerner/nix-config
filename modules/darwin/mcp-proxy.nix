{
  config,
  pkgs,
  lib,
  ...
}:

let
  user = "patrick";
  port = 8765;
  configPath = "/Users/${user}/.config/mcp-proxy/servers.json";

  # Wrapper that sources ~/.secrets-env so child MCP servers
  # (e.g. Gitlab needing GITLAB_PERSONAL_ACCESS_TOKEN) inherit the
  # required env vars. launchd doesn't inherit shell env, AND mcp's
  # stdio_client only forwards a safe default env (PATH/HOME/USER...)
  # to spawned children — so this wrapper must run inside each stdio
  # subprocess, not just around mcp-proxy itself.
  pnpmWrapper = pkgs.writeShellScript "mcp-pnpm-wrapper" ''
    if [ -f "$HOME/.secrets-env" ]; then
      set -a
      . "$HOME/.secrets-env"
      set +a
    fi
    exec ${pkgs.pnpm}/bin/pnpm "$@"
  '';
  pnpm = "${pnpmWrapper}";

  # npx instead of `pnpm dlx` for packages whose published JS imports
  # undeclared transitive deps (e.g. @a-bonus/google-docs-mcp pulls in
  # @modelcontextprotocol/sdk without listing it) — pnpm's strict
  # isolated linker can't resolve them; npm's flatter layout can.
  npxWrapper = pkgs.writeShellScript "mcp-npx-wrapper" ''
    if [ -f "$HOME/.secrets-env" ]; then
      set -a
      . "$HOME/.secrets-env"
      set +a
    fi
    exec ${pkgs.nodejs_24}/bin/npx --yes "$@"
  '';
  npx = "${npxWrapper}";

  # Same as npxWrapper but selects the @a-bonus/google-docs-mcp "work" profile,
  # which reads its refresh token from ~/.config/google-docs-mcp/work/token.json
  # (the default profile uses ~/.config/google-docs-mcp/token.json). Both profiles
  # share the OAuth client creds via GOOGLE_OAUTH_CREDENTIALS from ~/.secrets-env.
  # Set inside the subprocess (not the proxy env) for the same reason the secrets
  # are: mcp's stdio_client only forwards a safe default env to children.
  npxWorkWrapper = pkgs.writeShellScript "mcp-npx-wrapper-work" ''
    if [ -f "$HOME/.secrets-env" ]; then
      set -a
      . "$HOME/.secrets-env"
      set +a
    fi
    export GOOGLE_MCP_PROFILE=work
    exec ${pkgs.nodejs_24}/bin/npx --yes "$@"
  '';
  npxWork = "${npxWorkWrapper}";

  serversJson = builtins.toJSON {
    mcpServers = {
      claude-orchestrator = {
        command = pnpm;
        args = [
          "--package=@instaffo/claude-dashboard"
          "dlx"
          "claude-mcp"
        ];
        transportType = "stdio";
      };
      Gitlab = {
        command = pnpm;
        args = [
          "dlx"
          "@zereight/mcp-gitlab"
          "-e"
          "GITLAB_TOOLSETS=all"
          "-e"
          "GITLAB_TOOLS=execute_graphql"
        ];
        transportType = "stdio";
      };
      # Personal Google account (default profile). @a-bonus/google-docs-mcp
      # covers Docs, Drive, Gmail and Calendar, so no separate calendar MCP.
      google-private = {
        command = npx;
        args = [ "@a-bonus/google-docs-mcp" ];
        transportType = "stdio";
      };
      # Work Google account: same package, "work" profile (separate token file).
      google-work = {
        command = npxWork;
        args = [ "@a-bonus/google-docs-mcp" ];
        transportType = "stdio";
      };
    };
  };
in
{
  launchd.user.agents.mcp-proxy = {
    serviceConfig = {
      Label = "com.patrick.mcp-proxy";
      ProgramArguments = [
        "${pkgs.mcp-proxy}/bin/mcp-proxy"
        "--host"
        "127.0.0.1"
        "--port"
        (toString port)
        "--named-server-config"
        configPath
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/${user}/Library/Logs/mcp-proxy.log";
      StandardErrorPath = "/Users/${user}/Library/Logs/mcp-proxy.log";
      EnvironmentVariables = {
        PATH = lib.concatStringsSep ":" [
          "${pkgs.pnpm}/bin"
          "${pkgs.nodejs_24}/bin"
          "${pkgs.coreutils}/bin"
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

  home-manager.users.${user} = {
    home.file.".config/mcp-proxy/servers.json".text = serversJson;
  };
}
