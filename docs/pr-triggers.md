# docs/pr-triggers.md — PR 触发词（v2.1 / 证据优先）
> **宗旨**：以标准话术驱动 AI 执行 **G→R 两阶段**，防止“善意谎言”。  
> **对齐**：`make itest = 部署 + 验收`（Gate2 复合动作）；`make deploy` 为合入后生产上线。  
> **新增**：本版强化 **Micro‑Update 目标精确性** 与 **诊断模式的说明义务**。

---

## 🅶 阶段 G — 生成 PR（禁止填写 Testing Done）

**精简版（默认首选）**
```text
Repository: HomeOps
Task: Implement Issue #{编号}

严格遵守根目录 AGENTS.md 与 docs/verification-spec.md。
现在只做：实现修复并创建 PR。⚠️ 禁止填写 “Testing Done”，保留为 “PENDING-CI”。
金路径：先在沙箱本地跑通 Gate1（make setup → make lint → make test），再提交；
提交后由 Runner 触发 Gate2（make itest = 部署 + 验收）。
```

**详细版（首单/复杂场景）**
```text
Repository: HomeOps
Task: Implement Issue #{编号}

口径：AGENTS.md（流程）、verification-spec（Gate2 判分）。
范围：仅做 Issue 的 Requirements/Acceptance；不扩展、不重构、不引入新依赖。
Secrets：{yes|no}（与 Issue/ codex-meta 一致；敏感字段使用 no_log: true，不得写入工件）。
交付：整文件替换允许；PR 描述含 “PENDING-CI” 的 Testing Done + codex-meta；
执行：先本地/沙箱跑通 Gate1，再 push；由 Runner 触发 Gate2（itest）。
```

---

## 🅁 阶段 R — CI 绿后，仅引用“本次 run”证据回填

```text
Repository: HomeOps
Task: Update PR #{编号}

该 PR 的 CI 已全部绿灯：{Actions run 链接}
仅从本次 run 的日志与 Artifacts 提取事实，回填 PR 的 “Testing Done”：
- Run URL：该次 Actions run 的 URL（含 run_id/attempt）
- Commit：HEAD SHA
- Gate1 / Gate2：Job 名称与结论
- Artifacts：artifacts/test/* 与 artifacts/itest/* 的文件清单
- 证据：关键信号原文（HTTP 200、active (running)、查询命中等）+ 文件名/路径

⚠️ 禁止推测或虚构；只能引用本次 CI 的事实。
```

---

## 🪄 PR “小更新”触发词（Micro‑Update / 驳回重审）

> 用于 **同一 PR** 内的增量修正；与 `docs/pr-micro-update.md` 配套。

### 1) 标准模式（修复一个明确缺口）— *新增：绑定 PCR Gap*
```text
Repository: HomeOps
Task: PR Micro‑Update for #{PR编号}

上轮 CI 证据：{粘贴失败片段或工件路径}
PCR 对应缺口：{从 PR Close Review 的 Gap 表选取/引用 Spec 条款，如 §D.2 Loki Range Query}
本轮目标：提交“最小补丁”修复以上单一缺口。禁止扩展范围。

交付：仅修改 {受影响的文件清单}；保持其它行为不变。
验收：
- Gate1：make setup / make lint / make test = 0；
- Gate2：针对该缺口的验证转为 OK（列出对应证据信号）。
```

### 2) 诊断优先模式（先查明原因，再修）— *新增：说明义务*
```text
Repository: HomeOps
Task: PR Micro‑Update (Diagnosis‑First) for #{PR编号}

现象：{粘贴反常/矛盾证据}
诊断目标：请先在 PR 的 **评论或 Commit Message** 中，明确你的诊断结论（是什么 / 为什么 / 证据）。
修复目标：在同一 PR 推送“最小补丁”，只解决经诊断确认的根因。

验收：
- CI 允许红灯，但必须：
  1) 产出定位所需的新工件（列文件名）；
  2) PR 评论/Commit Message 内含**结构化诊断说明**（≤10 行要点，引用证据链接/行号）；
- 若修复已到位，则 Gate2 该项转为 OK。
```

### 3) 临时降级 + 回补 Issue（务实推进）
```text
Repository: HomeOps
Task: PR Micro‑Update (Temporary Downgrade) for #{PR编号}

依据证据：{粘贴导致“当前验收不可达”的客观限制，例如缺少日志标签}
调整：将 {原严格断言} 暂时降低为 {可达的可机判断言}；
同时创建后续 Issue（如 V3.8）用于“恢复严格标准”。

验收：
- 本 PR：以新断言为准，Gate2 全绿；
- 新 Issue：记录恢复路径与优先级（High/Med/Low）。
```

---

## 🧾 R 阶段固定 “Testing Done 四行”规范

> R 阶段仅允许**从同一次 CI run** 复制事实回填。

```
Run URL: <https://github.com/<org>/<repo>/actions/runs/<run_id>/attempts/<n>>
Commit: <HEAD-SHA>
Gate1/Gate2: <job 名称> — <结论>
Artifacts: 
  - artifacts/test/tools_versions.txt
  - artifacts/itest/grafana-health.json
  - artifacts/itest/loki-query.json
  - ...
```

**反模式（拒收）：** 没有 Run URL/Artifacts 的口述总结；与实际 run 不一致；跨 run 拼接证据。

---

## 🤝 与其它 SOP 的关系
- 与 **`docs/pr-micro-update.md`**：上面的 Micro‑Update 触发词就是其“执行话术”。
- 与 **`docs/pr-close-review.md`**：Micro‑Update 的“目标/缺口”应来源于 PCR 的 **Gap 表**；R 阶段回填引用 PCR。

---

## 📌 提示（常见易错）
- Secrets：在 G 阶段即明确 `{yes|no}`，并与 Issue/ codex-meta 保持一致；任何使用都需 `no_log: true`。
- itest：这是 **部署 + 验收** 的复合动作；不要把“先部署、后验收”拆成两个不同 PR。

