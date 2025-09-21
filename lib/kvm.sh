#!/bin/bash
stop_vbox_services() {
    print_status "Stopping VirtualBox services..."
    systemctl stop vboxdrv.service 2>/dev/null || true
    systemctl stop virtualbox.service 2>/dev/null || true

    # Kill leftover VBox processes
    pkill -9 VBoxHeadless 2>/dev/null || true
    pkill -9 VBoxNetDHCP 2>/dev/null || true
    pkill -9 VBoxSVC      2>/dev/null || true

    print_success "VirtualBox services stopped"
}

switch_to_kvm() {

    local cpu_vendor
    cpu_vendor=$(detect_cpu)

    stop_vbox_services
    
    print_status "Switching to KVM..."
    stop_vms

    print_status "Unloading VirtualBox modules (if any)..."
    for mod in vboxnetadp vboxnetflt vboxpci vboxdrv; do
        if lsmod | grep -q "^$mod "; then
            print_status "Removing module: $mod"
            if modprobe -r "$mod"; then
                print_success "Removed $mod"
            else
                print_error "Failed to remove $mod"
            fi
        fi
    done

    print_status "Loading KVM core module..."
    if modprobe kvm; then
        print_success "kvm module loaded"
    else
        print_error "Failed to load kvm"
        return 1
    fi

    case $cpu_vendor in
        intel)
            print_status "Loading Intel KVM support (kvm_intel)..."
            if modprobe kvm_intel; then
                print_success "Intel KVM support loaded"
            else
                print_error "Failed to load kvm_intel"
                return 1
            fi
            ;;
        amd)
            print_status "Loading AMD KVM support (kvm_amd)..."
            if modprobe kvm_amd; then
                print_success "AMD KVM support loaded"
            else
                print_error "Failed to load kvm_amd"
                return 1
            fi
            ;;
        *)
            print_error "Unknown CPU vendor: $cpu_vendor (cannot load vendor-specific module)"
            return 1
            ;;
    esac

    if [[ -e /dev/kvm ]]; then
        print_success "Toggled to KVM!"
        print_success "KVM is now active!"
        print_status "You can now use KVM-based VMs."
    else
        print_error "KVM device not found — switching may have failed."
        return 1
    fi
}
