AGENTS.md — HomeOps AI 协作权威手册 (v2.0)

目的：把对 AI（以及所有自动化代理）在 HomeOps 仓库中的行为规则固化为一个、可审计的契约。

座右铭：事实胜于陈述，制度胜于人治 — 一条金路径，一处真相源。

前言（要点速览）

最高原则：证据优先（Evidence-First）。所有“测试通过”的声明必须来源于 CI/CD 的真实运行与工件（Actions run + Artifacts），不得伪造或推测。

两阶段工作流（G → R）：生成（G）与报告（R）必须分权。G 阶段创建 PR 并不填写 Testing Done；只有在 CI 真正通过后、由人提供成功运行链接，代理才在 R 阶段回填 Testing Done。

唯一真相源：

验收标准（Gate2）：docs/verification-spec.md；

操作流程（四步金路径）：本文件 AGENTS.md（本文件为操作流程的权威）。

Ⅰ. 核心哲学与不可越界条款

必守哲学

证据优先：所有报告必须可追溯至 CI run（URL + 工件 + 提取原文）。

最小权限：不修改 Runner 全局、不得要求管理员权限（除非 Issue 明确授权并获批准）。

单一职责：一个 Issue / PR 只解决一件事。

严禁行为（红线）

伪造或编造测试结果（Testing Done 必须为 CI 真正产出的事实）。

在 G 阶段填写或伪造 Testing Done。

未经许可修改或要求修改 Runner 全局环境或外部云主机。

将 Secrets 明文写入日志或工件（必须 no_log: true）。

在非明确允许下大量使用 shell/command 代替 Ansible 原生模块。

Ⅱ. 金路径：唯一认可的四步（Make Targets Contract）

人 / CI / 代理一律通过下列命令驱动与验证变更。不要引入平行命令或绕道检查。

make setup # Gate0: bootstrap / record tool versions

make lint # Gate1.1: static checks (ansible-lint, yamllint, syntax-check)

make test # Gate1.2: local non-destructive checks (check mode / idempotency probes)

make itest # Gate2: self-hosted deploy & verify combo（先部署，再按 Spec 验证）

make deploy # 条件部署：Gate 2 通过后按需在主干或人工触发（生产释放）

对各命令的职责简述

make setup：创建/确认可复现的虚拟环境（.venv/）与 collections，产出 artifacts/test/tools_versions.txt。所有 collections 必须从仓库随附的 `vendor/*.tar.gz` 本地解包（禁止访问 galaxy.ansible.com）。

make lint：静态风格、语法检查，必须限制在仓库源（playbooks/,roles/,inventory/ 等），不得扫入 .venv/ / Runner site-packages。

make test：在 --check 或等价安全模式下运行关键 playbook，输出到 artifacts/test/。

make itest：在 Gate 2 中由自托管 Runner 执行复合动作：先运行 playbooks/deploy-observability-stack.yml 部署最新变更，再立刻调用 playbooks/tests/verify_observability.yml 依据 docs/verification-spec.md 进行验证，并将证据写入 artifacts/itest/。

make deploy：保留为最终生产发布手段，仅在 make itest 全绿之后（主干或人工）执行。

Ⅲ. 两阶段指令与触发词（AI 必须严格按此执行）

阶段 G — 生成（Generation）

目标：实现 Issue，并创建 PR。禁止填写 Testing Done。

触发词（复制即可使用）

Repository: HomeOps

Task: Implement Issue #{编号}

严格遵守根目录 AGENTS.md 与 docs/verification-spec.md。

现在只做：实现修复并创建 PR。

⚠️ 【禁止】在 PR 描述中填写 “Testing Done”；保留为 PENDING-CI。

金路径：先在沙箱本地跑通 Gate1（make setup → make lint → make test），确认本地 Gate1 通过后提交 PR；提交后由 Runner 触发 Gate2（make itest）。

G 阶段行为清单（AI）

在本地沙箱依次运行：make setup、make lint、make test；收集日志与失败信息。

若本地 Gate1 未通过：在 PR 中记录失败日志片段与诊断（但不编造通过记录）。

创建 PR：PR 描述包含变更摘要、codex-meta 区块、留空的 Testing Done（或写 PENDING-CI）。

阶段 R — 报告（Reporting）

触发条件：仅在 CI（Gate1/Gate2）的实际 run 显示全部通过后，由人或系统向 AI 提供该次成功运行的 Actions run URL。

触发词（复制即可使用）

Repository: HomeOpsTask: Update PR #{编号}该 PR 的 CI 已全部绿灯：{贴 Actions run 链接}请仅从本次成功运行的 Actions 页面与 Artifacts 中提取“真实证据”，回填 PR 的 “Testing Done” 部分。⚠️ 【禁止】推测或虚构；只能引用本次 CI 的事实（Commit SHA / Job 结论 / Artifacts 路径 / 关键日志原文）。

R 阶段行为清单（AI）

访问并解析提供的 Actions run（必须是用户/系统明确给出的链接）。

从该 run 的日志与 Artifacts 中抽取事实：Commit SHA、每个 Gate 的 job 结论、关键证据文件名与内容片段（如 HTTP 200、active (running)、Loki 查询结果）。

