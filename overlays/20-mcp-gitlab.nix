_: super:
with super; {
  mcp-gitlab = buildNpmPackage rec {
    pname = "mcp-gitlab";
    version = "2.0.8";

    src = fetchFromGitHub {
      owner = "zereight";
      repo = "gitlab-mcp";
      rev = "4d66c9316686757eaaddde6be227affc5c3d36cf"; # v2.0.8
      hash = "sha256-EqAVxX4/bCMgtVwvPtHAz3z8D9L+sU3WgORhUlduy2Q=";
    };

    # npm dependencies hash calculated from lockfile
    npmDepsHash = "sha256-OgJKbPub5fDEMlVgXv6rOGPeNtYxkuXZamZcpcIMl3I=";

    # The package uses TypeScript and has a build script
    npmBuildScript = "build";

    # Use nodejs_24 to match the system configuration
    nodejs = nodejs_24;

    # Create a symlink for the scoped package binary
    postInstall = ''
      ln -s $out/bin/@zereight/mcp-gitlab $out/bin/mcp-gitlab
    '';

    meta = with lib; {
      description = "GitLab MCP (Model Context Protocol) Server";
      homepage = "https://github.com/zereight/gitlab-mcp";
      license = licenses.mit;
      maintainers = [ ];
      mainProgram = "mcp-gitlab";
    };
  };
}
