#!/bin/bash

# ====================================================
# AbuseGuard - Minimal Network Firewall
# Developed by: https://github.com/monhacer
# ====================================================

CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_DIM="\033[2m"
CLR_BLUE="\033[38;5;75m"
CLR_CYAN="\033[38;5;80m"
CLR_GREEN="\033[38;5;78m"
CLR_RED="\033[38;5;203m"
CLR_YELLOW="\033[38;5;221m"
CLR_GRAY="\033[38;5;242m"

if [ "$EUID" -ne 0 ]; then
    printf "%b\n" "${CLR_RED}✖ Error: Root privileges required. Run with sudo -i${CLR_RESET}"
    exit 1
fi

CHAIN_BLOCK="AbuseGuard-Block"
CHAIN_CUSTOM="AbuseGuard-Custom"
CHAIN_WHITE="AbuseGuard-Whitelist"
REMOTE_URL="https://raw.githubusercontent.com/monhacer/AbuseGuard/main/abuse.ipv4"

# چاپ ۱۰۰٪ استاندارد رنگ‌ها با printf %b در تمام شل‌ها
read_input() {
    local prompt="$1"
    local var_name="$2"
    printf "%b" "$prompt"
    if [ -t 0 ]; then
        read -r "$var_name"
    else
        read -r "$var_name" < /dev/tty
    fi
}

init_firewall() {
    for pkg in iptables iptables-persistent curl; do
        dpkg -s "$pkg" >/dev/null 2>&1 || apt-get install -y -qq "$pkg" >/dev/null 2>&1
    done

    iptables -N "$CHAIN_WHITE" 2>/dev/null || true
    iptables -N "$CHAIN_BLOCK" 2>/dev/null || true
    iptables -N "$CHAIN_CUSTOM" 2>/dev/null || true

    iptables -C OUTPUT -j "$CHAIN_WHITE" 2>/dev/null || iptables -I OUTPUT 1 -j "$CHAIN_WHITE"
    iptables -C OUTPUT -j "$CHAIN_BLOCK" 2>/dev/null || iptables -I OUTPUT 2 -j "$CHAIN_BLOCK"
    iptables -C OUTPUT -j "$CHAIN_CUSTOM" 2>/dev/null || iptables -I OUTPUT 3 -j "$CHAIN_CUSTOM"
}

apply_blocklist() {
    init_firewall
    printf "%b\r" "${CLR_YELLOW}↻ Fetching and applying rules from GitHub...${CLR_RESET}"

    RAW_DATA=$(curl -fsSL "$REMOTE_URL" 2>/dev/null)

    if [ -z "$RAW_DATA" ]; then
        printf "%b\n" "${CLR_RED}✖ Error: Failed to fetch abuse.ipv4 from GitHub.${CLR_RESET}          "
        return
    fi

    iptables -F "$CHAIN_BLOCK"
    grep -qF "127.0.0.1 appclick.co" /etc/hosts || echo "127.0.0.1 appclick.co" >> /etc/hosts
    grep -qF "127.0.0.1 pushnotificationws.com" /etc/hosts || echo "127.0.0.1 pushnotificationws.com" >> /etc/hosts

    local count=0
    for ip in $(printf '%s' "$RAW_DATA" | LC_ALL=C tr -cs '0-9./' '\n'); do
        [ -z "$ip" ] && continue
        if iptables -A "$CHAIN_BLOCK" -d "$ip" -j DROP 2>/dev/null; then
            count=$((count + 1))
        fi
    done

    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    printf "%b\n" "${CLR_GREEN}✔ Successfully blocked ${CLR_BOLD}${count}${CLR_RESET}${CLR_GREEN} network ranges.${CLR_RESET}                  "
}

add_whitelist() {
    init_firewall
    read_input "${CLR_CYAN}➤ Enter IP or CIDR to whitelist: ${CLR_RESET}" ip_input
    ip_input=$(printf '%s' "$ip_input" | LC_ALL=C tr -cd '0-9./')
    if [ -n "$ip_input" ]; then
        iptables -I "$CHAIN_WHITE" -d "$ip_input" -j ACCEPT
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        printf "%b\n" "${CLR_GREEN}✔ Allowed outbound traffic to ${CLR_BOLD}${ip_input}${CLR_RESET}"
    else
        printf "%b\n" "${CLR_GRAY}Action cancelled.${CLR_RESET}"
    fi
}

add_custom() {
    init_firewall
    read_input "${CLR_CYAN}➤ Enter IP or CIDR to block: ${CLR_RESET}" ip_input
    ip_input=$(printf '%s' "$ip_input" | LC_ALL=C tr -cd '0-9./')
    if [ -n "$ip_input" ]; then
        iptables -A "$CHAIN_CUSTOM" -d "$ip_input" -j DROP
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        printf "%b\n" "${CLR_GREEN}✔ Custom block applied to ${CLR_BOLD}${ip_input}${CLR_RESET}"
    else
        printf "%b\n" "${CLR_GRAY}Action cancelled.${CLR_RESET}"
    fi
}

