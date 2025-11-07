# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About This Configuration

This is a customized version of [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config), adapted specifically for macOS development environments using Nix Flakes. This configuration has been streamlined to focus exclusively on Darwin/macOS systems.

## Prerequisites

Before working with this configuration:

1. **Xcode Command Line Tools**: `xcode-select --install`
2. **Nix with Flakes**: Install using Determinate Systems installer
3. **Experimental Features**: Ensure `experimental-features = nix-command flakes` is enabled

## Common Commands

This repository uses Nix flakes with custom apps for system management. All commands are run via `nix run`:

### macOS (Darwin) Commands

- `nix run .#build` - Build the Darwin configuration without switching
- `nix run .#build-switch` - Build and switch to the new Darwin configuration (requires sudo)
- `nix run .#clean` - Clean up old system generations (older than 7 days)
- `nix run .#rollback` - Rollback to a previous system generation (interactive selection)
- `nix run .#check-keys` - Verify required SSH keys are present (id_ed25519, id_ed25519_agenix)
- `nix run .#copy-keys` - Copy SSH keys (part of setup process)
- `nix run .#create-keys` - Generate required SSH keys

### Development Shell

- `nix develop` - Enter development shell with git, age, and age-plugin-yubikey

### Linting and Code Quality

- `./lint.sh` - Run Nix linters (nixfmt for formatting, deadnix for unused code, statix for static analysis)

## Architecture Overview

This is a **Darwin-focused Nix flake configuration** optimized specifically for macOS development environments using nix-darwin and a streamlined module system.

### Flake Structure

- **Inputs**: Uses nixpkgs-unstable, nix-darwin, home-manager, agenix, nix-homebrew
- **Outputs**: Provides `darwinConfigurations` for macOS only
- **Apps**: Custom scripts in `apps/aarch64-darwin/` directory expose system management commands
- **User**: Hardcoded to user "patrick" throughout the configuration

### Key Design Principles

1. **Shared Configuration**: Common packages and settings in `modules/shared/`
2. **Darwin Integration**: macOS-specific config in `modules/darwin/` and `hosts/darwin/`
3. **Secrets Management**: Uses agenix for encrypted secrets with YubiKey support
4. **Homebrew Integration**: nix-homebrew manages macOS-specific GUI applications
5. **Simplified Structure**: Consolidated modules for better maintainability

## Module Organization

### `modules/shared/`

Contains core configuration used across the system:

- `packages.nix` - All Nix packages organized by category (development tools, CLI utilities, fonts, etc.)
- `home-manager.nix` - User-level configuration (shell, git, tmux, ssh, etc.)
- `files.nix` - Static configuration files with automated generation for Neovim and Karabiner configs
- `config/` - Non-Nix configuration files (alacritty, nvim, karabiner, tmuxinator, etc.)

### `modules/darwin/`

macOS-specific configuration:

- `casks.nix` - Homebrew cask applications organized by category (browsers, development, productivity, etc.)
- `dock/` - macOS dock configuration
- `home-manager.nix` - Darwin-specific user configuration, dock management, and activation hooks
- `secrets.nix` - agenix secret definitions for macOS

### Home-Manager Activation Hooks

Activation scripts in `modules/darwin/home-manager.nix` run automatically after each home-manager activation:

```nix
home.activation.scriptName = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  # Shell commands here run after home-manager files are written
  # Use full Nix store paths: ${pkgs.package-name}/bin/command
  echo "Running custom activation..."
'';
```

Example: Claude MCP server setup hook automatically configures MCP servers on each activation.

### Host Configuration

- `hosts/darwin/default.nix` - Main Darwin system configuration with macOS defaults, nixpkgs config, and overlays

## Package Management Strategy

### Nix Packages (`modules/shared/packages.nix`)

CLI tools, development environments, and cross-platform software organized by clear categories. See the source file for the complete list of packages including:

- Core System Utilities (bash-completion, coreutils, openssh, etc.)
- Terminal & Shell tools (alacritty, zsh, tmux, bat, eza, etc.)
- Development environments (neovim, claude-code, nodejs, rust, etc.)
- Cloud & Infrastructure tools (docker, kubernetes, aws tools, etc.)
- Security & Encryption tools (age, gnupg, yubikey support, etc.)
- System fonts and utilities

### Homebrew Casks (`modules/darwin/casks.nix`)

macOS-specific GUI applications organized by category. See the source file for the complete list including:

