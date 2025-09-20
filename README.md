# Patrick's Nix Configuration for macOS

A declarative macOS development environment using Nix Flakes, based on [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config) but streamlined specifically for Darwin/macOS systems.

**Note**: This configuration is personalized for user "patrick" and is not intended to be reusable as a template.

## Features

- **Declarative System Configuration**: Everything defined in code using Nix Flakes
- **Automated Software Management**:
  - **Nix packages**: CLI tools, development environments, fonts
  - **Homebrew**: GUI applications and some CLI tools
  - **Mac App Store**: Apps managed via `mas` tool
- **Dotfile Management**: Automated deployment of configuration files (zsh, tmux, neovim, karabiner, etc.)
- **Encrypted Secrets**: Secure secret management with agenix and YubiKey support
- **macOS System Defaults**: Automated configuration of system preferences
- **Automatic Cleanup**: Removes unlisted Homebrew packages to keep system clean

## Quick Start

### Prerequisites

1. **Xcode Command Line Tools**: `xcode-select --install`
2. **Nix with Flakes**: Install using [Determinate Systems installer](https://install.determinate.systems/)
3. **Enable Flakes**: Ensure `experimental-features = nix-command flakes` is enabled

### Installation

```bash
# Clone the repository
git clone https://github.com/PatrickLerner/nix-config.git
cd nix-config

# Build and apply the configuration
nix run .#build-switch
```

## Management Commands

| Command | Description |
|---------|-------------|
| `nix run .#build` | Test build without switching (safe) |
| `nix run .#build-switch` | Build and apply configuration (requires sudo) |
| `nix run .#clean` | Remove old system generations (7+ days) |
| `nix run .#rollback` | Rollback to previous generation (interactive) |
| `nix run .#check-keys` | Verify required SSH keys |
| `nix run .#create-keys` | Generate SSH keys |
| `nix develop` | Enter development shell |

## Configuration Files

The system configuration is organized across these key files:

- **[modules/shared/packages.nix](modules/shared/packages.nix)** - Nix packages (CLI tools, development environments)
- **[modules/darwin/casks.nix](modules/darwin/casks.nix)** - Homebrew GUI applications
- **[modules/darwin/home-manager.nix](modules/darwin/home-manager.nix)** - Homebrew formulas and Mac App Store apps
- **[modules/shared/home-manager.nix](modules/shared/home-manager.nix)** - Shell, git, tmux, and user configuration
- **[modules/shared/config/](modules/shared/config/)** - Application-specific configuration files
- **[hosts/darwin/default.nix](hosts/darwin/default.nix)** - macOS system settings and defaults

## Customization

### Adding Software
- **Nix packages**: Edit `modules/shared/packages.nix`
- **Homebrew casks**: Edit `modules/darwin/casks.nix`
- **Homebrew formulas**: Edit `modules/darwin/home-manager.nix` brews array
- **Mac App Store**: Edit `modules/darwin/home-manager.nix` masApps

### Modifying Configurations
- **Shell & Terminal**: `modules/shared/home-manager.nix`
- **Application configs**: `modules/shared/config/`
- **macOS settings**: `hosts/darwin/default.nix`
- **Dock**: `modules/darwin/dock/`

## Resources

### Package Search
- **Homebrew Casks**: https://formulae.brew.sh/cask/
- **Nix Packages**: https://search.nixos.org/packages
- **Mac App Store**: Use `mas search <app name>` after installation

### Documentation
- **Detailed Configuration Guide**: See [CLAUDE.md](./CLAUDE.md)
- **Original Template**: [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config)

## Troubleshooting

### Common Issues
- **Build Failures**: Try `nix run .#clean` then rebuild
- **Permission Errors**: Ensure SSH keys have correct permissions (600)
- **Homebrew Conflicts**: The system automatically removes unlisted packages
- **System Recovery**: Use `nix run .#rollback` to restore previous state

### Getting Help
- Check existing issues in the original template repository
- Verify Nix experimental features are enabled
- Ensure Git user.name and user.email are configured before running apply

