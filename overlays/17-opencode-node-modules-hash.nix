# nixpkgs' opencode node_modules hash doesn't match on darwin. Remove once
# nixpkgs ships a working hash (or opencode lands in the binary cache).
_final: prev: {
  opencode = prev.opencode.overrideAttrs (old: {
    node_modules = old.node_modules.overrideAttrs {
      outputHash = "sha256-dIveiaiPFGSItwLyeMuPDxTE9gpvvnlTCB/+nG24qCc=";
    };
  });
}
