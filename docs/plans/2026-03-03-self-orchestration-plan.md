# Dual-Agent 自编排改造 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 dual-agent 从外部 Python 脚本改为 Claude Code 自编排模式（slash command + shell wrapper）

**Architecture:** 两个文件：`~/.claude/bin/codex-call`（shell wrapper 调 Codex）+ `~/.claude/commands/dual-agent.md`（编排模板）。Claude Code 是编排器和唯一代码编写者，Codex 是只读顾问。

**Tech Stack:** Bash (wrapper), Markdown (slash command template), Codex CLI

---

### Task 1: Create codex-call wrapper

**Files:**
- Create: `codex-call`（项目内开发，最终安装到 `~/.claude/bin/codex-call`）

**Step 1: Write the wrapper script**

```bash
#!/bin/bash
set -euo pipefail

# Resolve codex binary
if command -v codex &>/dev/null; then
    CODEX_BIN="codex"
elif [[ -x "/Applications/Codex.app/Contents/Resources/codex" ]]; then
    CODEX_BIN="/Applications/Codex.app/Contents/Resources/codex"
else
    echo "ERROR: codex not found in PATH or at /Applications/Codex.app/Contents/Resources/codex" >&2
    exit 127
fi

# Timeout (default 600s, override via CODEX_TIMEOUT env var)
TIMEOUT="${CODEX_TIMEOUT:-600}"

# Prompt from argument or stdin
if [[ $# -ge 1 && "$1" != "-" ]]; then
    PROMPT="$1"
else
    PROMPT="$(cat)"
fi

if [[ -z "$PROMPT" ]]; then
    echo "ERROR: no prompt provided" >&2
    echo "Usage: codex-call \"prompt\" or echo \"prompt\" | codex-call -" >&2
    exit 1
fi

# Execute codex with read-only sandbox and timeout
exec timeout "$TIMEOUT" "$CODEX_BIN" exec --sandbox read-only "$PROMPT"
```

**Step 2: Make it executable and test basic invocations**

Run:
```bash
chmod +x codex-call
./codex-call 2>&1 || true
```
Expected: "ERROR: no prompt provided" message (exit 1)

Run:
```bash
./codex-call "echo hello, reply with just OK"
```
Expected: Codex runs and returns a response containing "OK" (confirms codex binary resolution and execution work)

**Step 3: Test timeout behavior**

Run:
```bash
CODEX_TIMEOUT=5 ./codex-call "wait 60 seconds then respond" 2>&1 || echo "exit code: $?"
```
Expected: Timeout after 5 seconds, exit code 124

**Step 4: Commit**

```bash
git add codex-call
git commit -m "feat: add codex-call shell wrapper"
```

---

### Task 2: Create dual-agent slash command template

**Files:**
- Create: `dual-agent.md`（项目内开发，最终安装到 `~/.claude/commands/dual-agent.md`）

**Step 1: Write the template**

The template is a Markdown file that Claude Code loads as instructions when the user invokes `/dual-agent`. It must contain:

1. Role definitions (Claude Code = decision maker + sole coder, Codex = read-only advisor)
2. Three-phase workflow with explicit rules
3. Debate rules (P0/P1 must be addressed, P2 optional)
4. How to call codex-call via Bash tool
5. Artifact file paths (.design/ directory)
6. `$ARGUMENTS` placeholder for user input

```markdown
# Dual-Agent 协作流程

你正在执行一个双 Agent 协作流程。严格按以下规则执行，不要跳过任何阶段。

## 角色

- **你（Claude Code）**：决策者 + 唯一代码编写者。你负责写设计、实现代码、修复问题。
- **Codex**：只读顾问。通过 `~/.claude/bin/codex-call` 调用。Codex 可以读项目文件但不能写。它的输出是建议，你来决定如何采纳。

## 调用 Codex 的方式

使用 Bash 工具调用：

```
Bash("~/.claude/bin/codex-call 'your prompt here'")
```

或者用 stdin 传递长 prompt：

```
Bash("~/.claude/bin/codex-call - <<'PROMPT'\nyour long prompt here\nPROMPT")
```

超时默认 600 秒。如果超时，告知用户并询问是否重试。

## 辩论规则

- Codex 返回的 **P0**（必须修复）和 **P1**（应当修复）问题，你必须逐条处理：
  - 接受并修复，或
  - 给出明确的技术理由说明为什么不改
  - **不能默默跳过**
- **P2**（建议改进）：可酌情忽略
- 每轮处理结果追加记录到对应的 debate 文件

## 流程

### 准备

1. 确认当前在 git 仓库中（运行 `git rev-parse --is-inside-work-tree`）
2. 创建 `.design/` 目录（`mkdir -p .design`）
3. 告知用户："开始三阶段双 Agent 协作流程"

### 阶段一：设计辩论（最多 3 轮）

1. 分析当前项目结构和代码，理解需求上下文
2. 写设计文档到 `.design/design.md`，包含：
   - 目标 / 非目标
   - 方案概述
   - 要修改的文件清单
   - 边界情况
3. 调用 Codex 审查设计：

```
~/.claude/bin/codex-call - <<'PROMPT'
审查 .design/design.md 中的设计文档。

