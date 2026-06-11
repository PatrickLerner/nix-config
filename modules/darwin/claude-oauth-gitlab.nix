{
  config,
  pkgs,
  ...
}:

let
  user = "patrick";

  # launchd does not inherit the shell env, so source ~/.secrets-env for
  # GITLAB_PERSONAL_ACCESS_TOKEN, then run the agenix-decrypted script. The
  # script body lives in the secret vault (agenix: claude-oauth-gitlab), not in
  # this public repo; only the schedule is declared here.
  wrapper = pkgs.writeScript "claude-oauth-gitlab-wrapper" ''
    #!/bin/bash
    if [ -f "$HOME/.secrets-env" ]; then
      set -a
      . "$HOME/.secrets-env"
      set +a
    fi
    exec /bin/bash ${config.age.secrets.claude-oauth-gitlab.path}
  '';
in
{
  # Push the local Claude OAuth token to the claude-orchestrator GitLab CI/CD
  # variables once an hour, so the remote runner keeps a usable session.
  launchd.user.agents.claude-oauth-gitlab = {
    serviceConfig = {
      Label = "com.patrick.claude-oauth-gitlab";
      ProgramArguments = [ "${wrapper}" ];
      # Every hour while the Mac is awake. launchd never wakes the machine; a
      # tick missed during sleep runs once on the next wake. No RunAtLoad, so it
      # does not fire on every rebuild/login (the timer resets on reload).
      StartInterval = 3600;
      RunAtLoad = false;
      StandardOutPath = "/Users/${user}/Library/Logs/claude-oauth-gitlab.log";
      StandardErrorPath = "/Users/${user}/Library/Logs/claude-oauth-gitlab.log";
      EnvironmentVariables = {
        HOME = "/Users/${user}";
        # System tools only: security, curl, xxd, uname, grep, sed (all /usr/bin).
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin:/run/current-system/sw/bin";
      };
    };
  };
}
