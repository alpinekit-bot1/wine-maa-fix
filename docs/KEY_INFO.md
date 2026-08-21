# MAA 桌面容器关键信息（压缩对话用）

## 主机/远程
- 宿主机：Ubuntu 22.04，Docker 29.7.2，8 核 / 16GB / 78GB 磁盘
- 通过本目录 `./sshx.sh` 执行宿主机命令（自动使用 ed25519 key + askpass）
- 容器：`maa-desktop`
- 项目目录：`/opt/maa-desktop/docker-compose.yml`
- 端口：`6080:6901`（noVNC 网页）、`5901:5901`（VNC）
- noVNC 地址：`http://<your-host>:6080/vnc.html`
- VNC 密码：`<your-vnc-password>`
- 桌面用户：`headless`（uid/gid 1001），家目录持久化在 `/opt/maa-desktop/config`

## GitHub 仓库
- 仓库：`alpinekit-bot1/wine-maa-fix`
- 地址：https://github.com/alpinekit-bot1/wine-maa-fix
- 已包含补丁：
  - `patches/winex11.drv-ws-ex-transparent-shapeinput.patch`（上游 MR !8597）
  - `patches/winex11.drv-ws-ex-transparent-client-input.patch`（保留弹窗客户端区域可交互）
  - `patches/winex11.drv-skip-hidden-1x1-helper-windows.patch`（跳过隐藏 1×1 辅助窗口，防止抢输入）
- 诊断文档：`docs/DIAGNOSIS.md`

## 已深挖到的根因
- Wine 能正确把 `WM_LBUTTONDOWN` / `WM_MOUSEWHEEL` 发给 MAA“公告”窗口，坐标正确。
- MAA 窗口非禁用、非卡死、是前台窗口。
- 但 WPF 的 `HwndWrapper` 窗口过程收到鼠标消息后直接走 `DefWindowProc` 返回 0，即 WPF 输入系统没有接住。
- 结论：问题在 Wine 对 .NET 10 WPF 的窗口子类化 / `HwndSource` 输入挂钩支持不完整，不是 X 输入路由问题。

## 已做过的尝试与结果
- Wine Staging 11.15 + wine-mono 11.2.0 + 中文字体 + Symbola：MAA 可启动。
- 编译替换 winex11.so：隐藏 1×1 窗口可消除，但 WPF 鼠标仍不响应。
- 手动安装 VC++ Redistributable `vc_redist.x64.exe`：已安装，`vcruntime140.dll`/`msvcp140.dll` 存在，但预计不解决 WPF 鼠标问题。
- 用户决定：卸掉当前 Wine，从干净桌面镜像重新开始。

## 当前重置决定
- 将容器从 `maa-desktop:v1`（含 Wine）重置为 `accetto/ubuntu-vnc-xfce-g3:latest`（干净桌面）。
- 清理卷里 Wine/MAA 相关目录：
  - `/opt/maa-desktop/config/.wine-maa`
  - `/opt/maa-desktop/config/MaaAssistantArknights`
  - `/opt/maa-desktop/config/MAA`
  - `/opt/maa-desktop/config/MAA-linux`
  - `/opt/maa-desktop/config/.config/autostart/maa.desktop`
  - `/opt/maa-desktop/config/.config/maa`