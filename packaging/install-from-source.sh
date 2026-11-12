#!/usr/bin/env bash
# Builds Lian Li Linux from this checkout and installs it system-wide, following
# docs/building-from-source.md. Run it again to update an existing source install.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: packaging/install-from-source.sh [--skip-deps] [--no-pull]

  --skip-deps  Do not install build and runtime dependencies.
  --no-pull    Build the checkout as it is, without pulling the latest commits.
EOF
}

install_deps=1
pull=1
for arg in "$@"; do
  case "$arg" in
    --skip-deps) install_deps=0 ;;
    --no-pull) pull=0 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

step() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [ "$(id -u)" -eq 0 ]; then
  fail "run this as your normal user. It asks for sudo when it needs it."
fi

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"
if [ ! -f Cargo.toml ] || [ ! -d crates/lianli-daemon ]; then
  fail "$repo is not a Lian Li Linux checkout."
fi

# shellcheck disable=SC1091
. /etc/os-release
distro="unknown"
case " ${ID:-} ${ID_LIKE:-} " in
  *" arch "*) distro="arch" ;;
  *" fedora "*) distro="fedora" ;;
  *" debian "* | *" ubuntu "*) distro="debian" ;;
esac

package_owner() {
  case "$distro" in
    arch) pacman -Qqo "$1" 2>/dev/null ;;
    debian) dpkg -S "$1" 2>/dev/null | cut -d: -f1 ;;
    fedora) rpm -qf --qf '%{NAME}\n' "$1" 2>/dev/null ;;
    *) return 1 ;;
  esac
}

if [ -e /usr/bin/lianli-gui ] && owner="$(package_owner /usr/bin/lianli-gui)" && [ -n "$owner" ]; then
  fail "/usr/bin/lianli-gui belongs to the '$owner' package, whose updates would replace this build.
Remove that package first, then run this script again."
fi

step "Requesting administrator access"
sudo -v

if [ "$install_deps" -eq 1 ]; then
  step "Installing dependencies"
  have_cargo=0
  command -v cargo >/dev/null 2>&1 && have_cargo=1
  case "$distro" in
    arch)
      packages=(git libusb ffmpeg fontconfig mesa libxkbcommon wayland libx11 libinput libdrm
        libjpeg-turbo clang cmake pkg-config nasm npm
        webkit2gtk-4.1 gtk3 glib2 libsoup3 libayatana-appindicator librsvg)
      [ "$have_cargo" -eq 1 ] || packages+=(rustup)
      sudo pacman -S --needed "${packages[@]}"
      ;;
    debian)
      packages=(git libusb-1.0-0-dev libudev-dev libfontconfig-dev
        libxkbcommon-dev libwayland-dev libx11-dev libinput-dev libdrm-dev
        libgl-dev libegl-dev clang cmake pkg-config ffmpeg nasm npm
        libavcodec-dev libavformat-dev libswscale-dev libavutil-dev libavfilter-dev
        libwebkit2gtk-4.1-dev libglib2.0-dev libgtk-3-dev libsoup-3.0-dev
        libayatana-appindicator3-dev librsvg2-dev)
      [ "$have_cargo" -eq 1 ] || packages+=(rustup)
      sudo apt-get update
      sudo apt-get install "${packages[@]}"
      ;;
    fedora)
      packages=(git libusb1-devel fontconfig-devel
        libxkbcommon-devel wayland-devel libX11-devel libinput-devel libdrm-devel
        mesa-libGL-devel mesa-libEGL-devel clang cmake pkg-config ffmpeg
        ffmpeg-devel nasm npm
        webkit2gtk4.1-devel gtk3-devel glib2-devel libsoup3-devel
        libappindicator-gtk3-devel librsvg2-devel)
      [ "$have_cargo" -eq 1 ] || packages+=(rustup)
      sudo dnf install "${packages[@]}"
      ;;
    *)
      note "Unrecognised distribution. Install the dependencies listed in"
      note "docs/building-from-source.md, then run this script with --skip-deps."
      exit 1
      ;;
  esac
fi

if command -v rustup >/dev/null 2>&1; then
  step "Preparing the Rust toolchain"
  rustup toolchain install || rustup show active-toolchain
fi
command -v cargo >/dev/null 2>&1 || fail "cargo was not found. Install Rust from https://rustup.rs and run this script again."
command -v npm >/dev/null 2>&1 || fail "npm was not found. Install it and run this script again."

if [ "$pull" -eq 1 ] && [ -d .git ]; then
  step "Updating the source"
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    note "Local changes found, so the checkout is built as it is."
  elif ! git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
    note "This branch has no upstream, so the checkout is built as it is."
  else
    git pull --ff-only
  fi
fi
if [ -d .git ]; then
  git submodule update --init --recursive
fi

step "Building (this can take a while the first time)"
cargo build --release

step "Installing files"
inst() { sudo install -Dm"$1" "$2" "$3"; }

