package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/huh"
)

func main() {
	if os.Geteuid() != 0 {
		fmt.Println("Please run as root (sudo)")
		os.Exit(1)
	}

	// 1. Fetch drives
	drivesOutput, err := exec.Command("bash", "-c", "lsblk -d -n -o NAME,SIZE,MODEL | grep -v loop").Output()
	if err != nil {
		fmt.Println("Error fetching drives:", err)
		os.Exit(1)
	}
	
	driveLines := strings.Split(strings.TrimSpace(string(drivesOutput)), "\n")
	var driveOptions []huh.Option[string]
	for _, line := range driveLines {
		if line == "" {
			continue
		}
		parts := strings.Fields(line)
		if len(parts) > 0 {
			driveOptions = append(driveOptions, huh.NewOption(line, parts[0]))
		}
	}

	if len(driveOptions) == 0 {
		fmt.Println("No drives found!")
		os.Exit(1)
	}

	// State variables
	var (
		driveName       string
		confirm         bool
		targetUser      = "nixosusername"
		gitName         = "gitconfig"
		gitEmail        = "gitconfig@mail.com"
		rootPass        string
		rootPassConfirm string
		userPass        string
		userPassConfirm string
	)

	// 2. Build the Form
	form := huh.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Select Drive to Format").
				Description("WARNING: All data will be erased!").
				Options(driveOptions...).
				Value(&driveName),
			huh.NewConfirm().
				Title("Are you absolutely sure?").
				Affirmative("Yes, wipe the drive").
				Negative("No, abort").
				Value(&confirm),
		),
		huh.NewGroup(
			huh.NewInput().
				Title("System Username").
				Value(&targetUser),
			huh.NewInput().
				Title("Git Full Name").
				Value(&gitName),
			huh.NewInput().
				Title("Git Email").
				Value(&gitEmail),
		).WithHideFunc(func() bool { return !confirm }),
		huh.NewGroup(
			huh.NewInput().
				Title("Root Password").
				EchoMode(huh.EchoModePassword).
				Value(&rootPass),
			huh.NewInput().
				Title("Confirm Root Password").
				EchoMode(huh.EchoModePassword).
				Value(&rootPassConfirm).
				Validate(func(v string) error {
					if v != rootPass {
						return errors.New("passwords do not match")
					}
					return nil
				}),
			huh.NewInput().
				Title("User Password").
				EchoMode(huh.EchoModePassword).
				Value(&userPass),
			huh.NewInput().
				Title("Confirm User Password").
				EchoMode(huh.EchoModePassword).
				Value(&userPassConfirm).
				Validate(func(v string) error {
					if v != userPass {
						return errors.New("passwords do not match")
					}
					return nil
				}),
		).WithHideFunc(func() bool { return !confirm }),
	)

	err = form.Run()
	if err != nil {
		fmt.Println("Installation aborted.")
		os.Exit(1)
	}

	if !confirm {
		fmt.Println("Aborted by user.")
		os.Exit(0)
	}

	drive := "/dev/" + driveName
	fmt.Printf("\n==> Starting installation on %s...\n", drive)

	partBoot := drive + "1"
	partRoot := drive + "2"
	if strings.Contains(drive, "nvme") || strings.Contains(drive, "mmcblk") {
		partBoot = drive + "p1"
		partRoot = drive + "p2"
	}

	// 3. Execution Script
	script := fmt.Sprintf(`
set -e
echo "==> Cleaning up previous mounts (if any)..."
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

echo "==> Partitioning %s..."
parted -s "%s" -- mklabel gpt
parted -s "%s" -- mkpart ESP fat32 1MiB 1024MiB
parted -s "%s" -- set 1 esp on
parted -s "%s" -- mkpart primary ext4 1024MiB 100%%

echo "==> Formatting partitions..."
mkfs.fat -F 32 -n BOOT "%s"
mkfs.ext4 -L nixos "%s"

echo "==> Mounting partitions..."
mount "%s" /mnt
mount --mkdir "%s" /mnt/boot

echo "==> Generating NixOS hardware config..."
nixos-generate-config --root /mnt

echo "==> Cloning dotfiles..."
git clone https://github.com/davidyusaku-13/nixos-dotfiles.git /mnt/etc/nixos-dotfiles

echo "==> Injecting hardware config..."
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos-dotfiles/hosts/nixos-btw/

cd /mnt/etc/nixos-dotfiles

echo "==> Configuring generic placeholders..."
if [ "%s" != "nixosusername" ]; then
  sed -i "s/users\.nixosusername =/users\.%s =/g" flake.nix
  sed -i "s/autologinUser = \"nixosusername\"/autologinUser = \"%s\"/g" hosts/nixos-btw/configuration.nix
  sed -i "s/users\.users\.nixosusername =/users\.users\.%s =/g" hosts/nixos-btw/configuration.nix
  sed -i "s/home\.username = \"nixosusername\"/home\.username = \"%s\"/g" hosts/nixos-btw/home.nix
  sed -i "s/homeDirectory = \"\\/home\\/nixosusername\"/homeDirectory = \"\\/home\\/%s\"/g" hosts/nixos-btw/home.nix
fi

if [ "%s" != "gitconfig" ]; then
  sed -i "s/userName = \"gitconfig\"/userName = \"%s\"/g" hosts/nixos-btw/home.nix
fi

if [ "%s" != "gitconfig@mail.com" ]; then
  sed -i "s/userEmail = \"gitconfig@mail.com\"/userEmail = \"%s\"/g" hosts/nixos-btw/home.nix
fi

git add -A

echo "==> Installing NixOS..."
nixos-install --flake /mnt/etc/nixos-dotfiles#nixos-btw --no-root-passwd

echo "==> Setting passwords..."
nixos-enter --root /mnt -c "echo 'root:%s' | chpasswd"
nixos-enter --root /mnt -c "echo '%s:%s' | chpasswd"

echo "==> Cleaning up..."
umount -R /mnt 2>/dev/null || true

echo "==> Rebooting in 3 seconds..."
sleep 3
reboot
`,
		drive, drive, drive, drive, drive,
		partBoot, partRoot, partRoot, partBoot,
		targetUser, targetUser, targetUser, targetUser, targetUser, targetUser,
		gitName, gitName,
		gitEmail, gitEmail,
		rootPass,
		targetUser, userPass,
	)

	cmd := exec.Command("bash", "-c", script)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		fmt.Printf("\nInstallation failed: %%v\n", err)
		os.Exit(1)
	}

	fmt.Println("\n==> Done! You can now type 'reboot'.")
}