- Development Tools (docker, zed)
- Browsers (firefox, google-chrome, microsoft-edge)
- Communication & Social (discord, slack, telegram, whatsapp, zoom)
- Productivity & Utilities (raycast, 1password, etc.)
- Media & Content Creation (audacity, obs, spotify, vlc)
- Security & Privacy tools

### Homebrew Formulas (`modules/darwin/home-manager.nix`)

Command-line tools installed via Homebrew that aren't available in nixpkgs:

- `openai-whisper` - Speech recognition and transcription
- `gitlab-gem` - GitLab CLI tool
- `aws-auth` - AWS authentication helper
- `aws-console` - AWS console utilities
- `aws-iam-authenticator` - AWS IAM authenticator
- `awscli` - AWS command line interface

## Secrets Management

Uses **agenix** for encrypted secrets with YubiKey support:

### Configuration

- Identity path: `/Users/patrick/.ssh/id_ed25519`
- Secrets repository: `git+ssh://git@github.com/PatrickLerner/nix-secrets.git`
- Required SSH keys: `id_ed25519`, `id_ed25519.pub`, `id_ed25519_agenix`, `id_ed25519_agenix.pub`
- Use `check-keys` command to verify keys are present

### Workflow

1. Create secrets in private repository with `secrets.nix` defining public keys
2. Create encrypted secrets: `EDITOR=vim nix run github:ryantm/agenix -- -e secret.age`
3. Reference secrets in `modules/darwin/secrets.nix` with symlink paths
4. Secrets are automatically decrypted and symlinked during system build

### Apply Script Integration

The `apply` command automatically:

- Prompts for GitHub username and secrets repository name
- Inserts secrets repository URL into flake.nix inputs
- Updates flake.nix outputs to include secrets parameter
- Templates the repository URL throughout configuration files

## Overlays

Files in `overlays/` automatically run as part of each build for:

- Applying patches
- Version overrides or forks
- Temporary workarounds

### Creating Custom Package Overlays

When adding npm/pnpm packages that aren't in nixpkgs:

1. **Create overlay file**: `overlays/##-package-name.nix` (numbered for load order)
2. **Git tracking required**: New overlay files MUST be `git add`ed before building - Nix uses git tree and won't see untracked files
3. **For npm packages**: Use `buildNpmPackage` with `npmDepsHash = lib.fakeHash`, build to get real hash
4. **For pnpm packages**: Use `stdenv.mkDerivation` with `pnpm_9.fetchDeps`:
   ```nix
   pnpmDeps = pnpm_9.fetchDeps {
     inherit pname version src;
     hash = lib.fakeHash;  # Build once to get real hash
     fetcherVersion = 2;    # Must be 1 or 2
   };
   nativeBuildInputs = [ nodejs_24 pnpm_9.configHook ];
   ```
5. **Add to packages**: Reference the overlay package in `modules/shared/packages.nix`
6. **Hash workflow**: Use `lib.fakeHash` initially, build will fail with correct hash to use

Example: See `overlays/30-mcp-figma.nix` for pnpm package or `overlays/20-mcp-gitlab.nix` for npm package.

## System Management

### Building and Switching

- Always use `build-switch` for applying configuration changes
- `build` command tests without switching (useful for validation)
- System automatically rebuilds with `sudo` elevation as required

### Maintenance

- Regular cleanup with `clean` command removes generations older than 7 days
- `rollback` provides interactive generation selection for system recovery
- Automatic garbage collection configured to run weekly

### Initial Setup

- Run `apply` command to configure user details and secrets repository
- This script templates user information throughout the configuration
- Requires GitHub username and secrets repository name

## Troubleshooting

### Common Issues

1. **Experimental Features Not Enabled**: Ensure `experimental-features = nix-command flakes` in Nix configuration
2. **File Conflicts**: During installation, backup existing `/etc/` configuration files that conflict
3. **SSH Key Permissions**: Ensure SSH keys have correct permissions (600 for private keys)
4. **Git Configuration**: Apply script pulls git user.name and user.email, configure git before running
5. **Darwin Rebuild Sudo**: The `build-switch` command requires sudo for system-level changes. DO NOT run this command as Claude - it requires password input. User must run it manually.
6. **System Deprecation Warning**: Use `stdenv.hostPlatform.system` instead of deprecated `system` attribute (e.g., `${pkgs.stdenv.hostPlatform.system}` not `${pkgs.system}`)

### File Template Variables

The apply script replaces these variables throughout the configuration:

- `%USER%` - System username
- `%EMAIL%` - Git email address
- `%NAME%` - Git full name
- `%GITHUB_USER%` - GitHub username
- `%GITHUB_SECRETS_REPO%` - Private secrets repository name
