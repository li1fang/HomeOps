# AGENTS.md — HomeOps / Ansible 项目操作手册（给 AI 与协作者）

> 本文件定义 **一条金路径**：任何改动都应只通过以下四个命令驱动与验证：  
> **`make lint` → `make test` → `make itest` → `make deploy`**。  
> CI 与守护流程（PR 保护分支）只认可这四个目标的结果。

---

## 0. 背景与范围（Scope）

- 仓库：**HomeOps**（家庭运维自动化平台）。  
- 控制器与自托管 Runner：**`ctrl-linux-01`**。CI 在该主机上执行需要连通硬件的步骤。  
- 私网：**Tailscale**。Ansible 通过私网访问受控主机。  
- 受控主机与分组（示例）：
  - `controllers`: `ctrl-linux-01`
  - `linux`: `ws-01-linux`, `ctrl-linux-01`

> 作用域就近优先：根目录 AGENTS.md 为全仓规则；如子目录另有 AGENTS.md，则以**离变更最近**的说明为准。禁止跨仓改动。

---

## 1. 环境与网络（Environment & Network）

- 执行环境：Linux，自托管 Runner（`ctrl-linux-01`）。
- **默认离线**：除 *setup 窗口* 外，流程不假设外网可达。部署所需的包应来自：
  1) 目标主机现有仓源/镜像，或  
  2) 预置的离线安装包（由仓库或内部制品库提供）。
- 禁止请求二次交互（GUI/人工输入）。只允许 **Ansible 原生模块** 与 HTTP API。
- 凭证管理：通过 GitHub Encrypted Secrets / Runner 本机凭证；**不得**把密钥写入仓库。

---

## 2. 目录导航（What you may edit）

- ✅ 允许：`playbooks/`、`roles/`、`group_vars/`、`host_vars/`、`templates/`、`scripts/`、`.github/workflows/`
- ⛔ 禁止：提交任何私密材料（密钥、令牌、私有证书）、修改 `inventory/hosts.yaml` 的主机名规范。
- Windows 相关任务必须使用 **`ansible.windows.win_*`** 原生模块；Linux 使用对应原生模块。

---

## 3. 金路径命令（Make Targets Contract）

> 人/CI/代理一律只使用以下四个目标。**不要**引入平行命令。

### 3.1 `make lint` — 静态检查（Gate 1/Step 1）
- 目的：风格/语法/最佳实践早期拦截。
- 应包含（参考实现）：
  ```bash
  ansible-lint
  yamllint .
  ansible-playbook --syntax-check -i inventory/hosts.yaml playbooks/**/*.yml
  ```

### 3.2 `make test` — 本地无破坏校验（Gate 1/Step 2）
- 目的：在 **check mode** 与二次运行校验幂等性，**不触达真实变更**。
- 口径：
  - 运行 **一次 check**：`--check --diff`
  - 再运行 **一次实际模式**，但仅执行 **幂等性探针**（不改变状态）或对无副作用任务进行 dry-run。
- 建议输出：`artifacts/test/` 收集检查报告。

### 3.3 `make itest` — 集成测试（Gate 2）
- 目的：在自托管 Runner 上对目标主机做 **真实部署前的可验收断言**（或蓝绿/影子环境）。
- 应执行：`playbooks/tests/verify_observability.yml`（见 §5 验收断言）。
- 失败处理：自动收集 **最近 200 行服务日志**、**关键 API 响应** 至 `artifacts/itest/` 并作为 CI 工件。

### 3.4 `make deploy` — 部署与回归
- 目的：只有在 `make itest` 通过后才允许执行（由 CI 流水线串联）。
- 应执行：`playbooks/deploy-observability-stack.yml` + 轻量回归（复跑部分验证）。
- 合并后：保护分支触发一次短回归（Smoke），与线上状态对齐。

---

## 4. PR 提交规范（PR Instructions）

- 标题：`[ansible/<scope>] 简要描述`（示例：`[ansible/observability] add loki+alloy+grafana stack`）
- 描述需包含：
  - **变更摘要**（1–2 句）
  - **Testing Done**：粘贴四个命令的关键信息（或链接到 CI 工件）
  - 追踪区块：
    ```md
    <!-- codex-meta v1
    task_id: OBS-STACK-001
    domain: homeops
    iteration: 1
    network_mode: setup-only
    -->
    ```
- 职责单一：一个 PR 只解决一个 Issue。

---

## 5. 典型任务：可观测性栈（Alloy + Loki + Grafana）

