#!/bin/sh -e

. ../common-script.sh

updatetaured() {
    if [ ! -e "$HOME/.cargo/bin/taured" ]; then
        printf "%b\n" "${RED}This script only updates the binary installed through cargo.\ntaured_tui is not installed.${RC}"
        exit 1
    fi

    if ! command_exists cargo; then
        printf "%b\n" "${YELLOW}Installing rustup...${RC}"
        case "$PACKAGER" in
            pacman)
                "$ESCALATION_TOOL" "$PACKAGER" -S --needed --noconfirm rustup
                ;;
            dnf)
                "$ESCALATION_TOOL" "$PACKAGER" install -y curl rustup man-pages man-db man
                rustup-init -y
                ;;
            zypper)
                "$ESCALATION_TOOL" "$PACKAGER" install -n curl gcc make rustup
                ;;
            apk)
                "$ESCALATION_TOOL" "$PACKAGER" add build-base rustup
                rustup-init -y
                ;;
            *)
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                ;;
        esac
    fi

    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
    rustup default stable

    INSTALLED_VERSION=$(cargo install --list | grep "taured_tui" | awk '{print $2}' | tr -d 'v:')
    LATEST_VERSION=$(curl -s https://crates.io/api/v1/crates/taured_tui | grep -oP '"max_version":\s*"\K[^"]+')

    if [ "$INSTALLED_VERSION" = "$LATEST_VERSION" ]; then
        printf "%b\n" "${GREEN}taured_tui is up to date.${RC}"
        exit 0
    fi

    printf "%b\n" "${YELLOW}Updating taured_tui...${RC}"
    cargo install --force taured_tui
    printf "%b\n" "${GREEN}Updated successfully.${RC}"
}

checkEnv
updatetaured
