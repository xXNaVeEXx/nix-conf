#!/usr/bin/env bash

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# System detection
detect_system() {
    # Detect the actual user (handle sudo case)
    if [[ -n "$SUDO_USER" ]]; then
        ACTUAL_USER="$SUDO_USER"
    else
        ACTUAL_USER="$USER"
    fi

    # Detect hostname
    ACTUAL_HOSTNAME="$(hostname)"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        SYSTEM_TYPE="darwin"
        REBUILD_CMD="darwin-rebuild"
        # For darwin, use the hostname directly from darwinConfigurations in flake.nix
        HOSTNAME="$ACTUAL_HOSTNAME"
    elif [[ -f /etc/os-release ]] && grep -q "ID=cachyos" /etc/os-release; then
        SYSTEM_TYPE="cachyos"
        REBUILD_CMD="home-manager"
        # For cachyos, use user@hostname format for home-manager
        HOSTNAME="${ACTUAL_USER}@${ACTUAL_HOSTNAME}"
    elif [[ -f /etc/NIXOS ]]; then
        SYSTEM_TYPE="nixos"
        REBUILD_CMD="nixos-rebuild"
        # For NixOS, use the hostname from nixosConfigurations in flake.nix
        HOSTNAME="$ACTUAL_HOSTNAME"
    else
        # Default to home-manager for other Linux distros
        SYSTEM_TYPE="linux"
        REBUILD_CMD="home-manager"
        # For standalone home-manager, use user@hostname format
        HOSTNAME="${ACTUAL_USER}@${ACTUAL_HOSTNAME}"
    fi
}

# Output helpers
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

show_help() {
    cat << EOF
Nix Rebuild Script (NixOS & macOS)

Usage: $0 [OPTION]

Detected System: $SYSTEM_TYPE
Hostname: $HOSTNAME

Options:
  switch              Build and activate the system (default)
  update              Update all flake inputs
  update-dotfiles     Update only the dotfiles input
  full                Update + switch (update everything and rebuild)
  test                Build the system without activating (NixOS only)
  boot                Stage the build for next boot (NixOS only)
  check               Validate the flake
  clean               Prune old generations
  help                Show this help

Examples:
  $0                  # Default: switch
  $0 full             # Update everything and rebuild
  $0 update-dotfiles  # Update dotfiles only
EOF
}

# Verify we're in the right directory
check_directory() {
    if [[ ! -f "flake.nix" ]]; then
        print_error "flake.nix not found!"
        echo "Please run this script from the nix-config directory."
        exit 1
    fi
}

# Verify Nix is installed (for home-manager systems)
check_nix_installed() {
    if [[ "$SYSTEM_TYPE" == "cachyos" ]] || [[ "$SYSTEM_TYPE" == "linux" ]]; then
        if ! command -v nix &> /dev/null; then
            print_error "Nix is not installed!"
            echo ""
            print_warning "On CachyOS and other non-NixOS systems Nix must be installed first."
            echo ""
            echo "Run the install script:"
            echo -e "${GREEN}  ./install-nix-home-manager.sh${NC}"
            echo ""
            echo "Or install Nix manually:"
            echo -e "${GREEN}  sh <(curl -L https://nixos.org/nix/install) --daemon${NC}"
            exit 1
        fi
    fi
}

# Check git status before destructive operations
check_git_status() {
    if [[ -n $(git status --porcelain) ]]; then
        print_warning "Git tree is dirty (uncommitted changes)"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Build and activate
do_switch() {
    print_header "Building and activating system..."
    if [[ "$SYSTEM_TYPE" == "cachyos" ]] || [[ "$SYSTEM_TYPE" == "linux" ]]; then
        # home-manager doesn't need sudo, use -b backup to backup existing files
        if $REBUILD_CMD switch --flake .#$HOSTNAME -b backup; then
            print_success "Home Manager configuration activated!"
        else
            print_error "Build failed!"
            exit 1
        fi
    else
        if sudo $REBUILD_CMD switch --flake .#$HOSTNAME; then
            print_success "System built and activated!"
        else
            print_error "Build failed!"
            exit 1
        fi
    fi
}

# Test build (without activation)
do_test() {
    if [[ "$SYSTEM_TYPE" != "nixos" ]]; then
        print_error "'test' is only available on NixOS"
        exit 1
    fi

    print_header "Testing build (no activation)..."
    if sudo $REBUILD_CMD test --flake .#$HOSTNAME; then
        print_success "Test build succeeded!"
    else
        print_error "Test build failed!"
        exit 1
    fi
}

# Boot build (stage for next boot)
do_boot() {
    if [[ "$SYSTEM_TYPE" != "nixos" ]]; then
        print_error "'boot' is only available on NixOS"
        exit 1
    fi

    print_header "Staging build for next boot..."
    if sudo $REBUILD_CMD boot --flake .#$HOSTNAME; then
        print_success "Boot configuration staged!"
    else
        print_error "Boot build failed!"
        exit 1
    fi
}

# Update all flake inputs
do_update() {
    print_header "Updating all flake inputs..."
    if nix flake update; then
        print_success "Flake inputs updated!"
        echo ""
        nix flake metadata | grep -A 10 "Inputs:"
    else
        print_error "Update failed!"
        exit 1
    fi
}

# Update only the dotfiles input
do_update_dotfiles() {
    print_header "Updating dotfiles input..."
    if nix flake lock --update-input dotfiles; then
        print_success "Dotfiles updated!"
        nix flake metadata | grep -A 1 "dotfiles"
    else
        print_error "Dotfiles update failed!"
        exit 1
    fi
}

# Validate flake
do_check() {
    print_header "Checking flake..."
    if nix flake check; then
        print_success "Flake is valid!"
    else
        print_error "Flake check failed!"
        exit 1
    fi
}

# Prune old generations
do_clean() {
    print_header "Listing generations..."

    if [[ "$SYSTEM_TYPE" == "cachyos" ]] || [[ "$SYSTEM_TYPE" == "linux" ]]; then
        # home-manager generations
        home-manager generations
        echo ""
        read -p "Delete generations older than X days (e.g. 30): " days

        if [[ $days =~ ^[0-9]+$ ]]; then
            print_header "Deleting generations older than $days days..."
            home-manager expire-generations "-${days} days"
            nix-collect-garbage -d
            print_success "Cleanup complete!"
        else
            print_error "Invalid input!"
            exit 1
        fi
    else
        sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
        echo ""
        read -p "How many generations to keep? (e.g. 5): " keep

        if [[ $keep =~ ^[0-9]+$ ]]; then
            print_header "Deleting old generations (keeping last $keep)..."
            sudo nix-env --delete-generations +$keep --profile /nix/var/nix/profiles/system
            sudo nix-collect-garbage -d
            print_success "Cleanup complete!"
        else
            print_error "Invalid input!"
            exit 1
        fi
    fi
}

# Full update + switch
do_full() {
    do_update
    echo ""
    do_switch
}

# Main
main() {
    detect_system
    check_directory
    check_nix_installed

    case "${1:-switch}" in
        switch)
            check_git_status
            do_switch
            ;;
        test)
            check_git_status
            do_test
            ;;
        boot)
            check_git_status
            do_boot
            ;;
        update)
            do_update
            ;;
        update-dotfiles)
            do_update_dotfiles
            ;;
        full)
            do_update
            echo ""
            check_git_status
            do_switch
            ;;
        check)
            do_check
            ;;
        clean)
            do_clean
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
