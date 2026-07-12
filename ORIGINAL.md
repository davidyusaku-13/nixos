fetched from https://www.tonybtw.com/tutorial/nixos-hyprland/

# Hyprland on NixOS (w/ UWSM) Installation Guide

_Based on the tutorial by Tony, btw._

This guide provides a quick and painless walkthrough for setting up Hyprland on NixOS, optionally with UWSM (Universal Wayland Session Manager). It utilizes Nix Flakes and Home Manager for a reproducible and unified configuration.

## Prerequisites

Boot into the minimal NixOS installation ISO.

## 1. Partitioning the Disk

First, identify your disk name:

```bash
lsblk
```

_(Assuming the disk is `/dev/vda`)_

Open `cfdisk` to set up partitions:

```bash
cfdisk /dev/vda
```

Create two partitions:

1.  **1GB** - Type: **EFI Filesystem** (Boot partition: `/dev/vda1`)
2.  **Remaining space** - Type: **Linux filesystem** (Root partition: `/dev/vda2`)
    Write the changes and quit.

## 2. Formatting and Mounting Filesystems

Format the partitions:

```bash
mkfs.ext4 -L nixos /dev/vda2
mkfs.fat -F 32 -n BOOT /dev/vda1
```

Mount the partitions:

```bash
mount /dev/vda2 /mnt
mount --mkdir /dev/vda1 /mnt/boot
```

## 3. Initial NixOS Configuration

Generate the initial NixOS configuration file:

```bash
nixos-generate-config --root /mnt
cd /mnt/etc/nixos/
```

### `flake.nix`

Create `flake.nix` to define where packages come from and manage the system/home configurations:

```nix
{
  description = "Hyprland on Nixos";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.nixos-btw = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.tony = import ./home.nix;
            backupFileExtension = "backup";
          };
        }
      ];
    };
  };
}
```

### `configuration.nix`

Edit `configuration.nix`. Ensure your hostnames and timezones match your preferences:

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.getty.autologinUser = "tony";
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Los_Angeles";

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  users.users.tony = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
    ];
  };

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    vim wget foot waybar kitty
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.05";
}
```

### `home.nix`

Set up the user's home configuration:

```nix
{ config, pkgs, ... }:

{
  home.username = "tony";
  home.homeDirectory = "/home/tony";
  home.stateVersion = "25.05";

  programs.git.enable = true;

  programs.bash = {
    enable = true;
    shellAliases = {
      btw = "echo i use nixos, btw";
    };
    profileExtra = ''
      if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
        exec uwsm start -S hyprland-uwsm.desktop
      fi
    '';
  };
}
```

## 4. Installation

Run the installation referencing the flake:

```bash
nixos-install --flake /mnt/etc/nixos#nixos-btw
```

_Note: Make sure to set your password!_

```bash
nixos-enter --root /mnt -c 'passwd tony'
```

Finally, reboot into your new system:

```bash
reboot
```

## 5. Post-Installation Setup

Once booted into Hyprland, open a terminal (`SUPER + Q`) to configure dotfiles.

### Applying Dotfiles

```bash
mkdir -p ~/nixos-dotfiles/config
cd ~/nixos-dotfiles/config

git clone https://github.com/tonybanters/hypr
git clone https://github.com/tonybanters/waybar
git clone https://github.com/tonybanters/foot
```

Update your `home.nix` to source these configurations:

```nix
home.file.".config/hypr".source = ./config/hypr;
home.file.".config/waybar".source = ./config/waybar;
home.file.".config/foot".source = ./config/foot;
```

Apply the changes:

```bash
sudo nixos-rebuild switch --flake ~/nixos-dotfiles#nixos-btw
```

### Nix Search TV

To easily search for packages, add `nix-search-tv` to your `home.nix` packages:

```nix
home.packages = with pkgs; [
  (pkgs.writeShellApplication {
    name = "ns";
    runtimeInputs = with pkgs; [ fzf nix-search-tv ];
    text = builtins.readFile "${pkgs.nix-search-tv.src}/nixpkgs.sh";
  })
];
```

Rebuild again, and you can now run `ns` in your terminal to easily search and jump into Nix shells!
