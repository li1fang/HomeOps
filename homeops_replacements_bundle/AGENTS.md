# AGENTS.md — HomeOps（适配 Codex 云代理）

> **目的**：把“对 AI 的工作说明”固定在仓库，所有人/CI/代理都遵循同一套“金路径”。
> **非目标**：本文件不替代人看的 README；不定义特权或联网；不要求代理修改环境。

---

## 1. 运行环境与边界（Environment & Guardrails）

- 代理运行在**受限、默认离线**的 Linux 沙箱。不要尝试 `apt-get`/`pip install` 从外网拉依赖。
- 代码改动必须通过**四步金路径**（见下），由 CI 判定是否可合入。
- **docs-only**（仅变更 `*.md`/`docs/**`）不进入代码关卡（lint/test/itest）。工作流会自动识别并跳过。

---

## 2. 项目导航（Project Layout）

- `inventory/hosts.yaml` — Ansible 主机清单（包含 `controllers` 与 `linux` 分组）。
- `playbooks/` — 所有剧本；测试剧本在 `playbooks/tests/`。
- `docs/verification-spec.md` — **机判验收口径**（唯一权威）。
- `.github/workflows/pr-quality-check.yml` — CI 金路径编排。

---

## 3. 金路径命令（Make Targets Contract）

> 人/CI/代理一律只使用以下四个目标。**不要**引入平行命令。

### 3.1 `make setup` — 本地工具自举（可选）
- 目的：在本地开发机安装 Ansible 工具链（CI 自有安装逻辑，不依赖此步骤）。

### 3.2 `make lint` — 静态检查（Gate 1 / Step 1）
- 目的：风格/语法/最佳实践早期拦截。
- 参考实现：`ansible-lint`、`yamllint .`、`ansible-playbook --syntax-check`

### 3.3 `make test` — 本地无破坏校验（Gate 1 / Step 2）
- 目的：在 **check mode** 与二次运行校验幂等性，**不触达真实变更**；默认仅对 `localhost` 做安全探针。

### 3.4 `make itest` — 集成测试（Gate 2 / 自托管 Runner）
- 目的：在真实硬件上执行**可机判验收**；
- **判分标准**：详见 [`docs/verification-spec.md`](docs/verification-spec.md)；
- 默认执行：`playbooks/tests/verify_observability.yml`（输出到 `artifacts/itest/`）。

### 3.5 `make deploy` — 部署与回归（条件执行）
- 目的：仅在 Gate 2 通过且分支/变量条件满足时触发；调用 `playbooks/deploy-observability-stack.yml`。

---

## 4. PR / Commit 规范（For Humans & Agents）

- **标题**：`[ansible/<scope>] 简要描述`
- **描述**必须包含：
  - **变更摘要**（1–2 句）
  - **Testing Done**（四个命令关键输出 / CI 链接）
  - 追踪区块：
    ```md
    <!-- codex-meta v1
    task_id: <ID>
    domain: homeops
    iteration: <n>
    network_mode: off
    -->
    ```
- **职责单一**：一个 PR / commit 只解决一个 Issue。

---

## 5. 注意事项（Hints for Agents）

- 遇到失败，请将 CI 工件（`artifacts/itest/*`）的相关片段原样贴回，按 `docs/verification-spec.md` 的条目逐一修复。
- 不要并行处理多个 Issue；**串行**推进以避免重状态环境互相干扰。
