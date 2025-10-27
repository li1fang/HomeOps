# PR Close Review (PCR) — 合并/关闭后的标准复盘（v1.0）

> **宗旨**：把一次 PR 的“最终事实”固化为结构化证据，并把“下一步行动”明确移交给 Issue 队列，防止偏航、遗忘与无效迭代。  
> **定位**：PCR 是 **PR 合并（Merged）或关闭（Closed）后** 的第一条标准化评论 / 记录；同时生成后续 Issues（若有）。  
> **哲学**：证据优先（Evidence-First）· 单一真相源（SSOT）· 一事一议（Single Responsibility）。

---

## 0) 适用时机

- PR 合并 **或** 关闭后 **10 分钟内**（CI 完整产出可用）。
- 该 PR 的 CI 已完成 Gate1/Gate2（无论红绿）。
- 存在“临时降级 / 偏差接受”（Acceptance Deviation）或“拆分合并”的情形。

---

## 1) PCR 最小交付（必须字段）

在 PR 最后一条评论中粘贴下列区块，并保持原样结构（便于人机解析）：

```markdown
## PR Close Review: #{PR_NUMBER}

**Related Issue:** #{ISSUE_NUMBER}
**Final State:** {Merged|Closed}
**Final CI:** {✅ Green | ❌ Red (accepted deviation)}  
**Run URL:** {https://github.com/<org>/<repo>/actions/runs/<run_id>}
**HEAD SHA:** {<commit_sha>}

### Evidence Matrix
| Original Acceptance (from Issue/Spec) | Final Evidence (CI/Artifacts)                        | Status | Notes / Deviation |
|:--------------------------------------|:-----------------------------------------------------|:------:|:------------------|
| Loki running (systemd active/enabled) | `service_facts`: loki=active, enabled=true           |   ✅   |                   |
| /ready returns 200                    | `GET /ready` → 200, body captured to artifacts       |   ✅   |                   |
| Per-host log assertion                | `query_range` OK, result non-empty, host-map empty   |   ⚠️   | **Deviation: simplified to non-empty** |
| make itest exit code 0                | Gate2 job exited 0                                   |   ✅   | (based on simplified assertion) |

### Key Learnings
- {e.g., Loki 日志缺少 host/instance 标签；当前阶段以“结果非空”替代按主机断言。}
- {e.g., until/retries 对就绪探针有效；range 查询需 start/end（ns）。}

### Follow-ups
- [ ] Create Issue **V3.8 – Restore host-level assertions** (Priority: High)
- [ ] (Optional) Spec update: clarify tiered assertions (L1: non-empty, L2: host coverage)
- [ ] (Optional) Tooling: artifacts summarizer agent

### Decision
**PCR_DECISION:** {ACCEPT | ACCEPT_WITH_DEVIATION | REJECT_REWORK | SPLIT_AND_MERGE}

<!-- pcr-meta:v1
pr: {PR_NUMBER}
issue: {ISSUE_NUMBER}
ci: {run_id}
sha: {commit_sha}
decision: {ACCEPT|ACCEPT_WITH_DEVIATION|REJECT_REWORK|SPLIT_AND_MERGE}
created_at: {ISO8601}
next_actions: [V3.8, SPEC_TIERING]
-->
```

> **说明**：
> - **Evidence Matrix**：左列来自原 Issue/Spec 的验收；右列引自“真实 CI 证据”；中间以 ✅/⚠️/❌ 标注达成度。  
> - **Decision**：
>   - `ACCEPT`：按原验收完全达成；无偏差；可关闭 Issue。  
>   - `ACCEPT_WITH_DEVIATION`：接受经 PCR 记录的**临时偏差**，并转化为后续 Issue；PR 合并合理。  
>   - `REJECT_REWORK`：未达成关键验收；继续以该 PR 进行“PR 小更新（Micro-Update）”。  
>   - `SPLIT_AND_MERGE`：拆分已完成部分（合并），余项转化为新 Issue/PR。

---

## 2) 偏差管理（Acceptance Deviation Protocol, ADP）

当 PR 为达成“核心目标”而**临时降低/调整**验收时，必须：

1. 在 **PCR** 的 Evidence Matrix 中**明确标注偏差**所在行（⚠️）与理由；
2. 立即创建后续 Issue（如 **V3.8**），标题以 `Restore ...`/`Harden ...` 开头；
3. 在该 Issue 中：重申原始验收；指向 PCR 证据；限定范围与 SLA；
4. 给 Issue 打上标签：`acceptance:deviated`, `priority:{High|Critical}`, `area:{gate2|observability}`。

> **可选**：若偏差涉及**规范层**（如 `docs/verification-spec.md`），采用**分层验收**（Tiered Acceptance）避免“回滚规范”：  
> - **L1（MVP）**：查询结果非空（最低保障“有流”）；  
> - **L2（Host coverage）**：每台主机≥1条；  
> - **L3（Freshness）**：最新条目 ≤10min。  
> `verify_observability.yml` 可按层级断言并打印当前达到的层级。

