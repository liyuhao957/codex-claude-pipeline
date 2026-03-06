# Claude Anime - 终端像素动画设计

## 概述

在终端中显示像素风动画，实时反映 Claude Code 的工作状态。通过 tmux 左右分屏，左侧运行 Claude Code，右侧显示俯视角像素风办公室场景。

## 技术方案

**方案：Claude Code Hooks + 状态文件**

- Hooks 在事件触发时写入状态到 `/tmp/claude-anime-state`
- 动画播放器每 200ms 轮询状态文件，渲染对应帧
- 用 `▀`/`▄` + 24-bit true color ANSI 实现像素渲染

## 动画状态

| 状态 | 触发条件 | 场景表现 |
|------|---------|---------|
| coding | PreToolUse: Bash/Edit/Write | 小人坐桌前敲键盘，显示器有代码滚动 |
| thinking | PreToolUse: Task/Glob/Grep/Read | 小人离开键盘，头上冒思考泡泡 |
| waiting | Notification | 小人转向镜头，头上问号闪烁 |
| done | Stop | 显示器显示 ✓，周围撒花效果 |

## Hooks 配置

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash|Edit|Write|NotebookEdit",
      "hooks": [{"type": "command", "command": "echo coding > /tmp/claude-anime-state"}]
    },
    {
      "matcher": "Task|Glob|Grep|Read",
      "hooks": [{"type": "command", "command": "echo thinking > /tmp/claude-anime-state"}]
    }
  ],
  "Notification": [
    {
      "matcher": "",
      "hooks": [{"type": "command", "command": "echo waiting > /tmp/claude-anime-state"}]
    }
  ],
  "Stop": [
    {
      "matcher": "",
      "hooks": [{"type": "command", "command": "echo done > /tmp/claude-anime-state"}]
    }
  ]
}
```

## 文件结构

```
claude-anime/
├── claude-anime           # 启动器（bash）：创建 tmux 分屏
├── claude-anime-player    # 动画播放器（python）：渲染像素帧
├── frames/                # 像素帧数据（python 模块）
│   ├── coding.py
│   ├── thinking.py
│   ├── waiting.py
│   └── done.py
└── install.sh             # 安装脚本
```

## 启动方式

```bash
claude-anime [claude-code-args...]
```

自动创建 tmux session，左侧 70% 跑 Claude Code，右侧 30% 跑动画。

## 像素渲染原理

每个终端字符格用 `▀` 字符，前景色=上像素，背景色=下像素，实现 2:1 垂直分辨率。50 列 × 50 行 pane ≈ 50×100 有效像素。

## 视觉风格

像素风俯视角办公室（参考 RPG Maker / 像素办公模拟器风格）：
- 桌子、显示器、键盘、椅子
- 书架、植物、咖啡杯等装饰
- 可爱的小人角色
- 丰富的 ANSI 颜色

## 依赖

- Python 3（macOS 自带）
- tmux（`brew install tmux`）
