{ pkgs }:

with pkgs;
[
  # Core System Utilities
  bash-completion
  coreutils
  killall
  moreutils
  openssh
  speedtest-cli
  sqlite
  wget
  zip
  unrar
  unzip
  xz
  zstd
  pkg-config
  gnumake
  libgit2

  # Terminal & Shell
  alacritty
  astroterm
  ncurses
  zsh
  tmux
  tmuxinator
  bat
  eza
  htop
  btop
  tree
  tldr

  # Editor & Development Environment
  claude-code
  codex
  opencode
  mcp-proxy
  neovim
  tree-sitter

  # Nix Development Tools
  nixfmt
  deadnix
  statix
  nix-prefetch-github

  # Prose & Documentation Linters
  vale

  # Search & Navigation
  ripgrep
  fd
  fzf
  watch
  scc

  # Version Control & Project Management
  delta
  gh
  glab
  lazygit
  direnv
  git-lfs
  mise

  # Cloud & Infrastructure
  kubectl
  kubernetes
  kubernetes-helm
  kubernetes-helmPlugins.helm-secrets
  google-cloud-sdk
  doctl
  k9s

  # Programming Languages & Runtimes
  bun
  nodejs_24
  pnpm
  portless
  yarn
  typescript
  typescript-language-server
  (python312.withPackages (
    ps: with ps; [
      pip
      python-gitlab
      pyyaml
    ]
  ))
  uv
  rustup

  # Database & Data Tools
  mysql84
  libmysqlclient
  jq
  yq

  # Media & Content Tools
  freeflow
  iina
  pear-desktop
  ffmpeg
  yt-dlp
  imagemagick
  optipng
  ghostscript
  poppler-utils

  # AI & Image Generation
  stable-diffusion-cpp
  python313Packages.huggingface-hub

  # Security & Encryption
  age
  age-plugin-yubikey
  gnupg
  libfido2
  sops

  # macOS System Tools
  mas
  switchaudio-osx

  # Fonts
  dejavu_fonts
  font-awesome
  hack-font
  jetbrains-mono
  nerd-fonts.fira-code
  noto-fonts
  noto-fonts-color-emoji
  meslo-lgs-nf
]
