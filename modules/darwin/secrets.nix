{ secrets, ... }:

let user = "patrick";
in {
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
