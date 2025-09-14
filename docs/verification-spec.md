Verification Spec — Observability Stack (Alloy + Loki + Grafana)
目的：定义 Gate 2 / make itest 的唯一判分标准与证据口径。
适用仓库：HomeOps（控制器与 Runner：ctrl-linux-01）。
关联契约：AGENTS.md / Makefile（lint → test → itest → deploy）。

0. 前置条件（Pre-req & Env）
控制器与自托管 Runner：ctrl-linux-01（标签：self-hosted, ansible, hardware）。

Inventory 分组：

controllers: ctrl-linux-01

linux: ws-01-linux, ctrl-linux-01

端口：Loki 3100，Grafana 3000（可通过变量覆盖）。

Secrets（由项目负责人配置到 Runner/CI）：

GRAFANA_ADMIN_USER / GRAFANA_ADMIN_PASSWORD 用于 Grafana API。

1. 金路径引用
Gate 1：make lint / make test

Gate 2：make itest → 执行本规格的所有断言；失败必须收集证据到 artifacts/itest/；任何断言失败均返回非零退出码。

2. 断言与证据（Assertions & Evidence）
A. 服务活性（即刻判）
断言

在 controllers 上：loki、grafana-server 为 active

在 controllers, linux 上：alloy 为 active

失败时证据

保存最近 200 行日志：

journalctl -u loki -n 200 → artifacts/itest/journal_loki.log

journalctl -u grafana-server -n 200 → artifacts/itest/journal_grafana.log

journalctl -u alloy -n 200 → artifacts/itest/journal_alloy.log

B. 端口连通（30s 重试）
断言

ctrl-linux-01:3100（Loki）、ctrl-linux-01:3000（Grafana）TCP 可达（max 30s，退避重试）。

失败时证据

ss -lntp 与 iptables -S 输出 → artifacts/itest/net_diag.txt

C. Grafana 健康与数据源（60s 重试）
断言

GET http://ctrl-linux-01:3000/api/health 返回 JSON 含 "database": "ok"

存在名为 Loki 的数据源（/api/datasources 列表中匹配）

方法与证据

Ansible uri，用 GRAFANA_ADMIN_USER/PASSWORD 基本认证。

响应 JSON 保存为：

artifacts/itest/health.json

artifacts/itest/datasources.json

D. 日志功能性（Loki 查询，90s 轮询）
断言

对 http://ctrl-linux-01:3100/loki/api/v1/query_range 以表达式 {job="systemd-journal"} 在 90s 内查询到同时来自 ws-01-linux 与 ctrl-linux-01 的日志（各 ≥ 1 条）。

方法与证据

用 uri 轮询；保存最后一次请求与响应：artifacts/itest/loki_query.json
