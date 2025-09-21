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

# Function to check hardware virtualization support
check_vt_support() {
    local cpu_vendor=$(detect_cpu)
    local vt_enabled=false
    
    if [[ $cpu_vendor == "intel" ]]; then
        if grep -q "vmx" /proc/cpuinfo; then
            vt_enabled=true
        fi
    elif [[ $cpu_vendor == "amd" ]]; then
        if grep -q "svm" /proc/cpuinfo; then
            vt_enabled=true
        fi
    fi
    
    echo $vt_enabled
}

# Function to check if we're running in a VM
check_if_vm() {
    # Check various indicators that we're in a VM
    if [[ -n $(systemd-detect-virt 2>/dev/null) ]] || 
       [[ -n $(dmesg | grep -i "hypervisor detected" 2>/dev/null) ]] ||
       [[ -f /proc/xen ]] ||
       [[ -d /proc/vz ]] ||
       [[ $(dmidecode -s system-product-name 2>/dev/null | grep -i "virtual\|vmware\|vbox\|qemu\|kvm") ]]; then
        return 0  # We are in a VM
    else
        return 1  # We are not in a VM
    fi
}

# Function to display current hypervisor status
display_status() {
    local cpu_vendor=$(detect_cpu)
    local kvm_loaded=false
    local vbox_loaded=false
    
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
}

# Function to check current hypervisor status (returns status only)
check_status() {
    local kvm_loaded=false
    local vbox_loaded=false
    
    # Check KVM modules
    if lsmod | grep -q "^kvm "; then
        kvm_loaded=true
    fi
    
    # Check VirtualBox modules
    if lsmod | grep -q "^vboxdrv "; then
        vbox_loaded=true
    fi
    
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
            print_warning "Found $running_vms running VirtualBox VMs. Attempting to stop them..."
            VBoxManage list runningvms 2>/dev/null | while read vm_line; do
                if [[ -n "$vm_line" ]]; then
                    local vm_name=$(echo "$vm_line" | cut -d'"' -f2)
                    print_status "  Stopping VM: $vm_name"
                    VBoxManage controlvm "$vm_name" poweroff 2>/dev/null || print_warning "    Failed to stop $vm_name"
                fi
            done
            
            # Wait for VMs to shut down
            sleep 3
            
            # Check if any VMs are still running
            local remaining_vms=$(VBoxManage list runningvms 2>/dev/null | wc -l)
            if [[ $remaining_vms -gt 0 ]]; then
                print_warning "Some VirtualBox VMs are still running. Please stop them manually:"
                VBoxManage list runningvms 2>/dev/null
                read -p "Press Enter once all VirtualBox VMs are stopped..."
            fi
        fi
    fi
    
    print_success "VM cleanup completed"
}

# Function to stop running VMs and unload modules
# Function to stop running VMs and unload modules cleanly
stop_and_unload_hypervisor() {
    local target=$1   # "kvm" or "vbox"
    local conflict=false

    print_status "Stopping running VMs..."
    stop_vms

    # Try stopping services before unloading modules
    if systemctl list-units --type=service | grep -q "vboxdrv.service"; then
        print_status "Stopping VirtualBox service..."
        systemctl stop vboxdrv.service 2>/dev/null || true
    fi
    if systemctl list-units --type=service | grep -q "libvirtd.service"; then
        print_status "Stopping libvirtd service..."
        systemctl stop libvirtd.service 2>/dev/null || true
    fi

    sleep 2

    if [[ $target == "kvm" ]]; then
        # Unload VirtualBox modules
        print_status "Unloading VirtualBox modules..."
        for module in vboxnetadp vboxnetflt vboxpci vboxdrv; do
            if lsmod | grep -q "^$module "; then
                print_status "  Unloading $module..."
                modprobe -r "$module" 2>/dev/null || {
                    print_error "    Could not unload $module"
                    conflict=true
                }
            fi
        done

    elif [[ $target == "vbox" ]]; then
        # Unload KVM modules
        local cpu_vendor=$(detect_cpu)
        print_status "Unloading KVM modules..."
        if [[ $cpu_vendor == "intel" ]] && lsmod | grep -q "kvm_intel"; then
            modprobe -r kvm_intel 2>/dev/null || { print_error "Failed to unload kvm_intel"; conflict=true; }
        elif [[ $cpu_vendor == "amd" ]] && lsmod | grep -q "kvm_amd"; then
            modprobe -r kvm_amd 2>/dev/null || { print_error "Failed to unload kvm_amd"; conflict=true; }
        fi
        if lsmod | grep -q "^kvm "; then
            modprobe -r kvm 2>/dev/null || { print_error "Failed to unload kvm"; conflict=true; }
        fi
    fi

    # Verify unload
    if [[ $target == "kvm" ]] && lsmod | grep -q "vboxdrv"; then
        print_error "VirtualBox modules are still loaded. Reboot may be required."
        return 1
    elif [[ $target == "vbox" ]] && lsmod | grep -q "^kvm "; then
        print_error "KVM modules are still loaded. Reboot may be required."
        return 1
    fi

    if [[ $conflict == true ]]; then
        print_warning "Some modules did not unload cleanly. Recommend reboot."
        return 1
    fi

    print_success "Cleanly unloaded conflicting hypervisor modules"
    return 0
}


