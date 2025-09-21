#!/bin/bash
# Check which hypervisor is active
source "$(dirname "$0")/utils.sh"

if lsmod | grep -q kvm_intel; then
    echo -e "${GREEN}KVM is currently enabled.${RESET}"
elif systemctl is-active --quiet hv-kvp-daemon; then
    echo -e "${BLUE}Hyper-V is currently enabled.${RESET}"
else
    echo -e "${YELLOW}No hypervisor detected.${RESET}"
fi
