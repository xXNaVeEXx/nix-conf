#!/usr/bin/env bash

# Nix + Home-Manager Installation Script for non-NixOS systems
# This script installs Nix package manager and sets up home-manager

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funktionen
print_header() {
    echo ""
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

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Prüfe ob Nix bereits installiert ist
check_nix_installed() {
    if command -v nix &> /dev/null; then
        print_success "Nix ist bereits installiert!"
        nix --version
        return 0
    elif [[ -d /nix ]]; then
        print_warning "Nix Verzeichnis existiert, aber nix Befehl nicht gefunden"
        print_info "Versuche Nix Environment zu laden..."
        return 1
    else
        print_info "Nix ist nicht installiert"
        return 1
    fi
}

# Prüfe ob wir im richtigen Verzeichnis sind
check_directory() {
    if [[ ! -f "flake.nix" ]]; then
        print_error "flake.nix nicht gefunden!"
        echo "Bitte führe das Script im nix-config Verzeichnis aus."
        exit 1
    fi
}

# Systemerkennung
detect_system() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/os-release ]]; then
            source /etc/os-release
            OS_NAME="$NAME"
            OS_ID="$ID"
            print_info "Erkanntes System: $OS_NAME"
        fi
    else
        print_error "Dieses Script ist nur für Linux-Systeme gedacht"
        exit 1
    fi
}

# Stoppe alle Nix-bezogenen Prozesse und Dienste
cleanup_nix_processes() {
    print_header "Stoppe laufende Nix-Prozesse..."

    # Stoppe nix-daemon service
    if systemctl is-active --quiet nix-daemon.service 2>/dev/null; then
        print_info "Stoppe nix-daemon.service..."
        sudo systemctl stop nix-daemon.service 2>/dev/null || true
        sudo systemctl stop nix-daemon.socket 2>/dev/null || true
    fi

    # Warte kurz
    sleep 1

    # Finde und stoppe alle nix-daemon Prozesse
    if pgrep -x nix-daemon >/dev/null 2>&1; then
        print_warning "Beende laufende nix-daemon Prozesse..."
        sudo pkill -TERM nix-daemon 2>/dev/null || true
        sleep 2
        # Falls noch Prozesse laufen, force kill
        if pgrep -x nix-daemon >/dev/null 2>&1; then
            sudo pkill -KILL nix-daemon 2>/dev/null || true
        fi
    fi

    # Finde und stoppe alle anderen Nix-Prozesse
    if pgrep nix >/dev/null 2>&1; then
        print_info "Beende andere Nix-Prozesse..."
        sudo pkill -TERM -f "/nix/" 2>/dev/null || true
        sleep 1
    fi

    print_success "Nix-Prozesse gestoppt"
}

# Installiere Nix Package Manager
install_nix() {
    print_header "Installiere Nix Package Manager..."

    # Prüfe ob bereits erfolgreich installiert
    if command -v nix &> /dev/null && nix --version &>/dev/null; then
        print_success "Nix ist bereits installiert und funktioniert"
        return 0
    fi

    # Wenn /nix existiert aber nix nicht funktioniert, cleanup nötig
    if [[ -d /nix ]]; then
        print_warning "Nix Verzeichnis existiert, aber Installation ist nicht vollständig"
        read -p "Alte Installation entfernen und neu installieren? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cleanup_nix_processes
            print_info "Entferne alte Nix Installation..."
            sudo rm -rf /nix
            sudo rm -rf /etc/nix
            print_success "Alte Installation entfernt"
        else
            print_error "Installation abgebrochen"
            exit 1
        fi
    fi

    # Stoppe alle Nix Prozesse vor Installation
    cleanup_nix_processes

    # Entferne ALLE möglichen Nix Backup-Dateien falls vorhanden
    print_info "Prüfe auf alte Nix Backup-Dateien..."

    local backup_files=(
        "/etc/bashrc.backup-before-nix"
        "/etc/bash.bashrc.backup-before-nix"
        "/etc/zshrc.backup-before-nix"
        "/etc/zsh/zshrc.backup-before-nix"
        "/etc/profile.d/nix.sh.backup-before-nix"
    )

    local found_backups=false
    for backup_file in "${backup_files[@]}"; do
        if [[ -f "$backup_file" ]]; then
            found_backups=true
            print_warning "Entferne alte Backup-Datei: $backup_file"
            sudo mv "$backup_file" "/tmp/$(basename $backup_file).old-$(date +%s)" 2>/dev/null || true
        fi
    done

    if [[ "$found_backups" == true ]]; then
        print_success "Alte Backup-Dateien entfernt"
    else
        print_info "Keine alten Backup-Dateien gefunden"
    fi

    print_info "Verwende Multi-User Installation (empfohlen)"

    # Download und Installation
    if curl -L https://nixos.org/nix/install | sh -s -- --daemon; then
        print_success "Nix erfolgreich installiert!"
    else
        print_error "Nix Installation fehlgeschlagen!"
        print_info "Möglicherweise müssen Sie die alte Installation manuell entfernen:"
        echo -e "${CYAN}  sudo rm -rf /nix${NC}"
        echo -e "${CYAN}  sudo rm -rf /etc/nix${NC}"
        echo "Dann führe das Script erneut aus."
        exit 1
    fi
}

