#!/usr/bin/env bash
# Theme switcher script for MangoWC + Quickshell
# Dynamically switches themes without rebuilding NixOS

set -e

THEME=$1
THEME_STATE_FILE="/tmp/quickshell-current-theme"
MAKO_CONFIG_DIR="/etc/xdg/mako"
SWAYLOCK_CONFIG_DIR="/etc/xdg/swaylock"

if [ -z "$THEME" ]; then
    echo "Usage: $0 <theme-name>"
    exit 1
fi

echo "Switching to theme: $THEME"

# Save current theme to state file
echo "$THEME" > "$THEME_STATE_FILE"

# Theme-specific configurations
case "$THEME" in
    "cyberpunk")
        WALLPAPER_URL="https://images.unsplash.com/photo-1517154421773-0529f29ea451?q=80&w=3270&auto=format&fit=crop"
        MAKO_BG="#0a0e27dd"
        MAKO_BORDER="#00d9ff"
        MAKO_TEXT="#e0e7ff"
        MAKO_PROGRESS="#00ffcc"
        SWAYLOCK_BG="0a0e27"
        SWAYLOCK_RING="2d3a6e"
        SWAYLOCK_KEY="00d9ff"
        ;;
    "sunset")
        WALLPAPER_URL="https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=3270&auto=format&fit=crop"
        MAKO_BG="#1a0a1fdd"
        MAKO_BORDER="#ff6ec7"
        MAKO_TEXT="#f8f8f2"
        MAKO_PROGRESS="#ff88cc"
        SWAYLOCK_BG="1a0a1f"
        SWAYLOCK_RING="6d3a7e"
        SWAYLOCK_KEY="ff6ec7"
        ;;
    *)
        echo "Unknown theme: $THEME"
        exit 1
        ;;
esac

# Change wallpaper
echo "Updating wallpaper..."
pkill swaybg || true
swaybg -i "$WALLPAPER_URL" -m fill &

# Update Mako config (write to /tmp for runtime changes)
echo "Updating notification theme..."
cat > /tmp/mako-config-$THEME <<EOF
anchor=top-right
margin=10,15,0,0
width=380
height=120
padding=15
border-size=2
border-radius=8
max-visible=10
default-timeout=5000
font=GohuFont Nerd Font 11
background-color=$MAKO_BG
text-color=$MAKO_TEXT
border-color=$MAKO_BORDER
progress-color=$MAKO_PROGRESS

[urgency=critical]
border-color=#ff0055
text-color=#ffffff
default-timeout=0

icon-path=/run/current-system/sw/share/icons/hicolor
max-icon-size=48
group-by=app-name
format=<b>%s</b>\n%b
markup=1
actions=1
history=1
max-history=100
layer=overlay
EOF

# Restart Mako with new config
pkill mako || true
mako --config /tmp/mako-config-$THEME &

echo "Theme switched to: $THEME"
echo "Quickshell will update colors automatically"

# Notify user
notify-send "Theme Switcher" "Switched to $THEME theme" -i preferences-desktop-theme