> 目标：在 `ctrl-linux-01` 部署 Loki+Grafana，在 `controllers,linux` 组部署 Alloy，采集 journald → Loki → Grafana 可查询。

### 5.1 Playbook 入口
- 统一入口：`playbooks/deploy-observability-stack.yml`
- 角色建议：
  - `roles/loki/` — 安装/配置/systemd
  - `roles/grafana/` — 安装/配置/systemd + **自动创建 Loki 数据源**
  - `roles/alloy/` — 安装/配置/systemd + `config.alloy`（journald → Loki@ctrl-linux-01）
- 目标选择：
  - `hosts: controllers` → Loki/Grafana（默认 `ctrl-linux-01`）
  - `hosts: linux,controllers` → Alloy（`ws-01-linux` + `ctrl-linux-01`）

### 5.2 可机判的验收断言（由 `make itest` 触发）

**A. 服务活性（部署后即判）**
- `systemctl is-active loki grafana-server alloy` → 均为 `active`
- 端口：Loki `3100`、Grafana `3000` 可达（TCP）

**B. 连通性（部署后 30–60 秒内重试）**
- `GET http://<ctrl-linux-01>:3000/api/health` → `database: ok`
- Grafana 存在名为 **`Loki`** 的数据源（API 查询校验）

**C. 功能性（E2E 90 秒超时，轮询）**
- 调用 Loki 查询：`{job="systemd-journal"}`  
  需同时检出：`ws-01-linux` 与 `ctrl-linux-01` 的近期日志样本（各 ≥ 1 条）

> 所有断言失败时：保存 **API 响应 JSON** 与 **近 200 行 `loki`, `grafana-server`, `alloy` 的 `journalctl` 输出** 到 `artifacts/itest/`。

---

## 6. 失败诊断与常见修复（PR Bot 模板要点）

- **lint 失败**：修复 `ansible-lint`/`yamllint` 报告；遵循模块最佳实践与变量命名规范。
- **语法/幂等失败**：检查 `changed_when`/`check_mode` 兼容性；模板渲染是否有条件分支漏判。
- **服务活性失败**：确认 `ExecStart`/二进制路径/权限；`After=network-online.target`；`daemon-reload`。
- **连通性失败**：Grafana 初始管理员密码/数据源 URL；Loki `server.http_listen_port` 与 `ingester` 配置。
- **功能性失败**：Alloy `journald` 输入权限；推送端点 URL；标签 `job=systemd-journal` 是否一致。

---

## 7. 安全与合规（Security）

- 不引入未审计的外部安装脚本；优先发行版包或内网镜像。  
- 不在 CI 日志中泄露密钥/令牌；敏感字段用 `no_log: true`。  
- 不执行特权容器；不修改内核参数（除非任务明确声明）。

---

## 8. 快速开始（Quick Start for Humans & Agents）

```bash
# 1) 本地静态检查
make lint

# 2) 本地无破坏校验（check 模式 + 幂等性探针）
make test

# 3) 在自托管 Runner 上做集成测试（Gate 2）
make itest

# 4) 部署（仅在 Gate 2 通过后）
make deploy
```

---

## 9. 机器可读摘要（AI Digest）

```yaml
ai_digest:
  contract_targets: ["make lint", "make test", "make itest", "make deploy"]
  inventory_groups:
    controllers: ["ctrl-linux-01"]
    linux: ["ws-01-linux", "ctrl-linux-01"]
  observability_playbook: "playbooks/deploy-observability-stack.yml"
  acceptance:
    service_active: ["loki","grafana-server","alloy"]
    ports_open:
      ctrl-linux-01: [3000, 3100]
    grafana_checks:
      health_endpoint: "http://<ctrl-linux-01>:3000/api/health expects database: ok"
      datasource: "Loki"
    loki_query:
      expr: '{job="systemd-journal"}'
      must_include_hosts: ["ws-01-linux","ctrl-linux-01"]
      timeout_seconds: 90
  artifacts_dir: "artifacts/itest"
  failure_captures:
    - "journalctl -u loki -n 200"
    - "journalctl -u grafana-server -n 200"
    - "journalctl -u alloy -n 200"
```

---

## 10. 版本与治理

- 适用于：`HomeOps` 仓库（v0.1）。
- 变更流程：通过 PR 修改本文件；CI 会以此为准做校验与放行。

> 记住：**一切以“可执行的命令 + 可机判的断言 + 可回溯的证据”为准**。这就是我们“自动化真正自动”的根。

