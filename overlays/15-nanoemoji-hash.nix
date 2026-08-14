# Workaround: upstream GitHub re-generated the googlefonts/nanoemoji v0.16.0
# release archive, so nixpkgs' pinned source hash no longer matches. Re-point
# the source at the same tag with the corrected hash. Applied via
# pythonPackagesExtensions so every Python interpreter's nanoemoji (and the
# top-level alias) picks up the fix — gftools -> jetbrains-mono depend on it.
# Remove this overlay once nixpkgs ships the corrected hash.
final: prev:
{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (
      _py-final: py-prev: {
        nanoemoji = py-prev.nanoemoji.overrideAttrs (_old: {
          src = final.fetchFromGitHub {
            owner = "googlefonts";
            repo = "nanoemoji";
            tag = "v0.16.0";
            hash = "sha256-FysyKC01XBnRiur5RR9fcsTxQqE8x0JJHSoe3q6JtKc=";
          };
        });
      }
    )
  ];
}
