_: super:
with super; {

  mcp-proxy = python3Packages.buildPythonApplication rec {
    pname = "mcp-proxy";
    version = "0.11.0";
    pyproject = true;

    src = fetchPypi {
      pname = "mcp_proxy";
      inherit version;
      hash = "sha256-NCTssfV/gXRiXd/w3xW1NKCHGdh89fnWorHgON5pafE=";
    };

    build-system = with python3Packages; [ setuptools ];

    dependencies = with python3Packages; [
      # httpx-auth's nixpkgs test suite is flaky against current pyjwt
      # (treats InsecureKeyLengthWarning as an error). Skip its tests.
      (httpx-auth.overridePythonAttrs (_: { doCheck = false; }))
      mcp
      uvicorn
    ];

    pythonImportsCheck = [ "mcp_proxy" ];

    meta = with lib; {
      description =
        "Bridge between Streamable HTTP and stdio MCP transports";
      homepage = "https://github.com/sparfenyuk/mcp-proxy";
      license = licenses.mit;
      mainProgram = "mcp-proxy";
      platforms = platforms.unix;
    };
  };
}
