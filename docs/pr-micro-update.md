# PR 微更新（Micro‑Update）SOP · v3.0
> **目的**：将“PR 内迭代修正”固化为**证据优先**、**一次过**、**机器可判**的流程，并与 `Analyzer`（见 `docs/analyzer-sop.md`）无缝协作。  
> **适用对象**：Planner（规划者）、Analyzer（分析者）、Codex（实现者/AI 代理）、Maintainer（人类维护者）。

---

## 0. TL;DR（给着急的人）
- **何时用**：PR 仍未满足其 Acceptance（无论 CI 绿/红），需要在**同一 PR** 内继续修正时。
- **两种模式**：
  - **Standard Fix**：证据已充分，直接指向一次性补丁与“机器可判”验收。
  - **Diagnostic‑First**：证据不足，**先采集证据**（如打印/落盘/收集日志），再进入 Standard Fix。
- **与 Analyzer 协作**：
  1) 先触发 **Step 1（轻信息）**，获取失败锚点与客观事实；
  2) 若仍不足，再触发 **Step 2（智能问答）**，**只问一轮（stop_after: 1）**；
  3) 若仍不足 → 直接出一份 **Diagnostic‑First** 微更新去“加仪表/落证据”。
- **硬约束**：只写“问题与验收”，**不写实现**；所有断言**可机判**；所有证据**来自 CI/Artifacts**。

---

## 1. 角色与术语
- **Planner（规划者）**：依据 Issue/Spec/CI 产出**微更新指令**（本 SOP 的使用者）。
- **Analyzer（分析者）**：**无状态**地解析 CI 日志与工件，输出**结构化事实**（见 `analyzer-sop.md`）。
- **Codex（实现者/AI）**：按微更新指令在**同一 PR** 提交补丁，不得“自述测试”。
- **Argus（守证者）**：可选机器人，核对“PR 描述 ↔ 运行证据”的一致性。

---

## 2. 触发条件（When）
- PR **未**满足其 Acceptance：
  - 红灯：失败位置或原因已明确/不明确；
  - 绿灯但**带偏差**：PCR（PR Close Review）记录“接受偏差”，需继续补回（如 V3.7 的 L2 Host Coverage）。
- 仅适用于**继续在同一 PR** 内推进；若范围变更或目标切换，请**新开 Issue/PR**。

---

## 3. 与 Analyzer 的协作契约
> Full spec 见 `docs/analyzer-sop.md`。此处给 Planner 的实操要点。

### 3.1 调用顺序
1) **Step 1（轻信息）**：
   - 提供：最小背景（Issue/PR 号、Acceptance 摘要）、最新 `run_url`、**精挑**工件列表；
   - 期望：`Anchor`（失败锚点）、`Facts`（客观事实）、`Insight`（一句话洞察）。  
   - 结束语由 Analyzer 固定输出：**“若足够请继续；不足请提问。”**
2) **Step 2（智能问答）**（可选、**只一轮**）：
   - 提供：**具体问题列表**（表格式、窄口径），设置 `stop_after: 1`；
   - 期望：逐问逐答 + **证据引用** + 置信度。

> **一次过**：若 Step 2 仍不足以直接出 Standard Fix，则**立即**切换到 Diagnostic‑First 微更新，**不要**陷入聊天循环。

### 3.2 轻量约束（建议而非强制）
- **工件选择**：优先 `artifacts/itest/*`、`artifacts/deploy/*` 的**小文件**（JSON 片段优先）；
- **体量预算**（建议）：
  - Light 输入 ≤ **10KB**；
  - Step 2 问题 ≤ **3 条**；
  - Analyzer 回答 ≤ **5KB**。

### 3.3 PR 中的调用写法（内嵌注释块）
在 PR 评论或描述里内嵌一段 **Analyzer 指令块**，便于机器人/人类统一读取：

```markdown
<!-- ANALYZER:STEP1
repo: li1fang/HomeOps
pr: 106
run_url: https://github.com/li1fang/HomeOps/actions/runs/xxxxxxxx
artifacts:
  - artifacts/itest/ctrl-linux-01_loki_query_response.json
  - artifacts/itest/ctrl-linux-01_service_facts.json
background: "V3.8 恢复 L2 Host Coverage，当前失败于 'Capture latest Loki entry per host'。"
-->
```

```markdown
<!-- ANALYZER:STEP2
questions:
  - id: Q1
    text: "data.result[].stream 是否包含 'host'？若有，唯一值集合是什么？"
  - id: Q2
    text: "data.result 的长度是否 > 0？"
stop_after: 1
-->
```

Analyzer 的回复（含**证据引用**）应被粘贴回 PR 评论，作为微更新的**证据基座**。

---

## 4. 微更新的三种“模式”
> 三选一；均要求“机器可判”。

### 4.1 Standard Fix（标准模式）
**适用**：证据已足，问题边界明确（如类型转换、端点/参数错误等）。  
**目标**：一次性补丁 + 直达 Acceptance 的断言。  
**常见 Allowed/Forbidden**：
- Allowed：与失败点**直接相关**的仓内文件；
- Forbidden：改变 Spec、改变流水线结构、扩大范围。

### 4.2 Diagnostic‑First（诊断优先）
**适用**：证据不足；需先**加仪表/落证据**（例如扩展 `rescue`、保存 `journalctl`、打印片段）。  
**目标**：CI 仍可失败，但**必须**新增可溯的工件/日志，成为下一轮 Standard Fix 的事实来源。

### 4.3 Acceptance Relaxation（临时下调）
**适用**：为确保“纵深推进”，临时以更小粒度验收（例如由“按主机断言”降为“非空断言”）。  
**约束**：必须在 PR 描述与 PCR 中**显式记录偏差**与**回补计划**（后续 Issue 编号）。

