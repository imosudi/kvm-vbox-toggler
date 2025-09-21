#!/bin/bash

# Interactive Hypervisor Switcher
# Switches between KVM and VirtualBox

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root/sudo
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script requires root privileges. Please run with sudo."
        exit 1
    fi
}

# Function to detect CPU vendor
detect_cpu() {
    if grep -q "Intel" /proc/cpuinfo; then
        echo "intel"
    elif grep -q "AMD" /proc/cpuinfo; then
        echo "amd"
    else
        echo "unknown"
    fi
}

# Function to check current hypervisor status
check_status() {
    local kvm_loaded=false
    local vbox_loaded=false
    local cpu_vendor=$(detect_cpu)
    
    # Check KVM modules
    if lsmod | grep -q "^kvm "; then
        kvm_loaded=true
    fi
    
    # Check VirtualBox modules
    if lsmod | grep -q "^vboxdrv "; then
        vbox_loaded=true
    fi
    
    echo "=== Current Hypervisor Status ==="
    echo "CPU Vendor: $(echo $cpu_vendor | tr '[:lower:]' '[:upper:]')"
    echo ""
    
    if $kvm_loaded; then
        print_success "KVM is currently ACTIVE"
        if [[ $cpu_vendor == "intel" ]] && lsmod | grep -q "kvm_intel"; then
            echo "  - kvm_intel module loaded"
        elif [[ $cpu_vendor == "amd" ]] && lsmod | grep -q "kvm_amd"; then
            echo "  - kvm_amd module loaded"
        fi
        echo "  - kvm module loaded"
    else
        print_warning "KVM is currently INACTIVE"
    fi
    
    if $vbox_loaded; then
        print_success "VirtualBox is currently ACTIVE"
        echo "  - vboxdrv module loaded"
    else
        print_warning "VirtualBox is currently INACTIVE"
    fi
    
    echo ""
    
    # Return status for script logic
    if $kvm_loaded && $vbox_loaded; then
        echo "both"
    elif $kvm_loaded; then
        echo "kvm"
    elif $vbox_loaded; then
        echo "vbox"
    else
        echo "none"
    fi
}

# Function to stop running VMs
stop_vms() {
    print_status "Checking for running virtual machines..."
    
    # Stop QEMU/KVM VMs
    if pgrep qemu > /dev/null; then
        print_warning "Found running QEMU/KVM VMs. Attempting to stop them..."
        pkill -TERM qemu || true
        sleep 2
        if pgrep qemu > /dev/null; then
            print_warning "Force stopping remaining QEMU processes..."
            pkill -KILL qemu || true
        fi
    fi
    
    # Stop VirtualBox VMs
    if command -v VBoxManage > /dev/null; then
        local running_vms=$(VBoxManage list runningvms 2>/dev/null | wc -l)
        if [[ $running_vms -gt 0 ]]; then
            print_warning "Found $running_vms running VirtualBox VMs. Please stop them manually first."
            print_status "Run: VBoxManage list runningvms"
            print_status "Then: VBoxManage controlvm <vm-name> poweroff"
            read -p "Press Enter once all VirtualBox VMs are stopped..."
        fi
    fi
}

# Function to switch to KVM
switch_to_kvm() {
    local cpu_vendor=$(detect_cpu)
    
    print_status "Switching to KVM hypervisor..."
    
    # Remove VirtualBox modules
    print_status "Unloading VirtualBox modules..."
    modprobe -r vboxnetadp vboxnetflt vboxpci vboxdrv 2>/dev/null || true
    
    # Load KVM modules
    print_status "Loading KVM modules..."
    modprobe kvm
    
    if [[ $cpu_vendor == "intel" ]]; then
        modprobe kvm_intel
        print_success "Intel KVM modules loaded"
    elif [[ $cpu_vendor == "amd" ]]; then
        modprobe kvm_amd
        print_success "AMD KVM modules loaded"
    else
        print_warning "Unknown CPU vendor, loaded base KVM module only"
    fi
    
    # Verify KVM is working
    if [[ -e /dev/kvm ]]; then
        print_success "KVM device (/dev/kvm) is available"
        print_success "Successfully switched to KVM!"
        print_status "You can now use QEMU/KVM, virt-manager, or GNOME Boxes"
    else
        print_error "KVM device not available. Check hardware virtualization support."
    fi
}

