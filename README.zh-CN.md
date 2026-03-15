# codex-claude-pipeline

[English](./README.md)

Claude Code + Codex 双 Agent 协作流程，通过 slash command 驱动。Claude Code 担任编排者和唯一代码编写者，Codex 作为只读顾问负责设计审查和代码审查。

## 功能概览

```
你（在 Claude Code 中）: /dual-agent 添加收藏功能

阶段一 — 设计辩论（自适应轮次）
  Claude Code 写设计文档  →  用户确认方向  →  Codex 审查  →  迭代

阶段二 — 实现
  Claude Code 实现已通过的设计，运行测试

阶段三 — 代码审查（自适应轮次）
  Codex 审查 git diff  →  Claude Code 修复  →  迭代
```

无需外部编排器。Claude Code 在自己的会话中通过 slash command 模板驱动整个流程。

## 安装

```bash
git clone https://github.com/liyuhao957/codex-claude-pipeline.git
cd codex-claude-pipeline
./install.sh
```

会将以下文件安装到主目录：
- `~/.claude/bin/codex-call` — Shell 封装脚本，以只读沙箱模式调用 Codex
- `~/.claude/commands/dual-agent.md` — 完整三阶段 slash command 模板
- `~/.claude/commands/dual-design.md` — 仅设计辩论
- `~/.claude/commands/dual-review.md` — 仅代码审查
- `~/.claude/prompts/dual-agent/architect.md` — 设计审查角色 prompt
- `~/.claude/prompts/dual-agent/reviewer.md` — 代码审查角色 prompt

## 使用方法

在任意 Claude Code 会话中（需要在 git 仓库内）：

```
/dual-agent 你的需求描述
/dual-design 你的需求描述   # 仅设计辩论，不实现
/dual-review [commit 范围]  # 仅代码审查
```

Claude Code 会自动按模板执行：分析项目、编写设计、调用 Codex 审查、实现代码、最后由 Codex 做代码审查。

## 核心特性

- **需求锚定**：用户原始需求通过 `<REQUIREMENT>` 标签逐字嵌入每次 Codex prompt，防止需求在多轮迭代中漂移。
- **三层分歧解决**：问题按类型分类——`[事实]`（必须跑代码或查文档验证）、`[取舍]`（翻译成用户能理解的利弊对比）、`[质量]`（Claude 自行判断并给出理由）。
- **验证优先心态**：处理 Codex 反馈时，Claude Code 默认假设 Codex 可能是对的，先验证再下结论。"我觉得不对"不是有效的拒绝理由。
- **用户检查点**：设计文档完成后，Claude Code 暂停让用户确认方向，确认后再发给 Codex。涉及需求范围变更的问题标记为 `deferred` 提交给用户决定。
- **原始输出透明**：Codex 的原始输出保存到 `.design/codex-raw-*.md`，用户可以审计 Codex 实际说了什么 vs Claude Code 如何解读。
- **自适应轮次**：无 P0/P1 → 一轮即过；有 P0 → 最多 3 轮；只有 P1 → 最多 2 轮；剩余问题全是已 deferred 的取舍类 → 直接通过。
- **自动收敛**：Codex 未报告新 P0/P1，或仅重复已拒绝的问题且无新技术反驳时，自动通过审查。
- **严重级别分类**：P0（必须修复）、P1（应当修复）、P2（建议改进，可跳过）。只有 P0/P1 驱动迭代。

## 产物

所有中间产物保存在项目的 `.design/` 目录下：

```
.design/
├── design.md                 # 设计文档（阶段一产出）
├── design-debate.md          # 设计辩论记录（阶段一）
├── changeset.md              # 实现改动摘要（阶段二产出）
├── diff.txt                  # git diff 快照（阶段三输入）
├── implementation-debate.md  # 代码审查辩论记录（阶段三）
├── codex-raw-design-*.md     # Codex 设计审查原始输出
├── codex-raw-review-*.md     # Codex 代码审查原始输出
└── .codex-session            # Codex 会话 ID（用于上下文复用）
```

| 文件 | 说明 |
|------|------|
| `design.md` | Claude Code 编写的设计文档，经过 Codex 审查后反复修改。包含原始需求原文。 |
| `design-debate.md` | 设计阶段完整辩论记录，包含列：ID、类型（`事实`/`取舍`/`质量`）、级别、问题、状态（`fixed`/`rejected`/`deferred`/`skipped`）、处理说明。 |
| `changeset.md` | 实现完成后的改动摘要：改了哪些文件、每个文件做了什么、风险点、需要人工确认的事项。 |
| `diff.txt` | `git diff` 的原始输出，导出为文件供 Codex 在代码审查阶段使用。 |
| `implementation-debate.md` | 代码审查阶段的辩论记录，格式同 `design-debate.md`。 |
| `codex-raw-*.md` | Codex 每轮的未加工输出——用户可核实 Claude Code 的解读是否准确。 |

## 工作原理

Slash command 模板（`dual-agent.md`）指示 Claude Code 遵循严格的三阶段协议：

1. **设计辩论** — Claude Code 编写 `.design/design.md`，经用户确认方向后，通过 `codex-call` 调用 Codex 审查。问题按 `[事实]`/`[取舍]`/`[质量]` 分类，走三层解决机制。自适应轮次。
2. **实现** — Claude Code 实现已通过的设计，编写 `.design/changeset.md`。
3. **代码审查** — Claude Code 生成 diff，调用 Codex 审查实际代码改动。同样的分类和解决规则。自适应轮次。

`codex-call` 是一个 Bash 封装脚本，负责定位 Codex 二进制文件、强制超时（默认 600 秒，可通过 `CODEX_TIMEOUT` 配置）、支持会话复用（`--session-file` / `--resume`）、保存原始输出（`--save-output`）。始终以 `--sandbox read-only` 运行 Codex。

## 环境要求

- macOS
- Git 仓库（slash command 会检查）
- `codex` CLI 在 PATH 中（或已安装 Codex.app）
- `claude` CLI（Claude Code）
- 可选：`timeout` 或 `gtimeout`（来自 coreutils）用于 Codex 调用超时

## 许可证

MIT
