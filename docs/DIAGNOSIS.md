# MAA 公告/主界面无法点击滚动 — 诊断记录

## 现象
- MAA WPF 窗口正常显示，但所有鼠标点击、滚轮、键盘都没有效果。
- Wine 调试确认：
  - Wine 能收到 X 事件，并生成正确的 `WM_LBUTTONDOWN` / `WM_LBUTTONUP` / `WM_MOUSEWHEEL`。
  - 消息发到正确的“公告”HWND（例如 `0x20080`），lParam 坐标也正确（如 `0x01370177` = 客户端 (375,311)）。
  - 窗口不是 disabled、不是 hung、是 foreground。
- 但 `spy` 显示 WPF 的窗口过程收到这些消息后**直接走 `DefWindowProc` 并返回 0**，也就是 WPF 没有把鼠标消息交给自己的输入系统处理。

## 结论
问题不在 X 输入路由，也不在隐藏窗口抢输入（已通过补丁消除 `.NET-BroadcastEventWindow` 等 1×1 窗口）。
真正断点在 **WPF 的 `HwndWrapper` 窗口过程没有处理鼠标消息**，疑似 Wine 对 .NET 10 WPF 的窗口子类化 / HwndSource 输入挂钩支持不完整。

## 下一步建议
1. 深入研究 Wine 的 `SetWindowLongPtr` / `HwndSubclass` 子类化路径，确认 .NET 10 WPF 的 `HwndWrapper.WndProc` 是否被正确安装。
2. 或在 Wine 中实现/修正 WPF 依赖的输入初始化消息，使 `HwndSource` 进入可接收鼠标输入的状态。
3. 短期可用替代：MAA Linux 原生/CLI（不依赖 WPF），或固定一个在 Wine 下可用的旧版 MAA。