# Function to switch to VirtualBox
switch_to_vbox() {
    local cpu_vendor=$(detect_cpu)
    
    print_status "Switching to VirtualBox hypervisor..."
    
    # Remove KVM modules
    print_status "Unloading KVM modules..."
    if [[ $cpu_vendor == "intel" ]]; then
        modprobe -r kvm_intel 2>/dev/null || true
    elif [[ $cpu_vendor == "amd" ]]; then
        modprobe -r kvm_amd 2>/dev/null || true
    fi
    modprobe -r kvm 2>/dev/null || true
    
    # Load VirtualBox modules
    print_status "Loading VirtualBox modules..."
    if ! modprobe vboxdrv; then
        print_error "Failed to load VirtualBox driver"
        print_status "You may need to install VirtualBox kernel modules:"
        print_status "  sudo apt install virtualbox-dkms  # On Debian/Ubuntu"
        print_status "  sudo dnf install VirtualBox-kmod  # On Fedora"
        return 1
    fi
    
    modprobe vboxnetflt 2>/dev/null || true
    modprobe vboxnetadp 2>/dev/null || true
    modprobe vboxpci 2>/dev/null || true
    
    print_success "Successfully switched to VirtualBox!"
    print_status "You can now use VirtualBox VMs"
}

# Function to show interactive menu
show_menu() {
    local current_status=$1
    
    echo "=== Hypervisor Switcher Menu ==="
    echo ""
    
    case $current_status in
        "kvm")
            echo "1) Switch to VirtualBox"
            echo "2) Refresh status"
            echo "3) Exit"
            ;;
        "vbox")
            echo "1) Switch to KVM"
            echo "2) Refresh status"
            echo "3) Exit"
            ;;
        "both")
            print_warning "Both hypervisors are loaded (conflict state)"
            echo "1) Switch to KVM (unload VirtualBox)"
            echo "2) Switch to VirtualBox (unload KVM)"
            echo "3) Refresh status"
            echo "4) Exit"
            ;;
        "none")
            echo "1) Switch to KVM"
            echo "2) Switch to VirtualBox"
            echo "3) Refresh status"
            echo "4) Exit"
            ;;
    esac
    echo ""
}

# Main function
main() {
    clear
    echo "=== Interactive Hypervisor Switcher ==="
    echo "Switches between KVM and VirtualBox hypervisors"
    echo "=============================================="
    echo ""
    
    check_privileges
    
    while true; do
        current_status=$(check_status)
        show_menu "$current_status"
        
        read -p "Select an option: " choice
        echo ""
        
        case $current_status in
            "kvm")
                case $choice in
                    1)
                        stop_vms
                        switch_to_vbox
                        ;;
                    2)
                        continue
                        ;;
                    3)
                        print_status "Goodbye!"
                        exit 0
                        ;;
                    *)
                        print_error "Invalid option"
                        ;;
                esac
                ;;
            "vbox")
                case $choice in
                    1)
                        stop_vms
                        switch_to_kvm
                        ;;
                    2)
                        continue
                        ;;
                    3)
                        print_status "Goodbye!"
                        exit 0
                        ;;
                    *)
                        print_error "Invalid option"
                        ;;
                esac
                ;;
            "both")
                case $choice in
                    1)
                        stop_vms
                        switch_to_kvm
                        ;;
                    2)
                        stop_vms
                        switch_to_vbox
                        ;;
                    3)
                        continue
                        ;;
                    4)
                        print_status "Goodbye!"
                        exit 0
                        ;;
                    *)
                        print_error "Invalid option"
                        ;;
                esac
                ;;
            "none")
                case $choice in
                    1)
                        switch_to_kvm
                        ;;
                    2)
                        switch_to_vbox
                        ;;
                    3)
                        continue
                        ;;
                    4)
                        print_status "Goodbye!"
                        exit 0
                        ;;
                    *)
                        print_error "Invalid option"
                        ;;
                esac
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        clear
        echo "=== Interactive Hypervisor Switcher ==="
        echo "=============================================="
        echo ""
    done
}

# Run main function
main "$@"