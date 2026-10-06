#!/bin/sh -e

TAURED_REPO="https://github.com/nibir-d7/taured"
TAURED_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/taured"

{
rc='\033[0m'
red='\033[0;31m'

check() {
    exit_code=$1
    message=$2

    if [ "$exit_code" -ne 0 ]; then
        printf '%sERROR: %s%s\n' "$red" "$message" "$rc"
        exit 1
    fi

    unset exit_code
    unset message
}

findArch() {
    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) check 1 "Unsupported architecture: $(uname -m)"
    esac
}

runFromSource() {
    if ! command -v cargo >/dev/null 2>&1; then
        printf '%sERROR: %s%s\n' "$red" "No prebuilt binary available and cargo is not installed. Install Rust from https://rustup.rs then re-run this command." "$rc"
        exit 1
    fi

    if [ ! -d "$TAURED_CACHE/src" ]; then
        echo "First run: fetching sources (this happens once)..."
        mkdir -p "$TAURED_CACHE"
        check $? "Creating the cache directory"
        if command -v git >/dev/null 2>&1; then
            git clone --depth 1 "$TAURED_REPO" "$TAURED_CACHE/src"
        else
            check 1 "git is required to fetch sources"
        fi
        check $? "Cloning sources"
    fi

    echo "Building from source (first run can take a few minutes)..."
    CARGO_TARGET_DIR="$TAURED_CACHE/target" cargo run --quiet --manifest-path "$TAURED_CACHE/src/cli/taured-lin/Cargo.toml" -p taured_tui --bin taured -- "$@"
    check $? "Running taured from source"
}

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
if [ -f "$SCRIPT_DIR/Cargo.toml" ] && command -v cargo >/dev/null 2>&1; then
    cd "$SCRIPT_DIR"
    check $? "Entering the taured directory"
    CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$TAURED_CACHE/target}" cargo run --quiet -p taured_tui --bin taured -- "$@"
    check $? "Running taured from source"
    exit 0
fi

findArch
temp_file=$(mktemp)
check $? "Creating the temporary file"

downloaded=0
for url in \
    "$TAURED_REPO/releases/latest/download/taured" \
    "$TAURED_REPO/releases/latest/download/taured-$arch"; do
    if curl -fsL "$url" -o "$temp_file" 2>/dev/null; then
        downloaded=1
        break
    fi
done

if [ "$downloaded" -eq 1 ]; then
    chmod +x "$temp_file"
    check $? "Making taured executable"
    "$temp_file" "$@"
    check $? "Executing taured"
    rm -f "$temp_file"
    check $? "Deleting the temporary file"
else
    echo "Prebuilt binary not found, building from source instead..."
    rm -f "$temp_file"
    runFromSource "$@"
fi
}