# PR Micro‑Update Handbook（v2.1）
> **目的**：在**同一个 PR** 内，以“证据优先 & 两阶段（G→R）”模式，连续下达**小更新（Micro‑Update）**指令，直至满足原始验收标准（或触发停机分流）。  
> **适用对象**：AI 工程师（Codex）与 Reviewer；适用于 HomeOps 全仓，特别是 Gate2（`make itest`）驱动的验收闭环。  
> **权威口径**：流程以 `AGENTS.md` 为准；Gate2 判分以 `docs/verification-spec.md` 为唯一来源。

---

## 0. 核心哲学
- **证据优先（Evidence‑First）**：一切判断以 **CI Run + 工件（Artifacts）** 为证，不依赖口头“猜测”。
- **两阶段纪律（G → R）**：
  - **G（Generation）**：只提交补丁，不填写 `Testing Done`；**禁止写 HOW**（实现细节）。
  - **R（Reporting）**：CI 完成后，**仅从本次 Run** 回填 `Testing Done`（Run URL/Job 结论/工件清单/原文摘录）。
- **同 PR 连续小更新**：以 **Part n** 方式逐步迭代，直到满足原 Acceptance，或触发停机分流。

```mermaid
flowchart LR
  A[PR 打开/更新] --> B{Gate1 云端
setup/lint/test}
  B -->|绿| C{Gate2 自托管
itest(部署+验证)}
  B -->|红| M1[Micro-Update: 修复 Gate1]
  C -->|绿| D[满足验收 → 合并]
  C -->|红| M2[Micro-Update: 诊断/修复 Gate2]
  M1 --> B
  M2 --> C
  M2 -->|超 3 次无证据增量| S[停机/分流：新 Issue 或调整验收]
```

---

## 1. 小更新的固定骨架（SOP 模板）
> 复制以下模板，替换花括号占位符；**不写方案**、**不改验收**、**只在范围内动作**。

```markdown
Title: [修正 {PR 名/迭代号}] 验收失败：{一句话证据结论}

致：工程师（Codex）

1) 上一轮 CI 的“客观证据”
- Run: {Actions URL}（run_id={id}）
- Commit: {short_sha}
- Jobs:
  - Gate1: {job_name} = {结论}
  - Gate2: {job_name} = {结论}
- Artifacts（路径 + 尺寸/计数）:
  - {相对路径}（{大小/行数/条数}）
- 关键原文（≤3 行，来自本次 Run 日志/响应体）
> {原文1}
> {原文2}

2) 该 PR 未结束的原因（对照验收）
- 本 PR 的 Acceptance（摘要）：{引用原验收关键条款或 `docs/verification-spec.md` 具体条目}
- 对照结果：{证据 X} 未满足 {验收 Y} → **未达到**。

3) 当前问题的准确定义
- 标准模式：{基于证据给出“现在的失败点”的定义（不写解决路径）}
- 诊断优先：{当现象反常/矛盾时，要求先产出诊断证据并给出诊断目标}

4) 你的“小更新”任务（只在白名单范围内）
- **范围白名单**：{允许修改的文件/任务名/段落}
- **动作意图**（不写 HOW）：
  - 标准：{例如“让 readiness 重试直至 200，并落盘 JSON”}
  - 诊断：{例如“插入 debug 任务打印 loki_log_map；新增 itest_debug.json”}
- **改动预算**：最多 {N} 个任务；**禁止修改**：{黑名单项}
- **Testing Done**：保持 **PENDING‑CI**；待 R 阶段回填

5) 不变的验收标准（机器可判）
- Gate1：`make setup` / `make lint` / `make test` 均 **exit 0**
- Gate2：`make itest` 必须执行，且：
  - {可测信号1：HTTP 200 / systemd active / result[].length>0 …}
  - {可测信号2}
- 新增/变更工件：{文件路径}（必须存在；大小>0；如适用包含关键字段）
- 诊断型小更新（如适用）：允许红灯，但**新增证据**必须出现（见上）
```

> **纪律重申**：
> - 禁止写“怎么实现”（HOW）；
> - 禁止要求修改 runner 全局环境；
> - PR 描述中的 `Testing Done` 在 **R 阶段**以 CI 事实回填。

---

## 2. 写作清单（提交前 1 分钟）
- [ ] 标题合规，**一句话证据结论**明确（例如 “/ready 503” / “query_range 400” / “变量未定义”）  
- [ ] **Run URL / run_id / SHA / Job 结论 / 工件（含大小或条数）**五件套齐全  
- [ ] 关键原文 **≤3 行**，直接粘贴自本次 Run  
- [ ] 范围白名单与改动预算写清，黑名单明确  
- [ ] 验收信号**可机判**（HTTP/status/result len/文件存在与大小）  
- [ ] 明确“**禁写 HOW** / **Testing Done = PENDING‑CI**”

### 10 秒复审
- [ ] 事实（证据）与判断（对照验收）分段清晰  
- [ ] 是否指向 `docs/verification-spec.md` 或 PR 原验收？  
- [ ] 是否只聚焦**一个失败点 → 一个小更新目标**？

---

