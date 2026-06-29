final: prev: {
  # mise's oci::layer test asserts setuid/setgid bits survive a tar
  # round-trip, but the Nix build sandbox strips special permission bits,
  # so the test can never pass here. The build itself is fine.
  mise = prev.mise.overrideAttrs (_: {
    doCheck = false;
  });
}
