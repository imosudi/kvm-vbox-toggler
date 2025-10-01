#!/bin/bash
set -e

# Resolve absolute path to this script’s directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Import modules
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/vmcontrol.sh"
source "$LIB_DIR/kvm.sh"
source "$LIB_DIR/vbox.sh"

check_privileges

if [[ $# -eq 1 ]]; then
    case "$1" in
        kvm)  switch_to_kvm ;;
        vbox) switch_to_vbox ;;
        *)
            echo "Usage: $0 [kvm|vbox]"
            exit 1
            ;;
    esac
    exit 0
fi

# ─────────────────────────────
# Interactive Menu
# ─────────────────────────────
while true; do
    clear
    echo "=========================="
    echo " Hypervisor Toggler Menu"
    echo "=========================="
    echo " The tool is brought to you by imosudi"
    echo " Repository: https://github.com/imosudi/kvm-vbox-toggler"
    echo "=========================="
    echo "1) Switch to KVM"
    echo "2) Switch to VirtualBox"
    echo "3) Show Current Status"
    echo "4) Exit"
    echo

    read -rp "Choose an option [1-4]: " choice
    case "$choice" in
        1) switch_to_kvm ;;
        2) switch_to_vbox ;;
        3) show_status ;;
        4) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice. Try again." ;;
    esac

    echo
    read -rp "Press Enter to continue..."
done
