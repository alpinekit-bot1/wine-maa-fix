# wine-maa-fix

Custom Wine patch for MAA (MaaAssistantArknights) under Wine + VNC/noVNC.

## Problem

MAA's announcement/popup windows (WPF, layered/transparent) create X11 input-shim
windows that swallow VNC/XTEST pointer events. The main window becomes effectively
unclickable over VNC even though the application itself is healthy.

## Fix

The root cause is Wine's X11 driver not honoring `WS_EX_TRANSPARENT` mouse
pass-through. The upstream fix is Wine merge request !8597:

- [winex11.drv: Implement WS_EX_TRANSPARENT mouse pass-through with ShapeInput extension](https://gitlab.winehq.org/wine/wine/-/merge_requests/8597)

It was merged into Wine master and is included in the Wine 11.15+ packages used by
this project.

This repository keeps the exact backport patch and build notes so the fix can be
rebuilt from source.

## Files

- `patches/winex11.drv-ws-ex-transparent-shapeinput.patch` — the `dlls/winex11.drv/window.c` change from Wine !8597.
- `build/` — scripts to apply and build Wine from source.

## Quick build

```bash
# Ubuntu 24.04 (container)
apt-get update
apt-get install -y build-essential flex bison libx11-dev libxext-dev libxfixes-dev \
  libxrandr-dev libxrender-dev libxcomposite-dev libxinerama-dev libxcursor-dev \
  libxi-dev libxkbcommon-dev libgl-dev libegl-dev libgles-dev libpulse-dev \
  libfreetype-dev libfontconfig-dev libssl-dev libdbus-1-dev libopenal-dev \
  libudev-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev

git clone --depth 1 --branch wine-11.15 https://gitlab.winehq.org/wine/wine.git
cd wine
git apply ../patches/winex11.drv-ws-ex-transparent-shapeinput.patch

mkdir build && cd build
../configure --enable-win64
make -j$(nproc)
```

## Deployment

The container image `maa-desktop:v1` already includes Wine 11.15 Staging built with
this fix. Recreate the container to pick up the fixed Wine:

```bash
cd /opt/maa-desktop
docker compose up -d --force-recreate
```

## Additional custom patch for MAA dialog interactivity

Wine's upstream !8597 sets an *empty* input shape for every `WS_EX_TRANSPARENT`
window. That makes fully transparent overlays click-through correctly, but it also
makes WPF dialogs that use `WS_EX_TRANSPARENT` (like MAA's announcement) unable to
receive mouse wheel/button events inside their visible client area.

`patches/winex11.drv-ws-ex-transparent-client-input.patch` changes the behavior:
- mouse event masks are always enabled on the whole window;
- for `WS_EX_TRANSPARENT` windows the input shape is set to the **client rectangle**
  instead of empty, so transparent margins pass through while the actual dialog
  content remains interactive.
