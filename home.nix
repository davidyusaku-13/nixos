{ config, pkgs, ... }:

{
  home.username = "david";
  home.homeDirectory = "/home/david";
  home.stateVersion = "26.05";
  programs.git.enable = true;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
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
    initExtra = ''
      afetch
    '';
  };

  home.file = builtins.listToAttrs (map (app: {
    name = ".config/${app}";
    value = { source = ./. + "/config/${app}"; force = true; };
  }) [ "hypr" "waybar" "alacritty" "nvim" "wofi" ]);

  home.packages = with pkgs; [
    (pkgs.writeShellApplication {
      name = "ns";
      runtimeInputs = with pkgs; [
        fzf
        nix-search-tv
      ];
      text = builtins.readFile "${pkgs.nix-search-tv.src}/nixpkgs.sh";
    })
  ];
}