要求：
- 指出设计缺陷、遗漏、潜在问题
- 每个问题标注严重级别：P0（必须修复）、P1（应当修复）、P2（建议改进）
- 给出具体的改进建议
PROMPT
```

4. 处理 Codex 的反馈：
   - 逐条处理 P0/P1（修复或反驳）
   - 更新 `.design/design.md`
   - 将本轮辩论记录追加到 `.design/design-debate.md`
5. 如果有 P0/P1 被修复，再调 Codex 审查（回到步骤 3）
6. 无 P0/P1 → 告知用户"设计通过"，进入阶段二
7. 满 3 轮仍有 P0/P1 → 停止，告知用户未解决的问题，询问是否继续

### 阶段二：实现

1. 读取 `.design/design.md` 中的最终设计
2. 实现所有代码改动
3. 运行项目的构建/测试命令
4. 写改动摘要到 `.design/changeset.md`，包含：
   - 修改/新建的文件清单
   - 风险点
   - 需要人工确认的事项

### 阶段三：代码审查（最多 3 轮）

1. 获取 git diff（`git diff` 或 `git diff HEAD`）
2. 调用 Codex 审查代码：

```
~/.claude/bin/codex-call - <<'PROMPT'
审查当前项目的代码改动。

上下文：
- 设计文档在 .design/design.md
- 改动摘要在 .design/changeset.md

要求：
- 审查代码质量、安全性、性能、正确性
- 每个问题标注 P0/P1/P2
- 如果需要改动，给出具体修改建议
PROMPT
```

3. 处理 Codex 的反馈：
   - 逐条修复 P0/P1
   - 将本轮辩论记录追加到 `.design/implementation-debate.md`
4. 修复后再调 Codex 审查（回到步骤 2）
5. 无 P0/P1 → 告知用户"代码审查通过，流程完成"
6. 满 3 轮仍有 P0/P1 → 停止，告知用户未解决的问题

### 完成

告知用户流程结果，列出 `.design/` 目录下的产物。

## 需求

$ARGUMENTS
```

**Step 2: Review template for completeness**

Read the file back and verify:
- `$ARGUMENTS` is at the end
- All three phases are described
- Codex call syntax uses `~/.claude/bin/codex-call`
- Debate rules are explicit about P0/P1

**Step 3: Commit**

```bash
git add dual-agent.md
git commit -m "feat: add dual-agent slash command template"
```

---

### Task 3: Create install script

**Files:**
- Create: `install.sh`

**Step 1: Write the install script**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install codex-call wrapper
mkdir -p ~/.claude/bin
cp "$SCRIPT_DIR/codex-call" ~/.claude/bin/codex-call
chmod +x ~/.claude/bin/codex-call
echo "Installed: ~/.claude/bin/codex-call"

# Install slash command template
mkdir -p ~/.claude/commands
cp "$SCRIPT_DIR/dual-agent.md" ~/.claude/commands/dual-agent.md
echo "Installed: ~/.claude/commands/dual-agent.md"

echo ""
echo "Done. Use in Claude Code: /dual-agent your requirement here"
```

**Step 2: Run the install script**

Run:
```bash
chmod +x install.sh
./install.sh
```

Expected:
```
Installed: ~/.claude/bin/codex-call
Installed: ~/.claude/commands/dual-agent.md

Done. Use in Claude Code: /dual-agent your requirement here
```

**Step 3: Verify installation**

Run:
```bash
ls -la ~/.claude/bin/codex-call ~/.claude/commands/dual-agent.md
```

Expected: Both files exist and codex-call is executable.

**Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: add install script for slash command and wrapper"
```

---

### Task 4: Update project documentation

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`（项目级，如果存在）

**Step 1: Update README.md**

Replace the current README content to reflect the new architecture:
- New usage: `/dual-agent xxx` inside Claude Code
- Install: `./install.sh`
- How it works: Claude Code self-orchestration
- Keep old `dual-agent` script mention as legacy

**Step 2: Update or create project CLAUDE.md**

Keep under 50 lines per user's global instruction. Record:
- Tech stack: Bash + Markdown slash command
- Directory structure
- Key conventions

**Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: update README and CLAUDE.md for self-orchestration"
```

---

### Task 5: End-to-end test

**Step 1: Verify slash command is recognized**

Open a new Claude Code session in any git repo and type `/dual-agent`. Verify that Claude Code loads the template.

**Step 2: Run a real test**

In a test project (git repo), run:
```
/dual-agent 在 README 末尾添加一行 "Hello from dual-agent"
```

Verify:
- Phase 1: Claude Code writes design, calls Codex for review
- Phase 2: Claude Code makes the change
- Phase 3: Claude Code calls Codex for code review
- `.design/` artifacts are created

**Step 3: Verify Codex is called with read-only sandbox**

Check that Codex calls use `--sandbox read-only` (visible in Bash tool output).
