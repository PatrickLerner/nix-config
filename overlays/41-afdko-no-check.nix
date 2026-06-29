final: prev:
let
  # The font build chain (jetbrains-mono, noto-fonts-color-emoji →
  # gftools → afdko/cffsubr) has no cached aarch64-darwin build, so it
  # compiles from source. afdko's pytest suite shells out to
  # makeotf/addfeatures and fails 93 tests in the Nix sandbox. The built
  # binaries are fine; only the test phase is broken.
  #
  # These packages are pulled through the Python *interpreter scope*
  # (python313.pkgs), NOT the top-level python313Packages set, so a plain
  # overrideScope does nothing here. Override the interpreter's
  # packageOverrides so the fonts pick up the patched derivations.
  noCheck = _: pyPrev: {
    afdko = pyPrev.afdko.overridePythonAttrs (_: {
      doCheck = false;
      pythonImportsCheck = [ ];
    });
    cffsubr = pyPrev.cffsubr.overridePythonAttrs (_: {
      doCheck = false;
      pythonImportsCheck = [ ];
    });
  };
in
{
  python313 = prev.python313.override (old: {
    packageOverrides = prev.lib.composeExtensions (old.packageOverrides or (_: _: { })) noCheck;
  });
}
