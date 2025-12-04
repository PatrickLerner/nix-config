_: super:
with super; {
  mcp-gitlab = buildNpmPackage rec {
    pname = "mcp-gitlab";
    version = "2.0.13";

    src = fetchFromGitHub {
      owner = "zereight";
      repo = "gitlab-mcp";
      rev = "3f33859d7a6db680cb41c7e490eaaa3c7aa4dab2"; # v2.0.13
      hash = "sha256-l/R5na0fecE7+qeDUW4XK7McNUyONMCKEo8KY2zZ2QU=";
    };

    # npm dependencies hash calculated from lockfile
    npmDepsHash = "sha256-eSKWr+dWrMf19Xb+5eKI4ZkBLTH09qysj+4rxpjWrSE=";

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
