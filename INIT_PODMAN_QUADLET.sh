#!/bin/bash
# Generates and installs the Quadlet with correct user/display settings

QUADLET_DIR="$HOME/.config/containers/systemd"
mkdir -p "$QUADLET_DIR"

UID_NUM=$(id -u)
WAYLAND=$(echo $WAYLAND_DISPLAY)
XDG=$(echo $XDG_RUNTIME_DIR)
PROJECT="$HOME/NaturalGrounding-Tiktok-Ying-Video-Manager"

echo "Detected:"
echo "  UID:             $UID_NUM"
echo "  WAYLAND_DISPLAY: $WAYLAND"
echo "  XDG_RUNTIME_DIR: $XDG"
echo "  Project dir:     $PROJECT"
echo ""

mkdir -p "$PROJECT/config" "$PROJECT/VIDEOS"

cat > "$QUADLET_DIR/naturalgrounding.container" << QUADLET
[Unit]
Description=NaturalGrounding TikTok Ying Video Manager
After=network-online.target

[Container]
ContainerName=NG
Image=localhost/mariadb-media-custom:latest

Environment=MARIADB_ROOT_PASSWORD=123
Environment=MARIADB_DATABASE=NaturalGrounding-Tiktok-Ying-Video-Manager

Environment=WAYLAND_DISPLAY=$WAYLAND
Environment=XDG_RUNTIME_DIR=$XDG
Environment=DISPLAY=:0

Volume=mariadb_data_NG:/var/lib/mysql:Z
Volume=$PROJECT/config:/app/config:Z
Volume=$PROJECT/VIDEOS:/app/VIDEOS:Z

Volume=$XDG/$WAYLAND:$XDG/$WAYLAND:ro
Volume=$XDG/pipewire-0:$XDG/pipewire-0:ro
Volume=$XDG/pulse:$XDG/pulse:ro

AddDevice=/dev/snd
GroupAdd=video

[Install]
WantedBy=multi-user.target default.target
QUADLET

echo "Installed: $QUADLET_DIR/naturalgrounding.container"
echo ""
systemctl --user daemon-reload
echo "Done! Run: systemctl --user start NG"