for bin in lianli-daemon lianli-gui lianli-session lianli-control; do
  inst 755 "target/release/$bin" "/usr/bin/$bin"
done

inst 644 packaging/udev/60-lianli.rules /usr/lib/udev/rules.d/60-lianli.rules

inst 644 packaging/systemd/lianli-session.service /usr/lib/systemd/user/lianli-session.service
sudo install -d /usr/lib/systemd/user/default.target.wants
sudo ln -sfn ../lianli-session.service /usr/lib/systemd/user/default.target.wants/lianli-session.service
inst 644 packaging/desktop/com.sgtaziz.lianlilinux.session.desktop /etc/xdg/autostart/com.sgtaziz.lianlilinux.session.desktop
inst 644 packaging/systemd/lianli-daemon.service /usr/lib/systemd/user/lianli-daemon.service
inst 644 packaging/systemd/lianli-daemon-system.service /usr/lib/systemd/system/lianli-daemon-system.service
inst 644 packaging/systemd/lianli-control-recovery.service /usr/lib/systemd/system/lianli-control-recovery.service
sudo install -d /usr/lib/systemd/system/multi-user.target.wants
sudo ln -sfn ../lianli-control-recovery.service /usr/lib/systemd/system/multi-user.target.wants/lianli-control-recovery.service
inst 644 packaging/polkit/49-lianli-recovery.rules /usr/share/polkit-1/rules.d/49-lianli-recovery.rules
inst 644 packaging/desktop/com.sgtaziz.lianlilinux.recovery.desktop /etc/xdg/autostart/com.sgtaziz.lianlilinux.recovery.desktop
inst 644 packaging/sysusers.d/lianli.conf /usr/lib/sysusers.d/lianli.conf
inst 644 packaging/tmpfiles.d/lianli.conf /usr/lib/tmpfiles.d/lianli.conf

inst 644 packaging/desktop/com.sgtaziz.lianlilinux.desktop /usr/share/applications/com.sgtaziz.lianlilinux.desktop
inst 644 packaging/desktop/com.sgtaziz.lianlilinux.metainfo.xml /usr/share/metainfo/com.sgtaziz.lianlilinux.metainfo.xml
for page in packaging/man/*.1; do
  inst 644 "$page" "/usr/share/man/man1/$(basename "$page")"
done
inst 644 assets/icons/32x32.png /usr/share/icons/hicolor/32x32/apps/com.sgtaziz.lianlilinux.png
inst 644 assets/icons/128x128.png /usr/share/icons/hicolor/128x128/apps/com.sgtaziz.lianlilinux.png
inst 644 assets/icons/128x128@2x.png /usr/share/icons/hicolor/256x256/apps/com.sgtaziz.lianlilinux.png
inst 644 assets/icons/icon.svg /usr/share/icons/hicolor/scalable/apps/com.sgtaziz.lianlilinux.svg

if modinfo evdi >/dev/null 2>&1; then
  inst 644 packaging/modules-load.d/lianli-evdi.conf /usr/lib/modules-load.d/lianli-evdi.conf
fi

step "Applying system configuration"
sudo systemd-sysusers lianli.conf
sudo systemd-tmpfiles --create lianli.conf
sudo udevadm control --reload-rules
sudo udevadm trigger
if [ -e /sys/module/evdi ]; then
  sudo udevadm trigger --action=add /sys/module/evdi
fi
sudo systemctl daemon-reload
systemctl --user daemon-reload 2>/dev/null || true
if command -v update-desktop-database >/dev/null 2>&1; then
  sudo update-desktop-database -q /usr/share/applications
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  sudo gtk-update-icon-cache -q -t /usr/share/icons/hicolor
fi

step "Restarting running services"
restarted=0
if systemctl --user is-active --quiet lianli-daemon.service 2>/dev/null; then
  systemctl --user restart lianli-daemon.service
  note "Restarted the user daemon."
  restarted=1
fi
if systemctl is-active --quiet lianli-daemon-system.service; then
  sudo systemctl restart lianli-daemon-system.service
  note "Restarted the system daemon."
  restarted=1
fi
if systemctl --user is-active --quiet lianli-session.service 2>/dev/null; then
  systemctl --user restart lianli-session.service
fi
if [ "$restarted" -eq 0 ] && pgrep -x lianli-daemon >/dev/null 2>&1; then
  note "A daemon started outside systemd is still running the previous build."
  note "Stop it, then choose a service mode in the app so it starts automatically."
fi

step "Done"
if [ -d .git ]; then
  note "Installed $(git --no-pager log --oneline -1)."
fi
if [ "$restarted" -eq 0 ]; then
  note "Open Lian Li Linux and, under Services, choose User (at login) or"
  note "System (at boot), then Enable and start. Only one mode can run at a time."
else
  note "Reopen Lian Li Linux to use the new version."
fi
