_: super: with super; {

  # Not in nixpkgs. Published as an npm tarball with all deps bundled into
  # dist/ (esbuild), so there are no node_modules to fetch — just wrap the
  # bundled ESM CLI with node 24 (its declared engine).
  portless = stdenv.mkDerivation rec {
    pname = "portless";
    version = "0.14.0";

    src = fetchurl {
      url = "https://registry.npmjs.org/portless/-/portless-${version}.tgz";
      hash = "sha256-fRBPzQWq4aKUQPZbk222OR6MOoV7irG0BmsMI0KDMZc=";
    };

    nativeBuildInputs = [ makeWrapper ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/portless"
      cp -R . "$out/lib/portless/"
      makeWrapper ${nodejs_24}/bin/node "$out/bin/portless" \
        --add-flags "$out/lib/portless/dist/cli.js"
      runHook postInstall
    '';

    meta = with lib; {
      description = "Replace port numbers with stable, named .localhost URLs";
      homepage = "https://github.com/vercel-labs/portless";
      license = licenses.mit;
      mainProgram = "portless";
      platforms = platforms.unix;
    };
  };
}
