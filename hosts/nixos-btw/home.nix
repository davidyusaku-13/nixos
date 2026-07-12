{ self, config, pkgs, lib, ... }:

{
  home.username = "david";
  home.homeDirectory = "/home/david";
  home.stateVersion = "26.05";
  programs.git = {
    enable = true;
    userName = "David Yusaku";
    userEmail = "davidyusaku13@gmail.com";
  };
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    shellAliases = {
      btw = "echo i use nixos, btw";
      rb = "sudo nixos-rebuild switch --flake ~/nixos-dotfiles#nixos-btw";
      sr = "sudo reboot";
      gp = "git pull";
      gf = "git fetch";
      gs = "git status";
    };
    profileExtra = ''
      if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
        exec start-hyprland
      fi
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" ];
      theme = "robbyrussell";
    };
  };


  programs = {
    alacritty.enable = true;
    waybar.enable = true;
    neovim.enable = true;
    wofi.enable = true;
  };

  xdg.configFile = lib.genAttrs [
    "hypr"
    "waybar"
    "alacritty"
    "nvim"
    "wofi"
  ] (app: { source = self + "/config/${app}"; });

  home.packages = with pkgs; [
    (pkgs.writeShellApplication {
      name = "ns";
      runtimeInputs = with pkgs; [
        fzf
        nix-search-tv
      ];
      text = builtins.readFile "${pkgs.nix-search-tv.src}/nixpkgs.sh";
    })
    kitty
    kdePackages.dolphin
    hyprpaper
    grim
    slurp
    wl-clipboard
    brightnessctl
    gopls
    svelte-language-server
    astro-language-server
    waypaper
    swayosd
    go
    nodejs
    bun
    imv
    libreoffice
    wayvnc
    uv
  ];
}