view_status() {
    local white_count custom_count abuse_count
    white_count=$(iptables -L "$CHAIN_WHITE" -n 2>/dev/null | grep -c ACCEPT)
    custom_count=$(iptables -L "$CHAIN_CUSTOM" -n 2>/dev/null | grep -c DROP)
    abuse_count=$(iptables -L "$CHAIN_BLOCK" -n 2>/dev/null | grep -c DROP)

    printf "\n"
    printf "%b\n" " ${CLR_CYAN}╭────────────────── Active Rules ──────────────────╮${CLR_RESET}"
    printf " %b│%b  %b%-17s%b : %-26s %b│%b\n" "$CLR_CYAN" "$CLR_RESET" "$CLR_GREEN" "Whitelisted" "$CLR_RESET" "${white_count} active rules" "$CLR_CYAN" "$CLR_RESET"
    printf " %b│%b  %b%-17s%b : %-26s %b│%b\n" "$CLR_CYAN" "$CLR_RESET" "$CLR_YELLOW" "Custom Blocks" "$CLR_RESET" "${custom_count} active rules" "$CLR_CYAN" "$CLR_RESET"
    printf " %b│%b  %b%-17s%b : %-26s %b│%b\n" "$CLR_CYAN" "$CLR_RESET" "$CLR_RED" "Abuse Managed" "$CLR_RESET" "${abuse_count} blocked CIDRs" "$CLR_CYAN" "$CLR_RESET"
    printf "%b\n" " ${CLR_CYAN}╰──────────────────────────────────────────────────╯${CLR_RESET}"
}

clear_rules() {
    read_input "${CLR_YELLOW}⚠ Are you sure you want to flush all rules? [y/N]: ${CLR_RESET}" confirm
    case "$confirm" in
        [Yy]*)
            for c in "$CHAIN_WHITE" "$CHAIN_BLOCK" "$CHAIN_CUSTOM"; do
                iptables -D OUTPUT -j "$c" 2>/dev/null || true
                iptables -F "$c" 2>/dev/null || true
                iptables -X "$c" 2>/dev/null || true
            done
            sed -i '/appclick.co/d;/pushnotificationws.com/d' /etc/hosts
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            printf "%b\n" "${CLR_GREEN}✔ Firewall rules flushed.${CLR_RESET}"
            ;;
        *)
            printf "%b\n" "${CLR_GRAY}Flush cancelled.${CLR_RESET}"
            ;;
    esac
}

pause() {
    printf "\n"
    read_input "${CLR_GRAY}Press [Enter] to continue...${CLR_RESET}" dummy
}

while true; do
    clear
    printf "%b\n" "${CLR_BLUE}  ___  _                     ____                     _ ${CLR_RESET}"
    printf "%b\n" "${CLR_BLUE} / _ \| |__  _   _ ___  ___ / ___|_   _  __ _ _ __ __| |${CLR_RESET}"
    printf "%b\n" "${CLR_BLUE}| |_| | '_ \| | | / __|/ _ \ |  _| | | |/ _\` | '__/ _\` |${CLR_RESET}"
    printf "%b\n" "${CLR_BLUE}|  _  | |_) | |_| \__ \  __/ |_| | |_| | (_| | | | (_| |${CLR_RESET}"
    printf "%b\n" "${CLR_BLUE}|_| |_|_.__/ \__,_|___/\___|\____|\__,_|\__,_|_|  \__,_|${CLR_RESET}"
    printf "%b\n" "   ${CLR_DIM}Server Abuse Sanitizer ${CLR_GRAY}•${CLR_RESET} ${CLR_CYAN}https://github.com/monhacer${CLR_RESET}"
    printf "\n"
    printf "%b\n" "  ${CLR_CYAN}[1]${CLR_RESET} ${CLR_BOLD}Apply Abuse IP List${CLR_RESET}     ${CLR_DIM}(abuse.ipv4)${CLR_RESET}"
    printf "%b\n" "  ${CLR_CYAN}[2]${CLR_RESET} ${CLR_BOLD}Add to Whitelist${CLR_RESET}        ${CLR_DIM}(Always allow)${CLR_RESET}"
    printf "%b\n" "  ${CLR_CYAN}[3]${CLR_RESET} ${CLR_BOLD}Add Custom Block${CLR_RESET}        ${CLR_DIM}(Manual drop)${CLR_RESET}"
    printf "%b\n" "  ${CLR_CYAN}[4]${CLR_RESET} ${CLR_BOLD}Show Filter Status${CLR_RESET}      ${CLR_DIM}(Active counters)${CLR_RESET}"
    printf "%b\n" "  ${CLR_CYAN}[5]${CLR_RESET} ${CLR_BOLD}Flush All Rules${CLR_RESET}         ${CLR_DIM}(Reset firewall)${CLR_RESET}"
    printf "%b\n" "  ${CLR_GRAY}[0] Exit${CLR_RESET}"
    printf "\n"

    read_input "  ${CLR_CYAN}Select option [0-5]:${CLR_RESET} " raw_opt
    opt=$(printf '%s' "$raw_opt" | LC_ALL=C tr -cd '0-5')

    case "$opt" in
        1) apply_blocklist; pause ;;
        2) add_whitelist; pause ;;
        3) add_custom; pause ;;
        4) view_status; pause ;;
        5) clear_rules; pause ;;
        0)
           printf "\n%b\n\n" "${CLR_GRAY}Session closed.${CLR_RESET}"
           exit 0
           ;;
        *)
           printf "\n%b\n" "${CLR_RED}Invalid option.${CLR_RESET}"
           sleep 1
           ;;
    esac
done
