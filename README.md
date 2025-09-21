# Hypervisor Toggler 🔄

Interactive Linux utility for seamlessly switching between KVM and VirtualBox hypervisors with automatic conflict resolution.

![License](https://img.shields.io/badge/license-BSD--2--Clause-blue.svg)
![Bash](https://img.shields.io/badge/bash-5.0+-green.svg)
![Platform](https://img.shields.io/badge/platform-linux-lightgrey.svg)

## Problem Statement

When running both KVM and VirtualBox on the same Linux system, you might encounter the dreaded error:
```
VirtualBox can't operate in VMX root mode. Please disable the KVM kernel extension, recompile your kernel and reboot (VERR_VMX_IN_VMX_ROOT_MODE).
```

This happens because both hypervisors try to use the same hardware virtualization features (Intel VT-x/AMD-V) simultaneously, which isn't possible.

## Solution

This script provides an interactive way to switch between hypervisors by:
- Automatically detecting the current hypervisor state
- Safely unloading conflicting kernel modules  
- Loading the appropriate modules for your chosen hypervisor
- Handling CPU vendor differences (Intel vs AMD)
- Managing running VMs before switching

## Features

-  **Smart Detection**: Automatically detects current hypervisor status and CPU vendor
-  **Safe Switching**: Handles module loading/unloading with proper error checking
-  **VM Management**: Detects and helps stop running VMs before switching
-  **Color Output**: Clear, color-coded status messages
-  **Interactive Menu**: Context-aware menu system
-  **Conflict Resolution**: Handles edge cases where both hypervisors are loaded
-  **Status Verification**: Confirms successful switches

## Requirements

- Linux system with kernel module support
- Root privileges (script must be run with `sudo`)
- Either VirtualBox or KVM/QEMU installed (or both)
- Hardware virtualization support (Intel VT-x or AMD-V)

### Supported Distributions

Tested on:
- Ubuntu 20.04+
- Debian 11+
- Fedora 35+
- CentOS Stream 8+
- Arch Linux

## Installation

### Quick Install
```bash
# Download the script
curl -O https://raw.githubusercontent.com/imosudi/kvm-vbox-toggler/main/hypervisor-toggler.sh

# Make executable
chmod +x hypervisor-toggler.sh

# Run
sudo ./hypervisor-toggler.sh
```

### Clone Repository
```bash
git clone https://github.com/imosudi/kvm-vbox-toggler.git
cd kvm-vbox-toggler
chmod +x hypervisor-toggler.sh
sudo ./hypervisor-toggler.sh
```

## Usage

### Basic Usage
```bash
sudo ./hypervisor-toggler.sh
```

### Example Session
```
=== Interactive Hypervisor Toggler ===
============================================

=== Current Hypervisor Status ===
CPU Vendor: INTEL

[SUCCESS] KVM is currently ACTIVE
  - kvm_intel module loaded
  - kvm module loaded
[WARNING] VirtualBox is currently INACTIVE

==========================
 Hypervisor Toggler Menu
==========================
1) Switch to KVM
2) Switch to VirtualBox
3) Show Current Status
4) Exit

Choose an option [1-4]: 1

[INFO] Switching to VirtualBox hypervisor...
[INFO] Unloading KVM modules...
[INFO] Loading VirtualBox modules...
[SUCCESS] Successfully toggled to VirtualBox!
[INFO] You can now use VirtualBox VMs
```

## How It Works

1. **Status Detection**: Checks which kernel modules are currently loaded
2. **CPU Identification**: Detects Intel or AMD CPU to load appropriate modules
3. **VM Detection**: Scans for running VMs that need to be stopped
4. **Module Management**: Safely unloads old modules and loads new ones
5. **Verification**: Confirms the toggl was successful

### Kernel Modules Managed

**KVM Modules:**
- `kvm` - Base KVM module
- `kvm_intel` - Intel VT-x support
- `kvm_amd` - AMD-V support

**VirtualBox Modules:**
- `vboxdrv` - Main VirtualBox driver
- `vboxnetflt` - Network filter driver
- `vboxnetadp` - Network adapter driver
- `vboxpci` - PCI driver

## Troubleshooting

### VirtualBox modules not found
```bash
# Ubuntu/Debian
sudo apt install virtualbox-dkms

# Fedora/CentOS
sudo dnf install VirtualBox-kmod

# Arch Linux
sudo pacman -S virtualbox-host-modules-arch
```

### Hardware virtualization not enabled
- Enable VT-x (Intel) or AMD-V (AMD) in BIOS/UEFI
- Check with: `grep -E 'vmx|svm' /proc/cpuinfo`

### Permission denied
- Always run with `sudo`
- Ensure your user is in the `vboxusers` group for VirtualBox

### Running VMs blocking switch
- Stop all VMs before switching
- For VirtualBox: `VBoxManage list runningvms` then `VBoxManage controlvm <vm> poweroff`
- For KVM: VMs will be automatically terminated

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup
```bash
git clone https://github.com/imosudi/kvm-vbox-toggler.git
cd kvm-vbox-toggler

# Test the script
sudo bash -n hypervisor-switch.sh  # Syntax check
sudo ./hypervisor-toggler.sh        # Run
```

### Guidelines
- Follow existing code style
- Add comments for complex logic  
- Test on multiple distributions when possible
- Update README for new features

## License

This project is licensed under the BSD-2-Clause License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the common VirtualBox/KVM conflict issues on Linux
- Thanks to the VirtualBox and KVM/QEMU communities

## Related Projects

- [virt-manager](https://virt-manager.org/) - KVM/QEMU GUI management
- [GNOME Boxes](https://wiki.gnome.org/Apps/Boxes) - Simple virtualization
- [VirtualBox](https://www.virtualbox.org/) - Cross-platform virtualization

## Support

If you encounter issues:

1. Check the [Issues](https://github.com/imosudi/kvm-vbox-toggler/issues) page
2. Run the script with bash debug: `sudo bash -x ./hypervisor-toggler.sh`
3. Include your Linux distribution and kernel version in bug reports
4. Provide the output of `lsmod | grep -E 'kvm|vbox'`

---

⭐ If this script helped you, please consider giving it a star!