---

## 3) 何时“PR 小更新”，何时“开新 PR/Issue”？（决策树）

- **继续 PR 小更新**（Micro-Update）：
  - 目标未变，仅需**微调**（重试、until、变量填充、日志打印、断言细化）；
  - 预计 ≤ 3 次增量能达成目标（或 ≤ 48h）。
- **SPLIT_AND_MERGE（拆分合并）**：
  - 已完成的子目标可独立带来价值；剩余项为**新问题**或**跨层改动**；
  - 当前 PR 再迭代会放大风险/停机时间。  
- **REJECT_REWORK**：
  - 关键验收缺失且无法就地缓解；需要回滚/重构。

> **停机判据**（任一满足则不再追加小更新）：  
> - Micro-Update 次数 ≥ **5**；或累计耗时 > **72h**；  
> - 每次 CI 失败点变化无规律、难以收敛；  
> - 出现“规范与实现”分离（Spec 与 Playbook 长期不一致）。

---

## 4) 防偏航：Milestone/白皮书对齐检查（2×2）

在 PCR 中加一行“对齐度评价”，确保每一步不偏离北极星：

- **对齐度**：High / Medium / Low / Off-track  
- **影响**：Unblocks critical path / Adds resilience / Cosmetic  
- **说明**：此 PR 对里程碑 {M27/M28/...} 的具体推进点。

> 若评为 **Low/Off-track**：必须在 `Follow-ups` 开出“回到主线”的 Issue，并标注 `roadmap:realign`。

---

## 5) 与“小更新（Micro-Update）SOP”的衔接

- PCR 引用的“上一轮 CI 证据”与“偏差记录”，为后续“小更新”提供**锚点**；
- 小更新的指令**仅描述问题与验收**（不写方案），继续沿用 G→R 两阶段纪律；
- 若 PCR 决策为 `ACCEPT_WITH_DEVIATION`，小更新的起点应转移至新 Issue（例如 **V3.8**）。

---

## 6) 附：示例（基于 V3.7 → V3.8 的真实结构）

```markdown
## PR Close Review: #104

**Related Issue:** #104
**Final State:** Merged
**Final CI:** ✅ Green
**Run URL:** https://github.com/<org>/<repo>/actions/runs/<run_id>
**HEAD SHA:** 0009abcd...

### Evidence Matrix
| Original Acceptance (from Issue/Spec) | Final Evidence (CI/Artifacts)                         | Status | Notes / Deviation |
|:--------------------------------------|:------------------------------------------------------|:------:|:------------------|
| Loki running                          | service_facts: loki active/enabled                    |   ✅   |                  |
| /ready returns 200                    | /ready → 200, artifacts/itest/ctrl..._ready.json      |   ✅   |                  |
| Per-host log assertion                | query_range OK, result non-empty; host-map = {}       |   ⚠️   | **Deviation: Scope reduced to non-empty** |
| make itest exit 0                     | Gate2 exit code 0                                     |   ✅   | (based on simplified check) |

### Key Learnings
- 实际日志流缺少 `host/instance` 标签；按主机断言暂不可行。

### Follow-ups
- [ ] Create Issue **V3.8 – Restore host-level assertions via Alloy labels** (High)

### Decision
**PCR_DECISION:** ACCEPT_WITH_DEVIATION

<!-- pcr-meta:v1
pr: 104
issue: 104
ci: 1234567890
sha: 0009abcd
decision: ACCEPT_WITH_DEVIATION
created_at: 2025-10-27T00:00:00Z
next_actions: [V3.8]
-->
```

---

## 7) 可复制的触发词（PCR 与后续行动）

**触发 PCR（合并/关闭后立即发起）**
```
Repository: HomeOps
Task: Draft PR Close Review for #{PR}

Inputs:
- Final CI run URL: {url}
- Issue: #{issue}
- Spec: docs/verification-spec.md

Deliverable:
- A PCR comment block (use template), with Evidence Matrix filled from the CI logs + artifacts.
- A short list of Follow-ups (Issues to create), each with title + priority.
```

**从 PCR 创建后续 Issue（例如 V3.8）**
```
Repository: HomeOps
Task: Create Issue — V3.8 Restore host-level log assertions

Scope:
- As recorded in PCR of PR #{PR}, host-level assertions were simplified.
- Bring back Tier L2 (per-host coverage) without degrading L1.

Acceptance:
- Gate2: verify_observability.yml asserts L1+L2.
- Evidence includes host-tag coverage per required host in artifacts/itest.
Priority: High
Labels: acceptance:deviated, area:gate2, priority:high
```

---

**版本**：v1.0（建议与 `AGENTS.md`、`docs/pr-micro-update.md` 同步维护）