用完全来自该 run 的证据回填 PR 的 Testing Done 区块；不得添加任何非 run 源的信息。

在 PR 评论中附上指向 run 与工件的直接链接（绝对 URL）。

Ⅳ. PR / Commit 必需格式（示例）

PR 描述必须包含：

一句变更摘要（1–2 句）。

Testing Done（留空于 G 阶段；R 阶段由 AI 回填，格式固定）：

Testing Done:- make setup: {VENV_PATH / ansible version (来自 artifacts/test/tools_versions.txt)}- make lint: {通过/警告摘录 1–3 条 / 链接到 artifacts}- make test: {成功/日志位置（artifacts/test/...）}- CI: {Actions run 链接 & 关键 Artifacts 链接}

codex-meta 区块（示例）：

<!-- codex-meta v1

task_id: OBS-STACK-001

domain: homeops

iteration: 1

network_mode: off



->

职责单一：PR 只解决一个 Issue；若多个变更需求，拆成多个 PR。

Ⅴ. Acceptance（机器可判）模板（写 Issue / 验收须遵循）

在 Issue 中务必给出机器可判的验收条件（例）：

Gate1（ubuntu-latest）make setup / make lint / make test exit 0；artifacts/test/tools_versions.txt 存在并含 ansible/ansible-lint/yamllint。

Gate2（self-hosted）make itest 产出 artifacts/itest/loki_query.json、artifacts/itest/datasources.json、artifacts/itest/health.json，并满足 docs/verification-spec.md 的 A/B/C/D 条款。

任一断言失败：playbook 必须以非零退出并仍上传工件（以便调查）。

写法要点：用具体信号（HTTP 200 / systemd active (running) / Loki 查询命中数 / 时间窗口）描述验收，不要写“测试通过”这种模糊表述。

Ⅵ. CI 与工件（Evidence）规范

工件路径固定：artifacts/test/（Gate1）与 artifacts/itest/（Gate2）。

必备工件：

artifacts/test/tools_versions.txt（make setup 输出）。

artifacts/test/ping.log 或等效自检输出（make test）。

artifacts/itest/：health.json, datasources.json, loki_query.json, journal_.log 等。

Evidence 要求：Testing Done 中引用的每一项都必须能在提供的 run 或工件中找到对应项（包含文件名与行片段）。

Ⅶ. 编写 Issue / 作业单的最佳实践（简明清单）

标题一句话清晰；Summary 2–3 句说明为什么重要。

Observed：列 2–5 条可复现现象，引用日志行（或粘贴关键片段）。

Requirements：只写目标，不给实现（不要写步骤或脚本）。

Acceptance：必须可机判，列出具体信号与产物路径。

Deliverables：明确需要修改的仓内文件/目录与 PR 要求（允许整文件替换）。

Testing Done：格式固定，等待 R 阶段回填。

Ⅷ. 常见问题与处理建议

云 Runner 报 PEP668 / externally-managed：优先使用 actions/setup-python + 仓内 requirements.txt 或在 runner 临时目录创建 venv（遵守 PEP668 限制）。在 Issue 中把该现象作为 Observed 一条并要求 CI 可复现。

ansible-lint 扫到 runner site-packages：在 .ansible-lint / .yamllint 中明确 exclude_paths，限制扫描范围到仓内路径。

需要紧急修复以 unblock CI：可以提交 临时 PR（标注 Hotfix），Acceptance 中需写明“临时措施，7 日内替代方案”。

Ⅸ. 自动化 Agent（未来规划 & 安全性）

目标：开发一个守证 Agent（例名 Argus / 证据驱动变更官），负责：

按 G→R 两阶段执行并记录操作历史；

在 R 阶段比对 PR 中 Testing Done 与 CI run 的一致性；

发现不一致自动留言并标注 evidence:discrepancy。

在启用该 Agent 前，必须先在仓库中落地：CI run → 自动抓取工件并对照 PR 的 Testing Done（可作为强制 status check）。

附录：示例（最小可复制片段）

PR 中 Testing Done（G 阶段留空示例）

Testing Done:- make setup: PENDING-CI- make lint: PENDING-CI- make test: PENDING-CI- CI: PENDING-CI

R 阶段回填示例（AI 必须来自提供的 run）

Testing Done:- make setup: /home/runner/temp/venv_homeops — ansible [core 2.19.3]



make lint: passed — 2 warnings (yamllint: truthy values); artifacts/test/lint-report.txt

make test: ping.yml check passed — artifacts/test/ping.log

CI: https://github.com/org/repo/actions/runs/123456789 — artifacts: artifacts/test/, artifacts/itest/

结语（执行者须知）

此文件是 HomeOps 对 AI/自动化代理的行为契约。每次代理在仓库内的变更都应能被 CI 的证据链追溯。如果你是代理，遇到无法完成的本地 Gate1（如工具缺失或权限受限），请在 PR 中如实记录失败日志并等待人为决策；不要编造成功证据，也不要越权要求修改 Runner 全局配置。

如需将此文件落库（AGENTS.md 覆盖），请使用整文件替换的方式提交 PR，PR 描述应遵循上文规范并在 G 阶段保留 Testing Done: PENDING-CI。
