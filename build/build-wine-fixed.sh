#!/bin/bash
# Build Wine with the MAA interactivity patch (run inside Ubuntu 24.04 container)
set -e
WINE_VERSION="${WINE_VERSION:-11.15}"
PREFIX="${PREFIX:-/opt/wine-fixed}"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential flex bison gettext \
  libx11-dev libxext-dev libxfixes-dev libxrandr-dev libxrender-dev \
  libxcomposite-dev libxinerama-dev libxcursor-dev libxi-dev \
  libxkbcommon-dev libgl-dev libegl-dev libgles-dev libpulse-dev \
  libfreetype-dev libfontconfig-dev libssl-dev libdbus-1-dev \
  libopenal-dev libudev-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libunwind-dev libxxf86vm-dev

if [ ! -f "wine-${WINE_VERSION}.tar.xz" ]; then
  curl -L --fail -o "wine-${WINE_VERSION}.tar.xz" \
    "https://dl.winehq.org/wine/source/${WINE_VERSION%%.*}.x/wine-${WINE_VERSION}.tar.xz"
fi
rm -rf "wine-${WINE_VERSION}" wine-build
tar -xJf "wine-${WINE_VERSION}.tar.xz"
mv "wine-${WINE_VERSION}" wine-src
cd wine-src
patch -p1 < ../patches/winex11.drv-ws-ex-transparent-client-input.patch
mkdir ../wine-build && cd ../wine-build
../wine-src/configure --enable-win64 --disable-tests --prefix="$PREFIX"
make -j"$(nproc)"
make install prefix="$PREFIX"
echo "Built Wine at $PREFIX"
