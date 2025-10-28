# docs/issue-template.md — Issue 合同模板（v2.1）
> **目的**：用“合同化 Issue”统一约束 **问题/目标→验收→证据**，可被人/CI/AI 直接消费。  
> **口径**：以 [`AGENTS.md`](../AGENTS.md) 为流程唯一指南；以 [`docs/verification-spec.md`](./verification-spec.md) 为 Gate2 唯一判分标准。  
> **注记**：本版在 v2.0 基础上新增 **Secrets 显式字段** 与 **Spec 对应关系（MAY）**。

---

## 🔧 长版固定模板（复制后替换花括号内容）

```markdown
<!-- codex-meta v1
task_id: {短ID-如 GATE2-VERIFY}
domain: homeops
iteration: {整数}
network_mode: {off|setup-only}
secrets_required: {yes|no}
-->

Title: {一句话清晰表述：只说明问题与验收，不指定实现}

Summary
{2–3 句：当前现象 / 为什么要做 / 做完得到的能力或风险下降。}

Context
- 仓库：HomeOps
- 入口：金路径 `make setup → make lint → make test → make itest → (make deploy)`
- 判分：**Gate2 仅以 `docs/verification-spec.md` 为权威**；流程口径以 `AGENTS.md` 为准
- Runner/权限：{例如 self-hosted, ansible, hardware}
- Secrets（必须与 codex-meta 一致）：**{Yes|No}**

Observed Problems
- {2–5 条可复现现象；引用日志行或 CI 链接；不用情绪词}

Requirements（What to achieve）
- {只写目标，不给方案；例如：“Gate1 稳定通过；lint 仅扫描仓库源路径；……”}

Deliverables
- {本次需要新增/修改的**仓内文件路径**清单（允许整文件替换）}
- PR 描述**包含** “Testing Done” 四行 与 Actions/Artifacts 链接

Constraints
- 不依赖管理员权限修改 runner **全局**环境
- 如需联网，仅限 CI 的 setup 窗口（说明用途与范围）
- 不改变 `docs/verification-spec.md` 的含义（如需改，另开文档作业单）

Acceptance Criteria（机器可判）
1) Gate1（ubuntu-latest）`make setup` / `make lint` / `make test` **exit 0**；
2) 生成 `artifacts/test/tools_versions.txt`，包含 ansible / ansible-lint / yamllint 版本；
3) lint 仅覆盖仓库源（`playbooks/`、`roles/`、`inventory/`、`templates/` 等），**无** `.venv/` / `site-packages/` / `.github/workflows/` 报错；
4) （如涉及 Gate2）自托管 Runner 运行 `make itest`（= 部署 + 验收），产出 `artifacts/itest/*`；失败退出非零但**仍**上传工件。

MAY — Spec Mapping（验收↔Spec 对应表，建议在复杂任务填写）
| 验收条目 | 对应 `verification-spec.md` 条款 | 证据文件/信号 |
|---|---|---|
| e.g., Grafana 健康 200 | §C.1 | `artifacts/itest/grafana-health.json` |
| e.g., Loki 查询非空 | §D.2 | `artifacts/itest/loki-query.json` |

Testing Done（R 阶段回填时必须按此格式提供）
- Run URL: `{Actions run 链接}`
- Commit: `{HEAD SHA}`
- Gate1/Gate2: `{Job 名 + 结论}`
- Artifacts: `{相对路径清单（含关键证据文件名）}`

Priority & SLA
- 优先级：{High / Med / Low}
- SLA：{首版 48–72h；稳定通过 7d}
```

---

## 🧩 迷你模板（可直接替换标题与少量正文）

### A. 文档/规范（docs-only）
```markdown
Title: Align AGENTS.md with verification‑spec (docs‑only)

Summary
将 AGENTS.md 的 “make itest = 部署 + 验收” 口径与 `docs/verification-spec.md` 对齐。

Context
- 仓库：HomeOps
- 入口：docs-only（变更仅限 `.md` / `docs/**`）
- 判分：不触发代码 Gates
- Secrets：No

Requirements
- 在 AGENTS.md 的 itest 小节**显式**声明 Gate2 的复合动作定义，并引用 Spec 为唯一判分标准。

Acceptance
- PR 仅改 `.md` / `docs/**`；CI 走 docs-only 路由。
```

### B. Gate1 稳定（云）
```markdown
Title: Gate1 CI stability on ubuntu‑latest

Observed
- lint 误扫 site‑packages；PEP668 抛 externally‑managed；Makefile 目标不稳定……

Requirements
- 云端 Gate1 稳定完成 `make setup/lint/test`；lint 仅限仓库源；产出工具版本报告。

Acceptance
- Gate1 全绿；`artifacts/test/tools_versions.txt` 存在且格式正确。
```

### C. Gate2 验收（verify_observability.yml）
```markdown
Title: Implement machine‑verifiable itest per verification‑spec

Requirements
- 依 `docs/verification-spec.md` A/B/C/D 实现 `playbooks/tests/verify_observability.yml`；证据落盘：`artifacts/itest/*`。

Acceptance
- `make itest`（部署 + 验收）可判：通过→绿；失败→非零且仍上传工件。
MAY — Spec Mapping：提供条目↔条款对照表。
```

### D. 部署幂等（deploy‑observability）
```markdown
Title: Idempotent deploy‑observability‑stack.yml

Requirements
- controllers: Loki + Grafana 自启；controllers,linux: Alloy 自启；Grafana 预置 Loki 数据源；健康节点二次 `changed=0`。

Acceptance
- 首次成功；二次最小变化；Gate2 仍绿。
```

### E. APT 锁竞争（系统窗口 + 强化 apt）
```markdown
Title: APT maintenance window & hardened apt tasks (replaces #50)

Requirements
- Gate2 期间静默系统更新器；所有 apt 任务加 `lock_timeout` / 非交互；集中 `update_cache`；故障路径可恢复。

Acceptance
- 无锁争用导致的失败；健康路径 `changed=0`；故障路径 `changed=1` 且后续成功；Gate2 绿。
```

---

## ✅ 1 分钟自检清单 & 🚫 反模式

**自检清单**
- [ ] 标题清晰只述“问题/目标”
- [ ] Summary 2–3 句讲清“为什么”
- [ ] Observed 引用可复现证据（日志/链接）
- [ ] Requirements 只写“要达到什么”，不写“怎么做”
- [ ] Acceptance 可机判（状态/端口/HTTP/exit code/文件）
- [ ] **Secrets = Yes/No** 已显式声明，并与 codex-meta 一致
- [ ] （MAY）填写 Spec Mapping 表
- [ ] Testing Done 四行约定保留

**反模式**
- 在 Issue 里给实现步骤/命令
- 多目标揉成一个 Issue
- 验收只写“CI 成功”而无具体信号
- 改动路径/产物路径每单都变
- 依赖修改 runner 全局环境（无审批）

---

## 🧪（可选）GitHub Issue Form 片段

> 如需让 GitHub UI 直接收集结构化字段，可创建：
> `.github/ISSUE_TEMPLATE/issue-contract.yml`

```yaml
name: Issue Contract
description: Contract-first issue for HomeOps
labels: ["type:contract"]
body:
  - type: input
    id: title
    attributes:
      label: Title
      description: 一句话清晰表述（问题与验收，不指定实现）
      placeholder: "Idempotent deploy-observability-stack.yml"
    validations: { required: true }
  - type: textarea
    id: summary
    attributes:
      label: Summary
      description: 2–3 句业务化描述（现象/为什么/带来能力）
    validations: { required: true }
  - type: dropdown
    id: secrets_required
    attributes:
      label: Secrets Required?
      description: 是否需要仓库 Secrets（必须与 codex-meta 一致）
      options: ["no", "yes"]
    validations: { required: true }
  - type: textarea
    id: observed
    attributes:
      label: Observed Problems
      description: 2–5 条可复现现象，建议附 CI 链接/日志行
    validations: { required: true }
  - type: textarea
    id: requirements
    attributes:
      label: Requirements (What to achieve)
      description: 只写目标，不给方案
    validations: { required: true }
  - type: textarea
    id: acceptance
    attributes:
      label: Acceptance Criteria (machine-verifiable)
      description: 写具体信号（HTTP code、systemd running、文件存在等）
    validations: { required: true }
  - type: textarea
    id: spec_mapping
    attributes:
      label: (MAY) Spec Mapping
      description: 验收条目 ↔ verification-spec.md 条款 对照（可选）
  - type: textarea
    id: deliverables
    attributes:
      label: Deliverables
      description: 本次改动的仓内文件路径清单；PR 需包含 Testing Done
  - type: input
    id: priority
    attributes:
      label: Priority
      placeholder: "High / Med / Low"
  - type: input
    id: sla
    attributes:
      label: SLA
      placeholder: "首版 48–72h；稳定通过 7d"
```
