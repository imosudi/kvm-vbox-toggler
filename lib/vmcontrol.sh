#!/bin/bash

show_status() {
    if systemctl is-active --quiet libvirtd; then
        echo "[+] KVM is active"
    elif systemctl is-active --quiet vboxdrv; then
        echo "[+] VirtualBox is active"
    else
        echo "[!] No hypervisor is active"
    fi
}

stop_vms() {
    print_status "Checking for running virtual machines..."

    # Stop QEMU/KVM VMs
    if pgrep qemu >/dev/null; then
        print_warning "Stopping QEMU/KVM VMs..."
        pkill -TERM qemu || true
        sleep 2
        pgrep qemu >/dev/null && pkill -KILL qemu || true
    fi

    # Stop VirtualBox VMs
    if command -v VBoxManage >/dev/null; then
        local running=$(VBoxManage list runningvms | wc -l)
        if [[ $running -gt 0 ]]; then
            print_warning "Stopping $running VirtualBox VMs..."
            VBoxManage list runningvms | while read vm_line; do
                [[ -z "$vm_line" ]] && continue
                local vm_name=$(echo "$vm_line" | cut -d'"' -f2)
                print_status "  Powering off: $vm_name"
                VBoxManage controlvm "$vm_name" poweroff || true
            done
        fi
    fi
    print_success "VM cleanup completed"
}
