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
      google-docs = {
        command = npx;
        args = [ "@a-bonus/google-docs-mcp" ];
        transportType = "stdio";
      };
      google-calendar = {
        command = pnpm;
        args = [
          "dlx"
          "@cocal/google-calendar-mcp"
        ];
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
