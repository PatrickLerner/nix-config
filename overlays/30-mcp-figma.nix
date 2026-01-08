_: super:
with super; {
  mcp-figma = super.stdenv.mkDerivation rec {
    pname = "figma-developer-mcp";
    version = "0.6.4";

    src = fetchFromGitHub {
      owner = "GLips";
      repo = "Figma-Context-MCP";
      rev = "c11b1bc7786ef5dbb1e165eb421415d009ca3810"; # v0.6.4
      hash = "sha256-63stXZAaRbMEiPBebtAF4mphiHp5pryWpXuNUKydLFk=";
    };

    nativeBuildInputs = [ nodejs_24 pnpm_9 pnpmConfigHook ];

    pnpmDeps = fetchPnpmDeps {
      inherit pname version src;
      hash = "sha256-l0ht71b9YaS0Eja39u8BWny01z12/ulgS3MCvuYqyKc=";
      fetcherVersion = 2;
    };

    buildPhase = ''
      runHook preBuild
      pnpm build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib/node_modules/${pname}
      cp -r dist node_modules package.json $out/lib/node_modules/${pname}/
      ln -s $out/lib/node_modules/${pname}/dist/bin.js $out/bin/${pname}
      chmod +x $out/bin/${pname}
      runHook postInstall
    '';

    meta = with lib; {
      description =
        "Framelink MCP for Figma - Model Context Protocol server for Figma API";
      homepage = "https://github.com/GLips/Figma-Context-MCP";
      license = licenses.mit;
      maintainers = [ ];
      mainProgram = "figma-developer-mcp";
    };
  };
}