# Konfiguriere Nix für Flakes und Trusted Users
configure_nix_flakes() {
    print_header "Konfiguriere Nix für Flakes und Trusted Users..."

    # Konfiguriere System-weite Nix Konfiguration (/etc/nix/nix.conf)
    SYSTEM_NIX_CONF="/etc/nix/nix.conf"

    print_info "Konfiguriere System-weite Nix Einstellungen..."

    # Erstelle /etc/nix Verzeichnis falls nicht vorhanden
    sudo mkdir -p /etc/nix

    # Prüfe ob Konfiguration bereits existiert
    if [[ -f "$SYSTEM_NIX_CONF" ]]; then
        if grep -q "experimental-features" "$SYSTEM_NIX_CONF"; then
            print_info "Flakes bereits in System-Konfiguration aktiviert"
        else
            # Füge Flakes hinzu
            echo "experimental-features = nix-command flakes" | sudo tee -a "$SYSTEM_NIX_CONF" > /dev/null
            print_success "Flakes zu System-Konfiguration hinzugefügt"
        fi

        if grep -q "trusted-users" "$SYSTEM_NIX_CONF"; then
            print_info "Trusted users bereits konfiguriert"
        else
            # Füge aktuellen User zu trusted users hinzu
            echo "trusted-users = root $(whoami)" | sudo tee -a "$SYSTEM_NIX_CONF" > /dev/null
            print_success "User $(whoami) zu trusted users hinzugefügt"
        fi
    else
        # Erstelle neue Konfiguration
        sudo tee "$SYSTEM_NIX_CONF" > /dev/null << EOF
# Enable experimental features
experimental-features = nix-command flakes

# Trusted users (needed for home-manager)
trusted-users = root $(whoami)

# Binary cache
substituters = https://cache.nixos.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
EOF
        print_success "System-Konfiguration erstellt: $SYSTEM_NIX_CONF"
    fi

    # Erstelle auch User-spezifische Konfiguration
    NIX_CONF_DIR="$HOME/.config/nix"
    mkdir -p "$NIX_CONF_DIR"
    NIX_CONF_FILE="$NIX_CONF_DIR/nix.conf"

    if [[ ! -f "$NIX_CONF_FILE" ]] || ! grep -q "experimental-features" "$NIX_CONF_FILE"; then
        cat >> "$NIX_CONF_FILE" << 'EOF'
# Enable experimental features
experimental-features = nix-command flakes
EOF
        print_success "User-Konfiguration erstellt: $NIX_CONF_FILE"
    fi
}

# Starte/Restarte Nix Daemon
restart_nix_daemon() {
    print_header "Starte Nix Daemon neu..."

    # Prüfe ob systemd verfügbar ist
    if command -v systemctl &> /dev/null; then
        # Prüfe ob nix-daemon.service existiert
        if systemctl list-unit-files | grep -q nix-daemon.service; then
            print_info "Starte nix-daemon.service neu..."
            sudo systemctl daemon-reload
            sudo systemctl restart nix-daemon.service

            # Warte kurz bis Daemon gestartet ist
            sleep 2

            if systemctl is-active --quiet nix-daemon.service; then
                print_success "Nix Daemon erfolgreich neu gestartet"
            else
                print_warning "Nix Daemon konnte nicht gestartet werden"
                systemctl status nix-daemon.service --no-pager | head -10
            fi
        else
            print_info "Nix Daemon Service nicht gefunden, überspringe Neustart"
        fi
    else
        print_warning "systemd nicht verfügbar, überspringe Daemon Neustart"
    fi
}

