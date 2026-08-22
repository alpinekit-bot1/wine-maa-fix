# redroid + 明日方舟 + MAA 互通（本仓库配套）

MAA-Wine 容器（`maa-desktop`）与 redroid 容器互通的核心：

1. 两个容器都加入同一个 Docker 外部网络 `maa-net`。
2. MAA 的连接地址使用 Docker DNS 主机名 `redroid:5555`，不要用宿主机 IP。
3. Windows 版 adb.exe 在 MAA 容器内路径：
   `Z:\home\headless\platform-tools\platform-tools\adb.exe`

MAA GUI 配置片段：

```json
"ConnectSettings": {
  "AutoDetect": false,
  "AlwaysAutoDetect": false,
  "AdbPath": "Z:\\home\\headless\\platform-tools\\platform-tools\\adb.exe",
  "Address": "redroid:5555",
  "AddressHistory": ["redroid:5555"]
}
```

验证：

```bash
docker exec -u headless -e WINEPREFIX=/home/headless/.wine-maa -e WINEDEBUG=-all \
  maa-desktop wine /home/headless/platform-tools/platform-tools/adb.exe connect redroid:5555
docker exec -u headless -e WINEPREFIX=/home/headless/.wine-maa -e WINEDEBUG=-all \
  maa-desktop wine /home/headless/platform-tools/platform-tools/adb.exe devices
```

redroid 定制镜像（自动打包最新明日方舟、性能调优、MSA 补丁）见：
https://github.com/alpinekit-bot1/redroid-arknights-image

宿主机关键参数（防止 lmkd 崩溃/黑屏）：
- boot cmdline：`systemd.unified_cgroup_hierarchy=0 psi=1`
- redroid command：`androidboot.redroid_gpu_mode=guest`