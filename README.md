# My Personal Dotfiles

Personal configuration files for Arch Linux, optimized for systems installed via the **Omarchy 3.5.1** script. This setup uses **Hyprland** as the compositor and a heavily customized **Quickshell** interface.

## 🛠 Management with GNU Stow & PKGBUILD

These dotfiles are managed using [GNU Stow](https://www.gnu.org/software/stow/). Stow creates symbolic links from this directory to your home folder, allowing for a centralized and version-controlled configuration. 

Additionally, all personal applications and dependencies are managed declaratively via a custom **PKGBUILD** metapackage, ensuring a clean and reproducible system.

### Directory Structure

- `hyprland/`: Configuration for the Hyprland compositor (`~/.config/hypr`).
- `quickshell/`: Configuration for Quickshell components (`~/.config/quickshell`).
- `whisker/`: Source code/clone for the Whisker Shell.
- `meta-package/`: Contains the `PKGBUILD` with the list of all my essential apps.
- `setup.sh`: Automated script to install dependencies and apply symlinks.

## 🚀 Installation

After a fresh Arch Linux installation, clone this repository to `~/dotfiles`. 

First, install all your essential applications using the custom metapackage, then run the setup script to apply the configurations:

```bash
# 1. Clone the repository
git clone [https://github.com/your-username/dotfiles.git](https://github.com/your-username/dotfiles.git) ~/dotfiles
cd ~/dotfiles

# 2. Install apps via the custom PKGBUILD
cd meta-package
makepkg -si
cd ..

# 3. Apply configurations with Stow
chmod +x setup.sh
./setup.sh
```

The setup script will:
1. Synchronize package databases.
2. Install `stow`, `base-devel`, and `git` (if not already covered by the PKGBUILD).
3. Apply symlinks for Hyprland and Quickshell using Stow.

## 🔄 Maintenance

### Managing Dotfiles
Since all configuration files in `~/.config` are symbolic links pointing back to this repository, you should **always edit the files directly inside `~/dotfiles`**.

To add a new module (e.g., `nvim`):
1. Create the structure: `mkdir -p ~/dotfiles/nvim/.config/nvim`.
2. Move your config there.
3. Run `stow nvim` from the `~/dotfiles` root.

### Managing Applications
To add or remove an application from your system:
1. Edit the `depends=()` array inside `meta-package/PKGBUILD`.
2. Increment the `pkgver` or `pkgrel`.
3. Run `yay -S --needed --noconfirm` again in that directory to apply the changes.
*(To clean up unused apps later, simply remove the metapackage: `sudo pacman -Rns <pkgname>`)*.

## 📚 References & Inspirations

- [snes19xx/surface-dots](https://github.com/snes19xx/surface-dots)
- [ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration)
- [Whisker Shell](https://github.com/corecathx/whisker)
