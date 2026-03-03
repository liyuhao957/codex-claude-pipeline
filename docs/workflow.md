# Codex x Claude Code 双 Agent 协作流程

全自动、无人值守的设计-实现-审查 pipeline。

---

## 流程图

```
                      ┌─────────────────────────────────┐
                      │     阶段一：设计辩论 (≤3 轮)      │
                      ├─────────────────────────────────┤
                      │                                 │
  需求描述 ──────────▶│  Codex 产出/更新 design.md       │
                      │       ↓                         │
                      │  Claude Code 审查设计            │
                      │       ↓                         │
                      │  VERDICT: PASS? ──yes──▶ 退出   │
                      │       │no                       │
                      │       ↓                         │
                      │  Codex 按问题清单修订             │
                      │       ↓                         │
                      │  (回到 Claude Code 审查)         │
                      │                                 │
                      └───────────────┬─────────────────┘
                                      │ 设计通过
                                      ▼
                      ┌─────────────────────────────────┐
                      │     阶段二：Claude Code 实现      │
                      ├─────────────────────────────────┤
                      │  读取 design.md 最终版            │
                      │  实现代码 + 构建/测试              │
                      │  输出 changeset.md               │
                      └───────────────┬─────────────────┘
                                      │
                                      ▼
                      ┌─────────────────────────────────┐
                      │     阶段三：实现辩论 (≤3 轮)      │
                      ├─────────────────────────────────┤
                      │                                 │
                      │  Codex 读仓库 + git diff 审查    │
                      │       ↓                         │
                      │  VERDICT: PASS? ──yes──▶ 完成   │
                      │       │no                       │
                      │       ↓                         │
                      │  Claude Code 按问题修复代码       │
                      │       ↓                         │
                      │  (回到 Codex 审查)               │
                      │                                 │
                      └─────────────────────────────────┘
```

---

## 轮次规则

| 项目       | 设计辩论（阶段一）         | 实现辩论（阶段三）         |
|-----------|--------------------------|--------------------------|
| 最大轮数   | 3                        | 3                        |
| 通过标准   | 无 P0/P1 问题            | 无 P0/P1 问题            |
| 终止条件   | PASS 或满 3 轮           | PASS 或满 3 轮           |
| 审查方     | Claude Code              | Codex                    |
| 修订方     | Codex                    | Claude Code              |

### 问题分级

- **P0**: 设计缺陷/逻辑错误，必须修复才能继续
- **P1**: 重要问题（安全、性能、可维护性），应当修复
- **P2**: 建议改进，不阻塞流程

### VERDICT 格式

每轮审查输出末尾必须带结构化标记，供脚本解析：

```
VERDICT: PASS
```

```
VERDICT: REVISE
- [P0] 缺少错误处理: ...
- [P1] 接口命名不一致: ...
- [P2] 建议添加注释: ...
```

---

## 产物目录

```
.design/
├── design.md                # 设计文档（Codex 维护，逐轮更新）
├── design-debate.md         # 设计阶段辩论记录（每轮追加）
├── implementation-debate.md # 实现阶段辩论记录（每轮追加）
└── changeset.md             # 实现改动摘要（Claude Code 产出）
```

---

## 关键约束

1. **工作目录**: 所有命令在项目根目录执行
2. **Codex 审查方式**: 直接读仓库 + git diff，不需要手工喂 diff
3. **权限控制**:
   - 纯审查: `read-only` / 最小权限
   - 改代码: `workspace-write` / `--full-auto`
   - 非必要不使用 `danger-full-access`
4. **轮次记录**: 每轮追加到对应 debate 文件
5. **上下文传递**: 每次调用 agent 时包含设计文档 + 历史辩论记录
6. **超轮处理**: 3 轮仍有 P0/P1 → 停止并输出未解决问题清单

---

## CLI 参考

```bash
# Claude Code 非交互
claude -p "prompt" --dangerously-skip-permissions

# Codex 非交互（通用）
codex exec "prompt"                        # 基本调用
codex exec --full-auto "prompt"            # 带写入权限 + 自动审批
codex exec --sandbox read-only "prompt"    # 只读

# Codex 代码审查（专用子命令，阶段三使用）
codex review --uncommitted                 # 审查未提交改动
codex review --base main                   # 审查相对 main 的改动
codex review --commit <sha>                # 审查某次提交
```

> **Codex 路径**: PATH 优先，fallback 到 `/Applications/Codex.app/Contents/Resources/codex`
> **非 git 项目**: 脚本检测后报错退出，提示手动执行 `git init && git add . && git commit -m 'baseline'`
