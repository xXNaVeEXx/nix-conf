#!/usr/bin/env bash

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktionen
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

# Hilfe anzeigen
show_help() {
    cat << EOF
NixOS Rebuild Script

Usage: $0 [OPTION]

Optionen:
  switch              System bauen und aktivieren (default)
  update              Alle Flake-Inputs updaten
  update-dotfiles     Nur Dotfiles updaten
  full                Update + Switch (alles updaten und bauen)
  test                System bauen aber nicht aktivieren
  boot                Für nächsten Boot vorbereiten
  check               Flake auf Fehler prüfen
  clean               Alte Generationen aufräumen
  help                Diese Hilfe anzeigen

Beispiele:
  $0                  # Standard: switch
  $0 full             # Alles updaten und bauen
  $0 update-dotfiles  # Nur dotfiles aktualisieren
EOF
}

# Prüfe ob wir in /etc/nixos sind
check_directory() {
    if [[ ! -f "flake.nix" ]]; then
        print_error "flake.nix nicht gefunden!"
        echo "Bitte führe das Script in /etc/nixos aus."
        exit 1
    fi
}

# Git Status prüfen
check_git_status() {
    if [[ -n $(git status --porcelain) ]]; then
        print_warning "Git tree ist dirty (uncommitted changes)"
        read -p "Trotzdem fortfahren? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# System bauen
do_switch() {
    print_header "System wird gebaut und aktiviert..."
    if sudo nixos-rebuild switch --flake .#nixos; then
        print_success "System erfolgreich gebaut!"
    else
        print_error "Build fehlgeschlagen!"
        exit 1
    fi
}

# Test build (ohne Aktivierung)
do_test() {
    print_header "System wird getestet (ohne Aktivierung)..."
    if sudo nixos-rebuild test --flake .#nixos; then
        print_success "Test erfolgreich!"
    else
        print_error "Test fehlgeschlagen!"
        exit 1
    fi
}

# Boot build
do_boot() {
    print_header "System für nächsten Boot vorbereiten..."
    if sudo nixos-rebuild boot --flake .#nixos; then
        print_success "Boot-Konfiguration erstellt!"
    else
        print_error "Boot-Build fehlgeschlagen!"
        exit 1
    fi
}

# Alle Inputs updaten
do_update() {
    print_header "Alle Flake-Inputs werden aktualisiert..."
    if nix flake update; then
        print_success "Flake-Inputs aktualisiert!"
        echo ""
        nix flake metadata | grep -A 10 "Inputs:"
    else
        print_error "Update fehlgeschlagen!"
        exit 1
    fi
}

# Nur Dotfiles updaten
do_update_dotfiles() {
    print_header "Dotfiles werden aktualisiert..."
    if nix flake lock --update-input dotfiles; then
        print_success "Dotfiles aktualisiert!"
        nix flake metadata | grep -A 1 "dotfiles"
    else
        print_error "Dotfiles-Update fehlgeschlagen!"
        exit 1
    fi
}

# Flake checken
do_check() {
    print_header "Flake wird geprüft..."
    if nix flake check; then
        print_success "Flake ist valide!"
    else
        print_error "Flake-Check fehlgeschlagen!"
        exit 1
    fi
}

# Alte Generationen aufräumen
do_clean() {
    print_header "Alte Generationen werden angezeigt..."
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
    echo ""
    read -p "Wie viele Generationen behalten? (z.B. 5): " keep
    
    if [[ $keep =~ ^[0-9]+$ ]]; then
        print_header "Lösche alte Generationen (behalte letzte $keep)..."
        sudo nix-env --delete-generations +$keep --profile /nix/var/nix/profiles/system
        sudo nix-collect-garbage -d
        print_success "Aufräumen abgeschlossen!"
    else
        print_error "Ungültige Eingabe!"
        exit 1
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
    check_directory
    
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
            print_error "Unbekannte Option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