# Lade Nix Environment
load_nix_environment() {
    print_header "Lade Nix Environment..."

    # Wenn Nix bereits verfügbar ist, nur Version anzeigen
    if command -v nix &> /dev/null; then
        print_success "Nix ist bereits verfügbar"
        print_success "Nix Version: $(nix --version)"
        return 0
    fi

    # Versuche Nix zu laden
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        print_success "Nix Environment geladen"
    elif [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
        source "$HOME/.nix-profile/etc/profile.d/nix.sh"
        print_success "Nix Environment geladen (Single-User)"
    else
        print_warning "Nix Environment konnte nicht automatisch geladen werden"
        print_info "Bitte starte eine neue Shell oder führe aus:"
        echo -e "${CYAN}  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh${NC}"
        echo -e "Dann führe das Script erneut aus:"
        echo -e "${CYAN}  $0 --skip-nix${NC}"
        return 1
    fi

    # Prüfe ob Nix verfügbar ist
    if ! command -v nix &> /dev/null; then
        print_error "Nix Befehl nicht gefunden nach dem Laden"
        return 1
    fi

    print_success "Nix Version: $(nix --version)"
    return 0
}

# Bestimme Home-Manager Konfiguration
detect_home_config() {
    local username=$(whoami)
    local hostname=$(hostname)

    # Prüfe welche Konfiguration verfügbar ist
    if grep -q "\"$username@$hostname\"" flake.nix; then
        HOME_CONFIG="$username@$hostname"
    elif [[ -f "home/$username-$(echo $hostname | cut -d. -f1).nix" ]]; then
        HOME_CONFIG="$username@$(echo $hostname | cut -d. -f1)"
    elif grep -q "\"$username@cachyos\"" flake.nix; then
        HOME_CONFIG="$username@cachyos"
    else
        print_error "Keine passende Home-Manager Konfiguration gefunden!"
        print_info "Verfügbare Konfigurationen in flake.nix:"
        grep -A 1 "homeConfigurations" flake.nix | grep -v "homeConfigurations"
        exit 1
    fi

    print_info "Verwende Home-Manager Konfiguration: $HOME_CONFIG"
}

# Installiere Home-Manager und aktiviere Konfiguration
install_home_manager() {
    print_header "Installiere Home-Manager..."

    detect_home_config

    print_info "Aktiviere Konfiguration: $HOME_CONFIG"

    # Backup existierende Konfigurationsdateien
    print_info "Sichere existierende Konfigurationsdateien automatisch..."

    # Installiere und aktiviere home-manager mit automatischem Backup
    if nix run home-manager/master -- switch --flake .#$HOME_CONFIG -b backup; then
        print_success "Home-Manager erfolgreich installiert und aktiviert!"
        print_info "Existierende Dateien wurden nach ~/.*.backup gesichert"
    else
        print_error "Home-Manager Installation fehlgeschlagen!"
        print_info "Du kannst es manuell mit folgendem Befehl versuchen:"
        echo -e "${CYAN}  nix run home-manager/master -- switch --flake .#$HOME_CONFIG -b backup${NC}"
        exit 1
    fi
}

# Füge Nix zu Shell-Profil hinzu
setup_shell_profile() {
    print_header "Konfiguriere Shell-Profil..."

    # Bestimme welche Shell verwendet wird
    CURRENT_SHELL=$(basename "$SHELL")

    case "$CURRENT_SHELL" in
        bash)
            PROFILE_FILE="$HOME/.bashrc"
            ;;
        zsh)
            PROFILE_FILE="$HOME/.zshrc"
            ;;
        fish)
            PROFILE_FILE="$HOME/.config/fish/config.fish"
            ;;
        *)
            print_warning "Unbekannte Shell: $CURRENT_SHELL"
            PROFILE_FILE="$HOME/.profile"
            ;;
    esac

    # Prüfe ob Nix bereits im Profil ist
    if [[ -f "$PROFILE_FILE" ]] && grep -q "nix-daemon.sh" "$PROFILE_FILE"; then
        print_info "Nix bereits in $PROFILE_FILE konfiguriert"
        return 0
    fi

    # Füge Nix zum Profil hinzu
    if [[ "$CURRENT_SHELL" == "fish" ]]; then
        mkdir -p "$(dirname "$PROFILE_FILE")"
        cat >> "$PROFILE_FILE" << 'EOF'

# Nix
if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
end
EOF
    else
        cat >> "$PROFILE_FILE" << 'EOF'

