#!/bin/bash

switch_to_kvm() {
    local cpu_vendor=$(detect_cpu)

    print_status "Switching to KVM..."
    stop_vms

    # Unload VBox modules
    for mod in vboxnetadp vboxnetflt vboxpci vboxdrv; do
        lsmod | grep -q "^$mod " && modprobe -r "$mod"
    done

    modprobe kvm || { print_error "Failed to load kvm"; return 1; }

    case $cpu_vendor in
        intel) modprobe kvm_intel || return 1 ;;
        amd)   modprobe kvm_amd   || return 1 ;;
    esac

    [[ -e /dev/kvm ]] && print_success "KVM active!" || print_error "KVM failed."
}
