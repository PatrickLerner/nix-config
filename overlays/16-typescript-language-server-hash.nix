# Workaround: nixpkgs' pinned pnpmDeps hash for typescript-language-server
# 6.0.2 no longer matches what fetchPnpmDeps produces. Remove once nixpkgs
# ships the corrected hash.
final: prev: {
  typescript-language-server = prev.typescript-language-server.overrideAttrs (old: {
    pnpmDeps = final.fetchPnpmDeps {
      inherit (old) pname version src;
      pnpm = final.pnpm_12;
      fetcherVersion = 4;
      hash = "sha256-PmyJb8090pEPc09Tbv8RgdvQpzpba2L8ve87+aVncQU=";
    };
  });
}
