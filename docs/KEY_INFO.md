# MAA 桌面容器关键信息（2026-08-21 压缩对话用）

## 当前最终状态
- **MAA 已关闭**，容器 `maa-desktop` 仍在运行。
- 镜像：`maa-desktop:v2`，`/opt/maa-desktop/docker-compose.yml` 已改用该镜像。
- VNC/noVNC 正常，端口 `6080`。
- **鼠标输入已修复**：关闭 MAA 桌面通知后，主窗口可正常点击。
- GitHub 已更新到 `2cb7193`，仓库当前无泄露；但 VNC 密码曾被旧历史公开过，**建议尽快轮换**。

## 访问方式
- 宿主机命令：`./sshx.sh "<命令>"`（自动使用 ed25519 key + askpass）
- 容器：`maa-desktop`
- 项目目录：`/opt/maa-desktop/docker-compose.yml`
- 端口：`6080:6901`（noVNC）、`5901:5901`（VNC）
- noVNC：`http://<your-host>:6080/vnc.html`
- VNC 密码：`<your-vnc-password>`
- 桌面用户：`headless`（uid/gid 1001），家目录持久化在 `/opt/maa-desktop/config`

## 安全记录（重要）
- GitHub 仓库 `alpinekit-bot1/wine-maa-fix` 是 **public**。
- 之前旧提交历史曾包含公网 IP 和 VNC 密码，现已通过 `git filter-branch` 重写历史并强制推送清除。
- 当前远程文件和历史扫描均无真实密码/IP。
- 但 public 仓库旧历史曾短暂公开，**VNC 密码视为已泄露**，压缩后第一件事建议：
  - 修改 `/opt/maa-desktop/.env` 的 `VNC_PW`
  - 重建容器 `docker compose up -d --force-recreate`
  - 考虑把 GitHub 仓库设为 private
- 仓库内未发现 GitHub Token、SSH 密钥或口令。

## 关键环境
- 容器系统：Ubuntu 24.04 (noble)
- Wine：WineHQ Staging `11.15`（apt 安装）
- wine-mono：`11.2.0`
- VC++ Redistributable：已安装到 Wine prefix
- .NET 8 Desktop Runtime `8.0.30`：已安装到 Wine prefix（用于测试旧版 MAA）
- 中文字体：Noto CJK、文泉驿正黑、Symbola
- locale：已生成 `zh_CN.UTF-8`（**必须**，否则 MAA 中文资源加载失败）

## MAA 安装
- 主用：`/home/headless/MaaAssistantArknights/MAA.exe`（v6.16.8）
- 备用旧版：`/home/headless/MAA-v5.28.5/MAA.exe`（v5.28.5，已下载，需 .NET 8 运行时）
- 启动脚本：`/home/headless/bin/maa.sh`
- 桌面快捷方式：`/home/headless/Desktop/MAA.desktop`
- 下载目录：`/home/headless/Downloads/`

## 关键技术结论 / 修复
1. **VNC 从零重建**：空卷必须先复制镜像默认家目录骨架，否则 `vnc_startup` 的 `mkdir` 不带 `-p` 会失败：
   ```bash
   docker run --rm --entrypoint /bin/sh accetto/ubuntu-vnc-xfce-g3:latest \
     -c 'tar -C /home/headless -cf - .' | tar -C /opt/maa-desktop/config -xf -
   chown -R 1001:1001 /opt/maa-desktop/config
   ```
2. **Wine 补丁 winex11.so**：已编译并替换
   - 路径：`/opt/wine-staging/lib/wine/x86_64-unix/winex11.so`
   - 原版备份：`/opt/wine-staging/lib/wine/x86_64-unix/winex11.so.stock`
   - 补丁：`client-input.patch` + `skip-hidden.patch`（仓库 `patches/`）
3. **鼠标输入修复（最重要）**
   - 根因：MAA 的桌面通知 `ToastWindow` 是全屏透明覆盖层，会抢占鼠标输入。
   - 修复：编辑 `/home/headless/MaaAssistantArknights/config/gui.new.json`：
     ```json
     "Gui": {
       "UseNotify": false,
       "LoadWindowPlacement": false,
       "SaveWindowPlacement": false
     }
     ```
   - 关闭后重启 MAA，`ToastWindow` 消失，主窗口鼠标可正常点击/切换页面。
4. **热键备份方案**（鼠标修复前/后都可用）：
   ```bash
   DISPLAY=:1 xdotool key --clearmodifiers ctrl+shift+alt+l
   ```
   触发 `LinkStart` 开始任务。

## 常用命令
```bash
# 启动 MAA
docker exec -d -u root maa-desktop bash -c \
  'runuser -u headless -- env DISPLAY=:1 nohup /home/headless/bin/maa.sh >/tmp/maa.log 2>&1 &'

# 停止 MAA
docker exec -u root maa-desktop bash -c \
  'runuser -u headless -- env WINEPREFIX=/home/headless/.wine-maa WINEDEBUG=-all DISPLAY=:1 wineserver -k; pkill -x MAA.exe || true'

# 查看日志
docker exec maa-desktop tail -n 50 /home/headless/MaaAssistantArknights/debug/gui.log
```

## 下一步
- **立即轮换 VNC 密码**（因旧历史曾公开）。
- 配置 MAA 的 ADB/模拟器连接（例如 `127.0.0.1:5555` 或备用机地址）。
- 可做开机自启：把 `MAA.desktop` 放进 `.config/autostart/`，并启动后自动发热键。
- 旧镜像 `maa-desktop:v1`（6.4GB）可删除释放空间。
- 完整从零部署步骤见仓库 `docs/SETUP_FROM_ZERO.md`。

## GitHub 仓库
- 仓库：`alpinekit-bot1/wine-maa-fix`
- 地址：https://github.com/alpinekit-bot1/wine-maa-fix
- 最新提交：`2cb7193`（历史已清洗，文档可复现）
- 关键文档：`docs/SETUP_FROM_ZERO.md`、`docs/KEY_INFO.md`