## 3. 标准化小更新范式库（速查棋谱）
> **意图导向，不写 HOW**；每条配**可机判信号**与**工件要求**。

### 3.1 就绪探针波动（503 `/ready`）
- **意图**：为 readiness 增加 `until` 重试/延迟，最终 200  
- **验收**：`Request Loki readiness status` 最终 OK；`ctrl-linux-01_loki_ready_response.json` 存在且 `status=200`  
- **范围**：`playbooks/tests/verify_observability.yml` 对应 block

### 3.2 查询类型错误（400 `query` vs `query_range`）
- **意图**：使用 `/query_range` 并添加最近 5–10 分钟时间窗  
- **验收**：`Request Loki log query results` 返回 200；`loki_query.json.data.result | length > 0`

### 3.3 变量未定义（Undefined var）
- **意图**：在查询前**计算**必须的时间戳变量，保证**始终定义**  
- **验收**：`Compute window` 任务 OK；后续查询 200

### 3.4 结果映射为空（标签缺失）
- **意图**：改为**非空结果断言**（不依赖 host 标签）  
- **验收**：`result | length > 0`；保存 `loki_query.json`

### 3.5 诊断注入（Debug 工具化）
- **意图**：断言前输出关键变量；新增 `itest_debug.json`  
- **验收**：日志出现 debug 输出；文件存在且大小 > 0（例如 >200B）

> 以上 5 条已覆盖 V3.5 → V3.7 的全部修复路径，可直接复用。

---

## 4. 停机 / 分流判据（避免无效内卷）
出现任一条，暂停小更新 → 转新 Issue / 调整验收口径：
- 同一失败点 **连续 3 次** 小更新仍**无证据增量**（日志/工件无新增）  
- 拟议改动**超出范围**（例如需重构角色/部署）  
- 目标**互斥**（两个小更新的验收相互打架）  
- Gate2 必须执行**破坏性动作**影响生产（需先设计影子环境或回滚策略）

---

## 5. 两段触发词（G / R）

**G 阶段（实现小更新，禁止填 `Testing Done`）**
```text
Repository: HomeOps
Task: Update PR #<ID> – Part <n> (Micro‑Update)

严格遵守 AGENTS.md 与 docs/verification-spec.md。
本次仅在范围白名单内做“小更新”，不写实现方案。
Testing Done = PENDING‑CI；等待 CI 结束后进入 R 阶段。
```

**R 阶段（CI 绿后，引用证据回填）**
```text
Repository: HomeOps
Task: Fill Testing Done for PR #<ID>

CI 全绿链接：<run URL>
请仅从本次 run/Artifacts 提取事实，回填：Run URL / SHA / Gate1&Gate2 结论 / 工件列表（含大小或条数） / 关键原文（≤3 行）。
```

---

## 6. 元数据（可选，便于审计/自动化）
在 PR 描述末尾附加可机读区块：
```md
<!-- pr-update-meta v1
task_id: <如 VERIFY-FIX-104-PART3>
domain: homeops
iteration: <整数，从 1 递增>
phase: G | R
run_id: <Actions run_id 或留空>
-->
```

---

## 7. 反模式（坚决避免）
- 写“怎么实现”（HOW）、贴命令/脚本  
- 更改 Gate2 判分口径（除非另开规范 PR）  
- 扩大改动面：引入新的角色/变量/服务（超出范围）  
- 不引用本次 Run 的**真实证据**（URL、原文、工件大小）  
- 在 G 阶段擅自填写 `Testing Done`

---

## 8. 附：最小示例（诊断型红灯验收）
> 用于“变量未定义” → 注入 debug 的场景。

```markdown
Title: [修正 V3.7 Part 4] 验收失败：断言前 loki_log_map 未定义

致：工程师（Codex）

1) 上一轮 CI 的“客观证据”
- Run: https://github.com/<org>/<repo>/actions/runs/<run_id>（run_id=123456789）
- Commit: a1b2c3d
- Jobs: Gate1=success，Gate2=failed（itest）
- Artifacts: artifacts/itest/loki_query.json（12.4KB）
- 关键原文（≤3 行）
> 'loki_log_map' is undefined
> TASK [Assert Loki has logs for required hosts]

2) 该 PR 未结束的原因（对照验收）
- Acceptance 摘要：Gate2 需完成范围查询并断言数据有效
- 对照：虽已 200 且有结果，但断言阶段变量未定义 → 未达到

3) 当前问题的准确定义
- 断言前的聚合变量 loki_log_map 未被创建或被覆盖，需先产出现场证据定位

4) 你的“小更新”任务（只在白名单内）
- 范围白名单：playbooks/tests/verify_observability.yml（断言前一行）
- 动作意图（不写 HOW）：插入 debug 任务打印 loki_log_map；新增 itest_debug.json
- 改动预算：最多 1 个任务；禁止改动查询/部署
- Testing Done：PENDING‑CI

5) 不变的验收标准（机器可判）
- Gate1 全绿；Gate2 执行
- 日志中出现 debug 输出；`artifacts/itest/itest_debug.json` 存在且大小>0
```

---

**End of file.**
