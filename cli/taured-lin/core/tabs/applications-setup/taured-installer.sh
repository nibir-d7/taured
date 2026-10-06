#!/bin/sh -e

. ../common-script.sh

install_extra() {
    printf "%b\n" "${YELLOW}Installing the manpage...${RC}"
    "$ESCALATION_TOOL" mkdir -p /usr/share/man/man1
    # -f makes curl exit non-zero on HTTP errors so a 404/5xx body is not written
    # as the manpage; -sSL keeps the curl quiet but shows the error if it fails.
    curl -fsSL 'https://raw.githubusercontent.com/ChrisTitusTech/taured/refs/heads/main/man/taured.1' | "$ESCALATION_TOOL" tee '/usr/share/man/man1/taured.1' > /dev/null
    printf "%b\n" "${YELLOW}Creating a Desktop Entry...${RC}"
    "$ESCALATION_TOOL" mkdir -p /usr/share/applications
    curl -fsSL 'https://raw.githubusercontent.com/ChrisTitusTech/taured/refs/heads/main/taured.desktop' | "$ESCALATION_TOOL" tee /usr/share/applications/taured.desktop > /dev/null
    printf "%b\n" "${GREEN}Done.${RC}"
}

installtaured() {
    printf "%b\n" "${YELLOW}Installing taured...${RC}"
    case "$PACKAGER" in
        pacman)
            printf "%b\n" "-----------------------------------------------------"
            printf "%b\n" "Select the package to install:"
            printf "%b\n" "1. ${CYAN}taured${RC}      (stable release compiled from source)"
            printf "%b\n" "2. ${CYAN}taured-bin${RC}  (stable release pre-compiled)"
            printf "%b\n" "3. ${CYAN}taured-git${RC}  (compiled from the latest commit)"
            printf "%b\n" "-----------------------------------------------------"
            printf "%b" "Enter your choice: "
            read -r choice
            case $choice in
                1) "$AUR_HELPER" -S --needed --noconfirm taured ;;
                2) "$AUR_HELPER" -S --needed --noconfirm taured-bin ;;
                3) "$AUR_HELPER" -S --needed --noconfirm taured-git ;;
                *)
                    printf "%b\n" "${RED}Invalid choice:${RC} $choice"
                    exit 1
                    ;;
            esac
            printf "%b\n" "${GREEN}Installed successfully.${RC}"
            ;;
        zypper)
            "$ESCALATION_TOOL" "$PACKAGER" install taured -y
            printf "%b\n" "${GREEN}Installed successfully.${RC}"
            ;;
        *)
            printf "%b\n" "${RED}There are no official packages for your distro.${RC}"
            printf "%b" "${YELLOW}Do you want to install the crates.io package? (y/N): ${RC}"
            read -r choice
            case $choice in
                y | Y)
                    if ! command -v cargo > /dev/null 2>&1; then
                        printf "%b\n" "${YELLOW}Installing rustup...${RC}"
                        case "$PACKAGER" in
                            dnf)
                                "$ESCALATION_TOOL" "$PACKAGER" install -y curl rustup man-pages man-db man
                                rustup-init -y
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
                    rustup default stable
                    if [ -f "$HOME/.cargo/env" ]; then
                        # shellcheck disable=SC1091
                        . "$HOME/.cargo/env"
                    else
                        export PATH="$HOME/.cargo/bin:$PATH"
                    fi
                    cargo install --force taured_tui
                    printf "%b\n" "${GREEN}Installed successfully.${RC}"
                    install_extra
                    ;;
                *) printf "%b\n" "${RED}taured not installed.${RC}" ;;
            esac
            ;;
    esac
}

checkEnv
installtaured