# Nix
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
EOF
    fi

    print_success "Nix zu $PROFILE_FILE hinzugefügt"
}

# Zeige Zusammenfassung
show_summary() {
    print_header "Installation abgeschlossen!"

    echo ""
    echo -e "${GREEN}✓ Nix Package Manager installiert${NC}"
    echo -e "${GREEN}✓ Flakes aktiviert${NC}"
    echo -e "${GREEN}✓ Home-Manager konfiguriert${NC}"
    echo -e "${GREEN}✓ Shell-Profil aktualisiert${NC}"
    echo ""

    print_info "Nächste Schritte:"
    echo ""
    echo -e "1. ${CYAN}Starte eine neue Shell oder führe aus:${NC}"
    echo -e "   ${YELLOW}source $HOME/.$(basename $SHELL)rc${NC}"
    echo ""
    echo -e "2. ${CYAN}Teste die Installation:${NC}"
    echo -e "   ${YELLOW}nix --version${NC}"
    echo -e "   ${YELLOW}home-manager --version${NC}"
    echo ""
    echo -e "3. ${CYAN}Verwende das rebuild.sh Script für Updates:${NC}"
    echo -e "   ${YELLOW}./rebuild.sh switch${NC}"
    echo -e "   ${YELLOW}./rebuild.sh update${NC}"
    echo -e "   ${YELLOW}./rebuild.sh full${NC}"
    echo ""

    print_warning "Hinweis: Einige Änderungen werden erst nach einem Neustart der Shell aktiv!"
}

# Hilfe anzeigen
show_help() {
    cat << EOF
Nix + Home-Manager Installation Script

Dieses Script installiert Nix Package Manager und richtet Home-Manager
für nicht-NixOS Systeme ein (z.B. CachyOS, Ubuntu, Fedora, etc.)

Usage: $0 [OPTION]

Optionen:
  --help, -h          Diese Hilfe anzeigen
  --skip-nix          Nix Installation überspringen (nur Home-Manager)
  --skip-home-manager Home-Manager Installation überspringen

Das Script führt folgende Schritte aus:
  1. Installiert Nix Package Manager (Multi-User)
  2. Aktiviert Flakes Support und konfiguriert trusted users
  3. Startet Nix Daemon neu
  4. Installiert und konfiguriert Home-Manager
  5. Richtet Shell-Profil ein

Wichtig:
  - Das Script kann mehrfach ausgeführt werden (idempotent)
  - Bereits durchgeführte Schritte werden automatisch übersprungen
  - Bei Fehlern kann das Script einfach erneut ausgeführt werden

Beispiele:
  $0                      # Vollständige Installation
  $0 --skip-nix           # Nur Home-Manager installieren (Nix bereits vorhanden)
  $0 --skip-home-manager  # Nur Nix installieren/konfigurieren
EOF
}

# Main
main() {
    SKIP_NIX=false
    SKIP_HOME_MANAGER=false

    # Parse Argumente
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --skip-nix)
                SKIP_NIX=true
                shift
                ;;
            --skip-home-manager)
                SKIP_HOME_MANAGER=true
                shift
                ;;
            *)
                print_error "Unbekannte Option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    print_header "Nix + Home-Manager Installation"

    detect_system
    check_directory

    if [[ "$SKIP_NIX" == false ]]; then
        # Prüfe ob Nix bereits installiert ist
        if ! check_nix_installed; then
            install_nix
        fi

        configure_nix_flakes
        restart_nix_daemon
        setup_shell_profile

        print_info "Lade Environment neu..."
        if ! load_nix_environment; then
            print_warning "Environment konnte nicht automatisch geladen werden"
            print_info "Bitte starte eine neue Shell und führe dann aus:"
            echo -e "${CYAN}  $0 --skip-nix${NC}"
            exit 0
        fi
    else
        # Wenn --skip-nix gesetzt ist, konfiguriere trotzdem falls nötig
        configure_nix_flakes
        restart_nix_daemon

        if ! load_nix_environment; then
            print_error "Nix Environment konnte nicht geladen werden!"
            print_info "Bitte stelle sicher, dass Nix installiert ist und führe aus:"
            echo -e "${CYAN}  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh${NC}"
            echo -e "Dann führe das Script erneut aus"
            exit 1
        fi
    fi

    if [[ "$SKIP_HOME_MANAGER" == false ]]; then
        install_home_manager
    fi

    show_summary
}

main "$@"
