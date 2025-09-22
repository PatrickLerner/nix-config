{ pkgs }:

with pkgs; [
  # Core System Utilities
  bash-completion
  coreutils
  killall
  openssh
  sqlite
  wget
  zip
  unrar
  unzip
  zstd
  pkg-config
  gnumake

  # Terminal & Shell
  alacritty
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
  claude-code

  # Nix Development Tools
  nixfmt-classic
  deadnix
  statix

  # Search & Navigation
  ripgrep
  fd
  fzf
  watch

  # Version Control & Project Management
  gh
  lazygit
  direnv
  git-lfs

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
  rustup
  rbenv

  # Database & Data Tools
  mysql84
  libmysqlclient
  jq
  yq

  # Media & Content Tools
  iina
  yt-dlp
  ffmpeg
  imagemagick
  optipng

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
  dockutil

  # Fonts
  dejavu_fonts
  font-awesome
  hack-font
  jetbrains-mono
  noto-fonts
  noto-fonts-emoji
  meslo-lgs-nf
]