---

## 5. 微更新的统一骨架（模板）
> 复制以下模板，替换花括号；**绝不**写“怎么做”。

```markdown
Title: [修正 {Version/Part}] 验收失败：{一句话证据标签}
致： 工程师（Codex）

1) 上一次 CI 证据锚点（Anchors）
- Gate：{Gate1/Gate2} → {✅/❌}（link: {run_url#job}）
- 失败点：`{TASK / 文件}`
- 摘录：
  ```
  {关键日志片段或 JSON 片段（≤10 行）}
  ```

2) Gap → Acceptance Map（逐条对照）
| 验收条款（Spec/PR Acceptance） | 本次 CI 的证据 | 结论 | 缺口/下一步 |
| --- | --- | --- | --- |
| {条款A} | {证据} | {✅/❌} | {说明} |
| {条款B} | {证据} | {✅/❌} | {说明} |

3) 我们现在的问题（Problem Statement）
- {基于 Analyzer/工件得到的**客观事实**，不下结论到“实现方案”。}

4) 你的“小更新”任务（Action, no How）
- **Mode**: {standard | diagnostic | relaxation}
- **Allowed Changes**: {最小变更范围（仓内路径列表）}
- **Forbidden Changes**: {禁止改动项}
- **目标**：{一次性目标，如“修复类型转换后通过 L2 Host Coverage”}
- **交付**：在**同一 PR** 提交补丁；PR 描述保持 `PENDING-CI`（G 阶段），待 CI 成功后再回填。

5) 不变的验收标准（Machine‑verifiable）
- Gate1：`make setup / make lint / make test` = 0；
- Gate2：`make itest` 产生 `artifacts/itest/*`；
- 关键断言：{列举任务名 + 可测信号 + 文件名}；
- 失败允许（仅 diagnostic）：CI 可失败，但**必须**新增 {artifact 路径}。

附：Analyzer 协同（可选）
<!-- 如需，请粘贴 ANALYZER:STEP1 / STEP2 指令块（见 §3.3） -->
```

---

## 6. 写作清单（Planner）
- [ ] **只写问题+验收**，绝不写实现；
- [ ] **证据锚点**：run_url + 工件片段 + 失败任务名；
- [ ] **与 Spec 对齐**：逐条映射到 `docs/verification-spec.md`；
- [ ] **一次过**：若 Step 2 后仍不清晰 → 直接 Diagnostic‑First；
- [ ] **产物路径稳定**：`artifacts/test/*`、`artifacts/itest/*`；
- [ ] **大小控制**：粘贴片段 ≤10 行，链接代替长文。

---

## 7. 常用片段（可直接拷贝）

### 7.1 Standard Fix（示例：Loki 时间戳类型错误）
```markdown
Title: [修正 V3.8 Part 5] 验收失败：日志时间戳计算 TypeError（int vs str）
…（按上节模板填充）…
4) 你的“小更新”任务
- Mode: standard
- Allowed Changes: playbooks/tests/verify_observability.yml
- Forbidden Changes: playbooks/deploy-observability-stack.yml, templates/*
- 目标：确保 `newest_entry_epoch/newest_entry_ns` 在参与计算/比较前均**作为整数**处理；
- 交付：同一 PR 推送补丁。

5) 验收
- `TASK [Capture latest Loki entry per host]` **OK**（不再出现 TypeError）；
- `TASK [Assert Loki has logs for required hosts]` **OK**；
- 工件：`artifacts/itest/ctrl-linux-01_loki_host_summary.json` **包含 ctrl-linux-01 与 ws-01-linux**。
```

### 7.2 Diagnostic‑First（示例：Alloy 崩溃待取证）
```markdown
Title: [修正 V3.8 Part 2] 诊断失败：未收集 alloy.service 的崩溃日志
…
4) 你的“小更新”任务
- Mode: diagnostic
- Allowed Changes: playbooks/tests/tasks/verify_required_service.yaml
- Forbidden Changes: playbooks/deploy-observability-stack.yml, templates/*
- 目标：通用化 rescue：对**任意**失败的 `required_service.unit` 收集 `journalctl` 并落盘：
  `artifacts/itest/{{ inventory_hostname }}_{{ required_service.unit }}_journal.log`
- 交付：同一 PR 推送补丁。

5) 验收
- CI 仍可红，但**必须**出现上述新工件文件；后续据此切换到 Standard Fix。
```

### 7.3 Acceptance Relaxation（示例：暂降到“非空断言”）
```markdown
Title: [修正 V3.7 Part 5] 验收下调：Loki 仅验证“返回非空”
…
4) 你的“小更新”任务
- Mode: relaxation
- Allowed Changes: playbooks/tests/verify_observability.yml
- 目标：以 `data.result | length > 0` 作为临时断言，解锁首次全绿；
- 交付：同一 PR 推送补丁，并在 PCR 中记录“偏差 & 回补计划（V3.8）”。
```

---

## 8. 与 PCR（PR Close Review）的关系
- **PCR 记录**：若采用 `relaxation`，必须标注 `ACCEPT_WITH_DEVIATION` 与**回补 Issue**；
- **PCR 触发下一步**：依据 Gap 表生成“下一 Issue 草案”，交给 Planner 审核。

---

## 9. 版本与变更
- **v3.0**（本版）：全面接入 `Analyzer`（Step1/Step2）、一次过、三模式；补充模板与示例。
- **v2.x**：早期版本（仅标准/诊断双模式，未对接 Analyzer）。

---

## 10. 附录：微更新中的 codex‑meta（建议）
在 PR 描述或评论附上追踪块，方便机器人聚合：
```md
<!-- codex-meta v1
task_id: MU-{短ID}
domain: homeops
iteration: {整数}
network_mode: off
-->
```
