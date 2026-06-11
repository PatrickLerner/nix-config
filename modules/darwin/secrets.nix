{ secrets, ... }:

let
  user = "patrick";
in
{
  age = {
    identityPaths = [ "/Users/${user}/.ssh/id_ed25519_agenix" ];

    secrets = {
      # Environment variables from encrypted file
      "env-vars" = {
        symlink = false;
        path = "/Users/${user}/.secrets-env";
        file = "${secrets}/env-vars.age";
        mode = "600";
        owner = "${user}";
        group = "staff";
      };

      # SSH private keys
      "ssh-id-rsa" = {
        symlink = true;
        path = "/Users/${user}/.ssh/id_rsa";
        file = "${secrets}/ssh-id-rsa.age";
        mode = "600";
        owner = "${user}";
        group = "staff";
      };

      "ssh-id-ed25519" = {
        symlink = true;
        path = "/Users/${user}/.ssh/id_ed25519";
        file = "${secrets}/ssh-id-ed25519.age";
        mode = "600";
        owner = "${user}";
        group = "staff";
      };

      # SSH public keys
      "ssh-id-rsa-pub" = {
        symlink = true;
        path = "/Users/${user}/.ssh/id_rsa.pub";
        file = "${secrets}/ssh-id-rsa-pub.age";
        mode = "644";
        owner = "${user}";
        group = "staff";
      };

      "ssh-id-ed25519-pub" = {
        symlink = true;
        path = "/Users/${user}/.ssh/id_ed25519.pub";
        file = "${secrets}/ssh-id-ed25519-pub.age";
        mode = "644";
        owner = "${user}";
        group = "staff";
      };

      # Phone number for scripts
      "phone-number" = {
        symlink = true;
        path = "/Users/${user}/.phone_number";
        file = "${secrets}/phone-number.age";
        mode = "600";
        owner = "${user}";
        group = "staff";
      };

      # Armenian phone number for scripts
      "phone-number-am" = {
        symlink = true;
        path = "/Users/${user}/.phone_number_am";
        file = "${secrets}/phone-number-am.age";
        mode = "600";
        owner = "${user}";
        group = "staff";
      };

      # List of private Instaffo GitLab repos to check out (one path per line,
      # relative to gitlab.com/Instaffo). Kept secret to avoid leaking the
      # private group structure into this public config.
      "instaffo-repos" = {
        symlink = true;
        path = "/Users/${user}/.config/instaffo-repos";
        file = "${secrets}/instaffo-repos.age";
        mode = "600";
        owner = "${user}";
        group = "staff";
      };

      # List of private personal GitHub repos to check out (one owner/repo per
      # line, relative to github.com). Kept secret so private repo names stay
      # out of this public config. Each lands in ~/Projects/<repo-basename>.
      "github-repos" = {
        symlink = true;
        path = "/Users/${user}/.config/github-repos";
        file = "${secrets}/github-repos.age";
        mode = "600";
        owner = "${user}";
        group = "staff";
      };

      # Shared Google OAuth client credentials for the Claude MCP. Pointed at by
      # GOOGLE_OAUTH_CREDENTIALS in ~/.secrets-env and used by both @a-bonus
      # google-docs-mcp profiles (google-private and google-work). Name kept for
      # the existing .age file; it is no longer calendar-specific.
      "google-calendar-credentials" = {
        symlink = true;
        path = "/Users/${user}/.claude/.google-calendar-credentials.json";
        file = "${secrets}/google-calendar-credentials.age";
        mode = "600";
        owner = "${user}";
        group = "staff";
      };

      # Self-contained script (keychain extraction inlined) that pushes the
      # Claude OAuth token to the claude-orchestrator GitLab CI/CD variables.
      # Run hourly by the com.patrick.claude-oauth-gitlab launchd agent.
      "claude-oauth-gitlab" = {
        symlink = false;
        path = "/Users/${user}/.claude/set-oauth-token-gitlab.sh";
        file = "${secrets}/claude-oauth-gitlab.age";
        mode = "700";
        owner = "${user}";
        group = "staff";
      };

      # Personal bio context read at runtime by the
      # anki-sami-german-vocab-builder agent. Kept out of the public agent
      # prompt so private details about Patrick and Sami stay encrypted.
      "anki-personal-context" = {
        symlink = true;
        path = "/Users/${user}/.claude/.anki-personal-context.md";
        file = "${secrets}/anki-personal-context.age";
        mode = "600";
        owner = "${user}";
        group = "staff";
      };
    };
  };

  # Example: GitHub signing key (commented out for now)
  # age.secrets."github-signing-key" = {
  #   symlink = false;
  #   path = "/Users/${user}/.ssh/pgp_github.key";
  #   file =  "${secrets}/github-signing-key.age";
  #   mode = "600";
  #   owner = "${user}";
  # };

}
