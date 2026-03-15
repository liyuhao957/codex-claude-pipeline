# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Claude Code + Codex 双 Agent 协作系统。通过 slash command 驱动，Claude Code 负责编排和编码，Codex 作为只读顾问提供设计审查和代码审查。

## 安装与开发

```bash
./install.sh          # 安装所有文件到 ~/.claude/
```

安装目标：
- `~/.claude/bin/codex-call` — Codex CLI wrapper
- `~/.claude/commands/dual-agent.md` — 完整三阶段 slash command
- `~/.claude/commands/dual-design.md` — 仅设计辩论
- `~/.claude/commands/dual-review.md` — 仅代码审查
- `~/.claude/prompts/dual-agent/architect.md` — 设计审查角色 prompt
- `~/.claude/prompts/dual-agent/reviewer.md` — 代码审查角色 prompt

修改源文件后需重新运行 `install.sh` 才能在 Claude Code 中生效。

无构建步骤、无测试套件、无 lint。验证方式：`bash -n codex-call`（语法检查）。

## 架构

**数据流**：用户通过 `/dual-agent <需求>` 触发 → Claude Code 按 `dual-agent.md` 模板执行三阶段流程 → 每阶段通过 `codex-call` 调用 Codex CLI → 所有产物写入 `.design/` 目录。

**核心约束**：
- Codex 始终 `--sandbox read-only`，不能写文件
- Claude Code 是唯一的代码编写者
- 所有传给 Codex 的内容必须内联到 prompt 中（Codex 不自己读文件）

**三阶段流程**（`dual-agent.md`）：
1. 设计辩论 — Claude 写 design.md → Codex 审查 → 迭代修复
2. 实现 — Claude 按设计编码 → 写 changeset.md
3. 代码审查 — Codex 审查 diff → Claude 修复 → 迭代收敛

**分歧解决机制**（三层）：
- `[事实]` 类问题 → 必须通过跑代码/查文档验证，不靠辩论
- `[取舍]` 类问题 → 翻译成用户能理解的利弊，让用户选或走保守方案
- `[质量]` 类问题 → Claude 自行判断

**codex-call**（Bash wrapper）：
- 解析 `--session-file`（session 复用）、`--resume`（续接会话）、`--save-output`（原始输出存档）
- 简单模式直接 exec codex；session 模式用 python3 解析 JSON 事件流提取文本和 session ID
- 超时通过 `timeout`/`gtimeout` 实现，macOS 默认无 `timeout` 需 fallback

**角色 prompt**（`prompts/`）：
- 要求精确而非刻薄，每个 FAIL 必须附可验证依据
- 问题分三类标注 `[事实]`/`[取舍]`/`[质量]`
- 不适用的检查项标 `[N/A]` 而非强行 PASS

## 关键约定

- 每次 Codex prompt 必须包含 `<REQUIREMENT>` 标签锚定用户原始需求
- 处理 Codex 反馈时采用验证者心态：默认假设 Codex 可能是对的，先查证再下结论
- 设计文档写完后先给用户确认方向，再发 Codex 审查
- 自适应轮次：无 P0/P1 一轮即过；有 P0 最多 3 轮；只有 P1 最多 2 轮
- 辩论记录状态：`fixed` / `rejected`（附验证过程）/ `deferred`（交用户）/ `skipped`
- 运行时产物全部在 `.design/` 目录，包括 `codex-raw-*.md`（Codex 原始输出，可审计）
- 项目可通过 `.claude/codex-context.md` 声明额外上下文文件，首轮内联到 Codex prompt