# Function to switch to KVM
switch_to_kvm() {
    local cpu_vendor=$(detect_cpu)
    
    print_status "Switching to KVM hypervisor..."
    
    # Check hardware virtualization support first
    local vt_support=$(check_vt_support)
    if [[ $vt_support == "false" ]]; then
        print_error "Hardware virtualization (VT-x/AMD-V) is not available"
        print_status "Please enable virtualization in your BIOS/UEFI settings"
        return 1
    fi
    
    # Check if we're in a VM
    if check_if_vm; then
        print_warning "Running inside a virtual machine detected"
        print_status "Nested virtualization may not be enabled on the host"
    fi
    
    # Stop and unload conflicting hypervisors
    if ! stop_and_unload_hypervisor "kvm"; then
        print_warning "Cleanup had some issues, but proceeding with KVM loading..."
    fi
    
    # Load KVM modules
    print_status "Loading KVM modules..."
    if ! modprobe kvm; then
        print_error "Failed to load base KVM module"
        return 1
    fi
    
    if [[ $cpu_vendor == "intel" ]]; then
        if ! modprobe kvm_intel; then
            print_error "Failed to load kvm_intel module"
            print_status "Possible causes:"
            print_status "  1. Hardware virtualization disabled in BIOS/UEFI"
            print_status "  2. Another hypervisor is still active"
            print_status "  3. Running inside a VM without nested virtualization"
            print_status "  4. CPU doesn't support Intel VT-x"
            print_status ""
            print_status "Diagnostic commands:"
            print_status "  grep vmx /proc/cpuinfo  # Check VT-x support"
            print_status "  dmesg | grep kvm        # Check kernel messages"
            print_status "  systemd-detect-virt     # Check if in VM"
            
            # Cleanup on failure
            modprobe -r kvm 2>/dev/null || true
            return 1
        fi
        print_success "Intel KVM modules loaded"
    elif [[ $cpu_vendor == "amd" ]]; then
        if ! modprobe kvm_amd; then
            print_error "Failed to load kvm_amd module"
            print_status "Possible causes:"
            print_status "  1. Hardware virtualization disabled in BIOS/UEFI"
            print_status "  2. Another hypervisor is still active"
            print_status "  3. Running inside a VM without nested virtualization"
            print_status "  4. CPU doesn't support AMD-V"
            print_status ""
            print_status "Diagnostic commands:"
            print_status "  grep svm /proc/cpuinfo   # Check AMD-V support"
            print_status "  dmesg | grep kvm         # Check kernel messages"
            print_status "  systemd-detect-virt      # Check if in VM"
            
            # Cleanup on failure
            modprobe -r kvm 2>/dev/null || true
            return 1
        fi
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
        return 1
    fi
}

# Function to switch to VirtualBox
switch_to_vbox() {
    local cpu_vendor=$(detect_cpu)
    
    print_status "Switching to VirtualBox hypervisor..."
    
    # Stop and unload conflicting hypervisors
    if ! stop_and_unload_hypervisor "vbox"; then
        print_warning "Cleanup had some issues, but proceeding with VirtualBox loading..."
    fi
    
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
    
    # Display current status in menu header
    case $current_status in
        "kvm")
            echo "=== Hypervisor Switcher Menu (Current: KVM) ==="
            ;;
        "vbox")
            echo "=== Hypervisor Switcher Menu (Current: VirtualBox) ==="
            ;;
        "both")
            echo "=== Hypervisor Switcher Menu (Current: CONFLICT - Both Active) ==="
            ;;
        "none")
            echo "=== Hypervisor Switcher Menu (Current: None Active) ==="
            ;;
    esac
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
        display_status
        current_status=$(check_status)
        show_menu "$current_status"
        
        read -p "Select an option: " choice
        echo ""
        
        case $current_status in
            "kvm")
                case $choice in
                    1)
                        if ! switch_to_vbox; then
                            print_error "Failed to switch to VirtualBox"
                        fi
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
                        if ! switch_to_kvm; then
                            print_error "Failed to switch to KVM"
                        fi
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
                        if ! switch_to_kvm; then
                            print_error "Failed to switch to KVM"
                        fi
                        ;;
                    2)
                        if ! switch_to_vbox; then
                            print_error "Failed to switch to VirtualBox"
                        fi
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
                        if ! switch_to_kvm; then
                            print_error "Failed to switch to KVM"
                        fi
                        ;;
                    2)
                        if ! switch_to_vbox; then
                            print_error "Failed to switch to VirtualBox"
                        fi
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


