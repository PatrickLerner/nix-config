_:

# let
#  githubPublicKey = "ssh-ed25519 AAAA...";
# in
let
  # Neovim configuration files list
  nvimConfigs = [
    "init.lua"
    "lua/config/options.lua"
    "lua/config/keymaps.lua"
    "lua/config/autocmds.lua"
    "lua/config/lazy.lua"
    "lua/plugins/colorscheme.lua"
    "lua/plugins/telescope.lua"
    "lua/plugins/treesitter.lua"
    "lua/plugins/lsp.lua"
    "lua/plugins/completion.lua"
    "lua/plugins/git.lua"
    "lua/plugins/editor.lua"
    "lua/plugins/lightline.lua"
    "lua/plugins/ale.lua"
  ];

  # Karabiner complex modifications list
  karabinerModifications =
    [ "1645224986.json" "1648966720.json" "1524263232.json" "1648967236.json" ];

  # Generate neovim config files
  nvimFiles = builtins.listToAttrs (map (path: {
    name = ".config/nvim/${path}";
    value = { text = builtins.readFile ../shared/config/nvim/${path}; };
  }) nvimConfigs);

  # Generate karabiner complex modifications
  karabinerFiles = builtins.listToAttrs (map (file: {
    name = ".config/karabiner/assets/complex_modifications/${file}";
    value = {
      text = builtins.readFile
        ../shared/config/karabiner/assets/complex_modifications/${file};
    };
  }) karabinerModifications);

in {
  # ".ssh/id_github.pub" = {
  #   text = githubPublicKey;
  # };

  # Tmuxinator configuration
  ".config/tmuxinator/instaffo.yml" = {
    text = builtins.readFile ../shared/config/tmuxinator/instaffo.yml;
  };

  # Global gitignore
  ".gitignore_global" = {
    text = builtins.readFile ../shared/config/gitignore_global;
  };

  # Empty hushlogin file to suppress login messages
  ".hushlogin" = { text = builtins.readFile ../shared/config/hushlogin; };

  # Git configuration with corrected name and email
  ".gitconfig" = { text = builtins.readFile ../shared/config/gitconfig; };

  # Karabiner configuration
  ".config/karabiner/karabiner.json" = {
    text = builtins.readFile ../shared/config/karabiner/karabiner.json;
  };

  # Alacritty configuration
  ".config/alacritty/alacritty.toml" = {
    text = builtins.readFile ../shared/config/alacritty.toml;
  };

  # Bin scripts
  ".bin/copy-my-phone-number.sh" = {
    text = builtins.readFile ../shared/bin/copy-my-phone-number.sh;
    executable = true;
  };
  ".bin/switch-to-headphones.sh" = {
    text = builtins.readFile ../shared/bin/switch-to-headphones.sh;
    executable = true;
  };
  ".bin/switch-to-speaker.sh" = {
    text = builtins.readFile ../shared/bin/switch-to-speaker.sh;
    executable = true;
  };
  ".bin/toggle_audio_run.sh" = {
    text = builtins.readFile ../shared/bin/toggle_audio_run.sh;
    executable = true;
  };
  ".bin/error_sound" = {
    text = builtins.readFile ../shared/bin/error_sound;
    executable = true;
  };

  # Zsh configuration files
  ".config/zsh/shrink-path.zsh" = {
    text = builtins.readFile ../shared/config/shrink-path.zsh;
  };
} // nvimFiles // karabinerFiles
