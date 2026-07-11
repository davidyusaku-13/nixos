{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.graphics.enable = true;

  services.getty.autologinUser = "david";

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Jakarta";
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };


  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };
  nixpkgs.config = {
    allowUnfree = true;
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.zsh.enable = true;
  users.users.david = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "input" "networkmanager" ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      tree
    ];
  };

  programs.firefox.enable = true;
  environment.systemPackages = with pkgs; [
    neovim
    wget
    alacritty
    waybar
    kitty
    wofi
    kdePackages.dolphin
    hyprpaper
    grim
    slurp
    wl-clipboard
    ripgrep
    fd
    brightnessctl
    gopls
    svelte-language-server
    astro-language-server
    waypaper
    swayosd
    go
    nodejs
    bun
    uv
    fastfetch
  ];

  fonts.packages = with pkgs; [
    font-awesome
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "26.05";

}
