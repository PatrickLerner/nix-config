_: super: with super; {

  freeflow = stdenv.mkDerivation rec {
    pname = "freeflow";
    version = "1.0.0";

    src = fetchurl {
      url = "https://github.com/zachlatta/freeflow/releases/download/v${version}/FreeFlow.dmg";
      hash = "sha256-MrG4J4Y4E8xZAllLvA4PmlWwyeOvelwmrF6R9kV6DQ8=";
    };

    nativeBuildInputs = [ undmg ];
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      cp -R FreeFlow.app "$out/Applications/"
      runHook postInstall
    '';

    meta = with lib; {
      description = "Free and open source alternative to Wispr Flow";
      homepage = "https://github.com/zachlatta/freeflow";
      license = licenses.mit;
      platforms = platforms.darwin;
    };
  };
}
