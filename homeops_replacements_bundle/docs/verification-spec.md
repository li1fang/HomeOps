# Verification Spec — Observability Stack (Loki + Grafana + Alloy)

> **Normative**: 本文为 Gate 2（`make itest`）的**唯一权威口径**。任何结果均以此文为准。

## 0. 目标主机与约定

- 控制器：`ctrl-linux-01` ∈ 组 `controllers`
- 采集器节点：`linux` 组（包含 `ctrl-linux-01` 与 `ws-01-linux` 等）
- 端口：
  - Loki: TCP `3100`（`/ready` 返回 `200`）
  - Grafana: TCP `3000`（`/login` 返回 `200` 即视为可达，无需鉴权）

## 1. 机判条目（MUST）

### A. Systemd 服务健康（controllers & linux）
- 控制器 `ctrl-linux-01`：
  - `loki` 服务 **active (running)**
  - `grafana-server` 服务 **active (running)**
- 所有 `linux` 组主机（含 `ctrl-linux-01`）：
  - `alloy` 服务 **active (running)**

### B. 端口可用（controllers）
- `ctrl-linux-01:3100` 可连接（Loki）
- `ctrl-linux-01:3000` 可连接（Grafana）

### C. Loki 摄取（journald）
- 在 `ctrl-linux-01` 对 Loki 执行健康探针：`GET /ready` 返回 `200`
- 至少能查询到近 5 分钟内的 journald 记录（标签思路 `{job="systemd-journal"}`；若查询接口受限，则以端口+健康探针替代，保留 TODO 备注）

### D. Grafana Reachability（controllers）
- `GET http://127.0.0.1:3000/login` 返回 `200`

## 2. 工件输出（Artifacts）

`make itest` 必须在仓库根输出：

```
artifacts/itest/
  ├─ services.json            # systemd 状态汇总（per host）
  ├─ ports.json               # 端口检查结果
  ├─ loki_ready.json          # Loki /ready 探针响应（status/elapsed）
  ├─ grafana_login.json       # Grafana /login 探针响应（status/elapsed）
  ├─ journal_tail_ctrl.txt    # ctrl-linux-01 上 loki/alloy/grafana 最近 200 行日志（若失败时）
  └─ net_diag.txt             # 简要网络诊断（ping/route，仅失败时）
```

## 3. 失败判定与回收

- 任一 MUST 条目失败 → `make itest` 失败（红灯）。
- 失败时必须**仍然生成**上述工件，以便人/AI 复盘。
- 恢复后重跑，应在 2 回合内修至绿灯（经验外推超过 2 回合需补充注释）。

## 4. 参考实现

- 测试剧本：`playbooks/tests/verify_observability.yml`
- 部署剧本：`playbooks/deploy-observability-stack.yml`（完成 #28 后生效）
