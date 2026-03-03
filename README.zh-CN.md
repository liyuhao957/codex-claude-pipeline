# codex-claude-pipeline

[English](./README.md)

Claude Code + Codex 双 Agent 协作流程，通过 slash command 驱动。Claude Code 担任编排者和唯一代码编写者，Codex 作为只读顾问负责设计审查和代码审查。

## 功能概览

```
你（在 Claude Code 中）: /dual-agent 添加收藏功能

阶段一 — 设计辩论（最多 3 轮）
  Claude Code 写设计文档  →  Codex 审查  →  迭代直到没有 P0/P1

阶段二 — 实现
  Claude Code 实现已通过的设计，运行测试

阶段三 — 代码审查（最多 3 轮）
  Codex 审查 git diff  →  Claude Code 修复  →  迭代直到没有 P0/P1
```

无需外部编排器。Claude Code 在自己的会话中通过 slash command 模板驱动整个流程。

## 安装

```bash
git clone https://github.com/liyuhao957/codex-claude-pipeline.git
cd codex-claude-pipeline
./install.sh
```

会将两个文件安装到你的主目录：
- `~/.claude/bin/codex-call` — Shell 封装脚本，以只读沙箱模式调用 Codex
- `~/.claude/commands/dual-agent.md` — Slash command 模板，定义三阶段流程

## 使用方法

在任意 Claude Code 会话中（需要在 git 仓库内）：

```
/dual-agent 你的需求描述
```

Claude Code 会自动按模板执行：分析项目、编写设计、调用 Codex 审查、实现代码、最后由 Codex 做代码审查。

## 核心特性

- **带上下文的辩论**：第 2 轮起，Codex prompt 中附上完整辩论记录，明确指示不要重复已拒绝的问题——消除无效轮次。
- **自动收敛**：Codex 未报告新 P0/P1，或仅重复已拒绝的问题且无新技术反驳时，自动通过审查。
- **清洁工作区**：每次运行开始时清除 `.design/`，防止上次任务的残留文件干扰。
- **提交提示**：流程完成后询问是否 git commit，无需手动操作。
- **严重级别分类**：P0（必须修复）、P1（应当修复）、P2（建议改进，可跳过）。只有 P0/P1 驱动迭代。

## 产物

所有中间产物保存在项目的 `.design/` 目录下：

```
.design/
├── design.md                # 设计文档（阶段一产出）
├── design-debate.md         # 设计辩论记录（阶段一）
├── changeset.md             # 实现改动摘要（阶段二产出）
├── diff.txt                 # git diff 快照（阶段三输入）
└── implementation-debate.md # 代码审查辩论记录（阶段三）
```

| 文件 | 说明 |
|------|------|
| `design.md` | Claude Code 编写的设计文档，经过 Codex 审查后反复修改，最终定稿的版本，包含目标、改动范围、边界情况等。 |
| `design-debate.md` | 设计阶段的完整辩论记录：每轮 Codex 提了什么问题，Claude Code 是接受修复还是拒绝及其理由。 |
| `changeset.md` | 实现完成后的改动摘要：改了哪些文件、每个文件做了什么、风险点、需要人工确认的事项。 |
| `diff.txt` | `git diff` 的原始输出，导出为文件供 Codex 在代码审查阶段使用。 |
| `implementation-debate.md` | 代码审查阶段的辩论记录，格式同 `design-debate.md`：Codex 对实际代码的审查意见和 Claude Code 的处理决定。 |

## 工作原理

Slash command 模板（`dual-agent.md`）指示 Claude Code 遵循严格的三阶段协议：

1. **设计辩论** — Claude Code 编写 `.design/design.md`，然后通过 `codex-call` 调用 Codex 审查。P0/P1 问题必须修复或给出反驳理由；P2 可选。最多 3 轮。
2. **实现** — Claude Code 实现已通过的设计，编写 `.design/changeset.md`。
3. **代码审查** — Claude Code 生成 diff，调用 Codex 审查实际代码改动。同样的 P0/P1/P2 规则。最多 3 轮。

`codex-call` 是一个轻量 Bash 封装脚本，负责定位 Codex 二进制文件、强制超时（默认 600 秒，可通过 `CODEX_TIMEOUT` 配置）、始终以 `--sandbox read-only` 运行 Codex。

## 环境要求

- macOS
- Git 仓库（slash command 会检查）
- `codex` CLI 在 PATH 中（或已安装 Codex.app）
- `claude` CLI（Claude Code）
- 可选：`timeout` 或 `gtimeout`（来自 coreutils）用于 Codex 调用超时

## 许可证

MIT
