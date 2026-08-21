# MAA 从零部署记录（2026-08-21）

目标：在干净 `accetto/ubuntu-vnc-xfce-g3:latest` 桌面容器中部署 MAA Windows 版，
VNC 固定使用 **6080 端口**，并尽可能长期稳定。

最终环境已打包为 Docker 镜像：`maa-desktop:v2`。

## 1. VNC 从零重建（6080）

清掉旧的 `maa-desktop` 容器和卷后重新创建：

```bash
docker rm -f maa-desktop
rm -rf /opt/maa-desktop/config
mkdir -p /opt/maa-desktop/config
chown 1001:1001 /opt/maa-desktop/config

# 必须先把镜像默认家目录骨架复制进空卷，否则 vnc_startup 的 mkdir 不带 -p 会失败
docker run --rm --entrypoint /bin/sh accetto/ubuntu-vnc-xfce-g3:latest \
  -c 'tar -C /home/headless -cf - .' | tar -C /opt/maa-desktop/config -xf -
chown -R 1001:1001 /opt/maa-desktop/config

docker compose -f /opt/maa-desktop/docker-compose.yml up -d
```

compose 关键配置：

```yaml
ports:
  - "6080:6901"   # noVNC 网页
  - "5901:5901"   # VNC
environment:
  VNC_PW: <your-vnc-password>
  VNC_RESOLUTION: 1600x900
  TZ: Asia/Shanghai
  LANG: zh_CN.UTF-8
  LC_ALL: zh_CN.UTF-8
volumes:
  - /opt/maa-desktop/config:/home/headless
```

## 2. WineHQ Staging 11.15

容器系统是 **Ubuntu 24.04 (noble)**。

```bash
dpkg --add-architecture i386
mkdir -pm755 /etc/apt/keyrings
wget -qO- https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key
wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources
apt-get update
apt-get install -y --install-recommends winehq-staging   # 11.15
```

## 3. locale / 字体 / wine-mono / VC++

```bash
# 必须先生成 zh_CN.UTF-8，否则 Wine 读取中文文件名会乱码，MAA 资源加载失败
apt-get install -y locales
locale-gen zh_CN.UTF-8

apt-get install -y --no-install-recommends \
  fonts-noto-cjk fonts-wqy-zenhei fonts-symbola winetricks \
  unzip p7zip-full cabextract tesseract-ocr tesseract-ocr-chi-sim \
  x11-utils xdotool wmctrl imagemagick

# wine-mono 11.2.0 + VC++ 2015-2022 x64
mkdir -p /home/headless/Downloads /home/headless/.cache/wine
cd /home/headless/Downloads
wget https://dl.winehq.org/wine/wine-mono/11.2.0/wine-mono-11.2.0-x86.msi
wget https://aka.ms/vc14/vc_redist.x64.exe
cp wine-mono-11.2.0-x86.msi /home/headless/.cache/wine/

mkdir -p /home/headless/.wine-maa
chown -R headless:headless /home/headless

runuser -u headless -- env WINEPREFIX=/home/headless/.wine-maa WINEARCH=win64 \
  WINEDEBUG=-all DISPLAY=:1 wineboot -u

runuser -u headless -- env WINEPREFIX=/home/headless/.wine-maa WINEDEBUG=-all DISPLAY=:1 \
  wine reg add "HKCU\\Software\\Wine" /v Version /d win10 /f

runuser -u headless -- env WINEPREFIX=/home/headless/.wine-maa WINEDEBUG=-all DISPLAY=:1 \
  wine /home/headless/Downloads/vc_redist.x64.exe /quiet /norestart
```

## 4. 部署 MAA v6.16.8

```bash
docker cp /opt/maa-desktop/MAA-v6.16.8-win-x64.zip maa-desktop:/home/headless/Downloads/
runuser -u headless -- unzip -q /home/headless/Downloads/MAA-v6.16.8-win-x64.zip \
  -d /home/headless/MaaAssistantArknights
```

验证资源加载成功（有中文文件名，不能缺 locale）：

```bash
grep 'AsstLoadResource ret' /home/headless/MaaAssistantArknights/debug/gui.log
# 应为 true true
```

## 5. 透明窗口补丁（必须）

MAA 的“公告/弹窗”带 `WS_EX_TRANSPARENT`。
Wine 11.15 上游 `!8597` 会给这类窗口设置**空 input shape**，导致点击直接穿透到下层窗口。
仓库里的 `patches/winex11.drv-ws-ex-transparent-client-input.patch` 改为只保留客户端区域可交互。

另外可同时打 `patches/winex11.drv-skip-hidden-1x1-helper-windows.patch`，跳过隐藏 1×1 辅助窗口。

### 只编译 winex11.so（保留 WineHQ Staging 其余部分）

```bash
apt-get install -y build-essential flex bison gettext \
  libx11-dev libxext-dev libxfixes-dev libxrandr-dev libxrender-dev \
  libxcomposite-dev libxinerama-dev libxcursor-dev libxi-dev \
  libxkbcommon-dev libgl-dev libegl-dev libgles-dev libpulse-dev \
  libfreetype-dev libfontconfig-dev libssl-dev libdbus-1-dev \
  libopenal-dev libudev-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libunwind-dev libxxf86vm-dev

mkdir -p /opt/wine-src
# 下载 https://dl.winehq.org/wine/source/11.x/wine-11.15.tar.xz
# 解压后进入 wine 目录：
#   patch -p1 < client-input.patch
#   patch -p1 < skip-hidden.patch
mkdir build && cd build
../wine/configure --enable-win64 --disable-tests --without-mingw --without-vulkan
make -C dlls/winex11.drv -j$(nproc)
```

替换系统 Staging 的 Unix 端模块（PE 端不要动）：

```bash
cd /opt/wine-staging/lib/wine/x86_64-unix
cp winex11.so winex11.so.stock
cp /opt/wine-src/build/dlls/winex11.drv/winex11.so winex11.so
```

## 6. 当前已知状态与可用方案

- 打补丁后，“公告”窗口已经能成为鼠标指针下的目标窗口：
  `xdotool getmouselocation` 在公告上时返回公告窗口，而不是主窗口。
- **但 WPF 仍不消费鼠标消息**：spy 显示 `WM_LBUTTONDOWN` 发给“公告”后直接进
  `DefWindowProc` 返回 0。这是 Wine + .NET 10 WPF 的 `HwndWrapper` 输入问题，
  尚未找到 Wine 侧完全修复方案。
- **可用替代：MAA 全局热键能启动任务**。发送 `Ctrl+Shift+Alt+L` 会触发
  `LinkStart Enter`，即使公告窗未关闭也能开始执行任务队列。
  这可以作为长期自动化入口，不修改 MAA 文件。

```bash
DISPLAY=:1 xdotool key --clearmodifiers ctrl+shift+alt+l
```

## 7. 桌面快捷方式

已创建：

- `/home/headless/bin/maa.sh`：Wine 启动脚本
- `/home/headless/Desktop/MAA.desktop`：桌面快捷方式
- 可选：放到 `/home/headless/.config/autostart/` 可实现开机自启

## 8. 镜像固化

已提交镜像 `maa-desktop:v2`，compose 已改用该镜像：

```bash
docker commit maa-desktop maa-desktop:v2
# compose: image: maa-desktop:v2
docker compose up -d --force-recreate
```

下次重建容器时 Wine、补丁、MAA 和快捷方式都会保留。