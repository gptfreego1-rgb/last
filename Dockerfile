FROM alpine:3.19

ENV DISPLAY=:1 \
    HOME=/root

# Install minimal packages
RUN apk add --no-cache \
    openjdk17-jre-headless \
    firefox \
    xvfb \
    x11vnc \
    jwm \
    feh \
    wget \
    unzip \
    ttf-dejavu \
    xterm \
    mesa-dri-gallium \
    && rm -rf /var/cache/apk/*

# Download MicroEmulator + Avatar
RUN mkdir -p /opt/microemulator \
    && wget -q https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/microemu/microemulator-2.0.4.zip -O /tmp/microemulator.zip \
    && unzip -q /tmp/microemulator.zip -d /opt/microemulator \
    && rm -f /tmp/microemulator.zip \
    && wget -q https://files.catbox.moe/9wzwpo.zip -O /opt/microemulator/avatar.jar

# MicroEmulator launcher
RUN cat >/usr/local/bin/microemu <<'EOF'
#!/bin/sh
exec java -noverify -Xms8m -Xmx32m -XX:+UseSerialGC -XX:MaxRAM=32m \
-jar /opt/microemulator/microemulator-2.0.4/microemulator.jar \
/opt/microemulator/avatar.jar
EOF

RUN chmod +x /usr/local/bin/microemu

# Script ganti password VNC (pakai xterm)
RUN cat >/usr/local/bin/change-vnc-password <<'EOF'
#!/bin/sh

mkdir -p /root/.vnc

xterm -title "Change VNC Password" -e sh -c '
echo
echo "=== Change VNC Password ==="
echo
echo "Masukkan password baru (minimal 6 karakter):"
echo

x11vnc -storepasswd /root/.vnc/passwd

echo
echo "Password berhasil diubah!"
echo "Restarting VNC server..."

pkill x11vnc 2>/dev/null
sleep 1

x11vnc -display :1 -rfbport 5901 -rfbauth /root/.vnc/passwd -forever -shared -noxdamage -nowf >/tmp/x11vnc.log 2>&1 &

echo
echo "VNC server restart complete!"
echo "Tekan ENTER untuk keluar..."
read
'
EOF

RUN chmod +x /usr/local/bin/change-vnc-password

# JWM Config (dengan menu Change Password)
RUN cat >/root/.jwmrc <<'EOF'
<?xml version="1.0"?>
<JWM>
<StartupCommand>feh --bg-fill /root/wallpaper/bg.png</StartupCommand>
<RootMenu onroot="12">
    <Program label="Firefox">firefox</Program>
    <Program label="MicroEmulator">microemu</Program>
    <Program label="Terminal">xterm</Program>
    <Program label="Change VNC Password">change-vnc-password</Program>
    <Separator/>
    <Exit label="Exit"/>
</RootMenu>
<Tray x="0" y="-1" height="28">
    <TrayButton label="Menu">root:1</TrayButton>
    <TrayButton label="Firefox">exec:firefox</TrayButton>
    <TrayButton label="MicroEmulator">exec:microemu</TrayButton>
    <Spacer/>
    <Clock format="%H:%M"/>
</Tray>
<Desktops width="1" height="1"/>
</JWM>
EOF

# Download wallpaper
RUN mkdir -p /root/wallpaper \
    && wget -q -O /root/wallpaper/bg.png \
    https://raw.githubusercontent.com/gptfreego1-rjk/k/refs/heads/main/file_000000005cac81fa9d4eaed1715e5291.png

# Startup script (dengan password default "123456")
RUN cat >/startup.sh <<'EOF'
#!/bin/sh
export DISPLAY=:1
mkdir -p /root/.vnc

# Set default password 123456 jika belum ada
if [ ! -f /root/.vnc/passwd ]; then
    echo "Setting default VNC password: 123456"
    x11vnc -storepasswd 123456 /root/.vnc/passwd >/dev/null
fi

# Cleanup
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# Start X server
Xvfb :1 -screen 0 800x600x16 &
sleep 1

# Start JWM
jwm &

# Start VNC
x11vnc -display :1 -rfbport 5901 -rfbauth /root/.vnc/passwd -forever -shared -noxdamage -nowf &

wait
EOF

RUN chmod +x /startup.sh

EXPOSE 5901
WORKDIR /root
CMD ["/startup.sh"]
