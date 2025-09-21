#!/bin/bash

switch_to_vbox() {
    print_status "Switching to VirtualBox..."
    stop_vms

    # Unload KVM modules
    modprobe -r kvm_intel 2>/dev/null || true
    modprobe -r kvm_amd   2>/dev/null || true
    modprobe -r kvm       2>/dev/null || true

    modprobe vboxdrv   || { print_error "Failed to load vboxdrv"; return 1; }
    modprobe vboxnetflt 2>/dev/null || true
    modprobe vboxnetadp 2>/dev/null || true
    modprobe vboxpci    2>/dev/null || true

    print_status "Loading VirtualBox modules..."
    print_success "Toggled to VirtualBox!"
    print_success "VirtualBox is nowactive!"
    print_status "You can now use VirtualBox VMs"
}
