# Sealos + LangGraph Playbooks

本包提供两步式部署：
1) `provision-sealos.yml` 在控制器（controllers 组）安装 Sealos 并启动单节点 Kubernetes。
2) `deploy-langgraph.yml` 在集群中部署最小可用的 LangGraph v1.0.0rc1 服务。

## 先决条件
- 目标主机：Ubuntu/Debian（root 权限，`become: true`）。
- 自托管 Runner 网络可访问 GitHub 与 PyPI。
- Ansible 控制端已能 SSH 到 `controllers` 组的主机（例如 `ctrl-linux-01`）。

## 使用
```bash
# 1) 启动 Kubernetes（Sealos）
ansible-playbook -i inventory/hosts.yaml playbooks/k8s/provision-sealos.yml -l controllers

# 2) 部署 LangGraph 服务
ansible-playbook -i inventory/hosts.yaml playbooks/k8s/deploy-langgraph.yml -l controllers
```

部署完成后，在控制器节点上访问：
- 健康检查: `curl http://127.0.0.1:30080/health` → `{"ok": true}`
- Demo 运行: `curl -X POST http://127.0.0.1:30080/run -H 'Content-Type: application/json' -d '{"n": 1}'`

## 参数与注意
- 如需调整版本：编辑 `playbooks/k8s/provision-sealos.yml` 与 `deploy-langgraph.yml` 中的 `sealos_version`、`k8s_image`、`langgraph_version` 等变量。
- 如果 `sealos` 指定版本下载失败，先到 GitHub Releases 检查是否存在，再修改变量重试。
- 此实现不依赖 `kubernetes.core` collection，直接用 `kubectl` 应用 YAML，以降低环境耦合。
- 提示：首次拉镜像时间较长，耐心等待 `rollout status` 完成。
