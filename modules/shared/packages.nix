{ pkgs }:

with pkgs; [
  # Core System Utilities
  bash-completion
  coreutils
  killall
  moreutils
  openssh
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
  neovim

  # Nix Development Tools
  nixfmt
  deadnix
  statix
  nix-prefetch-github

  # Search & Navigation
  ripgrep
  fd
  fzf
  watch
  scc

  # Version Control & Project Management
  delta
  gh
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
  nodejs_24
  pnpm
  yarn
  typescript
  typescript-language-server
  (python312.withPackages (ps: with ps; [ pip python-gitlab pyyaml ]))
  uv
  mcp-gitlab
  rustup
  rbenv

  # Database & Data Tools
  mysql84
  libmysqlclient
  jq
  yq

  # Media & Content Tools
  iina
  pear-desktop
  yt-dlp
  ffmpeg
  imagemagick
  optipng
  ghostscript
  poppler-utils

  # Security & Encryption
  age
  age-plugin-yubikey
  gnupg
  libfido2
  sops

  # macOS System Tools
  mas
  karabiner-elements
  switchaudio-osx

  # Fonts
  dejavu_fonts
  font-awesome
  hack-font
  jetbrains-mono
  noto-fonts
  noto-fonts-color-emoji
  meslo-lgs-nf
]
