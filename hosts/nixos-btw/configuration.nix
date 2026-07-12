{ self, config, lib, pkgs, ... }:

{
  imports = [
      ./hardware-configuration.nix
      (self + "/modules/system/audio.nix")
      (self + "/modules/system/desktop.nix")
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  services.getty.autologinUser = "nixosusername";

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  time.timeZone = "Asia/Jakarta";


  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };
  nixpkgs.config = {
    allowUnfree = true;
  };


  programs.zsh.enable = true;
  users.users.nixosusername = {
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
    ripgrep
    fd
  ];

  stylix.enable = true;
  stylix.image = self + "/config/hypr/wallpaper.png";
  stylix.polarity = "dark";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "26.05";

}
