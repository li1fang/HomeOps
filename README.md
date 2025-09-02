# HomeOps · Ansible 最终版（Windows↔Linux 自动切换 + 自愈）

这是为你的家庭集群定制的 **最终版 Ansible 骨架**。相比之前两版，本版：

- ✅ **跨平台更稳**：Windows 仍用 **SSH** 执行 PowerShell，无需 WinRM；Linux 走标准 SSH；
- ✅ **蓝屏规避**：`to-linux.ps1` 仅设置 **一次性** 引导到 Ubuntu，不改默认；
- ✅ **BootNext 正确免密**：Linux 侧自动探测 `efibootmgr/reboot` 路径，按实际路径生成 `sudoers`；
- ✅ **WoL 兜底**：`switch-to-windows.yml` 会在 Windows 迟迟不上线时自动发 Magic Packet；
- ✅ **自愈/保活**：`keepalive.yml` 统一保活 `ssh` / `tailscale` / `sshd`；
- ✅ **易用**：`Makefile` 快捷命令 + `ssh-keyscan.sh` 自动刷新指纹；
- ✅ **可进化**：所有切换脚本通过 **template/copy** 下发，后续你修改一处，整网生效。

---

## 目录结构

```
ansible.cfg
requirements.yml
inventory/hosts.yaml
group_vars/
  linux.yml
  windows.yml
templates/
  to-windows.sh.j2
  to-linux.ps1.j2
playbooks/
  ping.yml
  facts.yml
  bootstrap-linux.yml
  bootstrap-windows.yml
  switch-to-linux.yml
  switch-to-windows.yml
  keepalive.yml
scripts/
  ssh-keyscan.sh
Makefile
README.md
```

---

## 先决条件

- 控制端：`whipc`（Linux）已安装 `ansible`、可以通过 **SSH** 连接 `whipx` / `whipz`；
- 已安装 Tailscale，**inventory 中使用 Tailscale IPv4**；
- Windows（whipx）已安装 OpenSSH-Server（我们也提供 bootstrap）。

---

## 快速开始（在 `whipc`）

```bash
# 1) 安装依赖
sudo apt update && sudo apt install -y ansible git jq

# 2) 克隆你的仓库，并创建分支（建议）
mkdir -p ~/src && cd ~/src
git clone git@github.com:li1fang/homeops.git
cd homeops && git checkout -b ansible-final

# 3) 把本目录内容拷入仓库（如果你是下载 ZIP）
#   rsync -a /path/to/homeops-ansible-final/ ./

# 4) 安装 collections
make galaxy

# 5) 刷新主机指纹（避免“Host key changed”报错）
make keyscan

# 6) 验证连通
make ping
make facts

# 7) 首次引导（一次性把脚本/权限/服务铺到位）
make bootstrap-linux
make bootstrap-windows

# 8) 双向切换演练
make switch-linux     # Windows → Linux
make switch-windows   # Linux → Windows
```

> 如遇到等待时间不够，可按机器实际速度把 `switch-*.yml` 中 `timeout` 加大。

---

## Inventory（按你现状预填）

`inventory/hosts.yaml`：
```yaml
all:
  children:
    control:
      hosts:
        whipc:
          ansible_host: 100.103.154.96
          ansible_user: whipc
    windows:
      hosts:
        whipx:
          ansible_host: 100.81.77.26
          ansible_user: Administrator
          ansible_connection: ssh
          ansible_shell_type: powershell
          ansible_shell_executable: None
          wol_mac: "9C:6B:00:05:B4:16"
          wol_broadcast: "192.168.1.255"
    linux:
      hosts:
        whipz:
          ansible_host: 100.67.3.75
          ansible_user: whipz
        whipc:
          ansible_host: 100.103.154.96
          ansible_user: whipc
```

> 若 Tailscale IP 变动，**只改这一处**。

---

## 关键设计点

- **最小权限原则**：Linux 侧只对真实路径的 `efibootmgr` / `reboot` 免密；
- **一次性引导**：Windows 只设置 `bootsequence {GUID}`，默认仍是 Windows（避免蓝屏）；
- **等待 + 兜底**：等待 A 侧下线、B 侧上线；超时对 Windows 发送 WoL 再等一轮；
- **不强绑 Sunshine/Tailscale 安装**：只做“存在则启动”，避免破坏你现有环境；
- **SSH 指纹管理**：`scripts/ssh-keyscan.sh` 先 `ssh-keygen -R` 再 `ssh-keyscan -H`，免交互。

---

## 常见问题

- **Windows 蓝屏**：本方案不改默认引导，`to-linux.ps1` 只做“一次性”切换，已规避。
- **Linux sudo 仍提示密码**：路径不一致最常见（`/usr/bin/efibootmgr` vs `/usr/sbin/efibootmgr`）。`bootstrap-linux.yml` 已自动探测并写入 sudoers。
- **Windows 不上线**：检查 `wol_mac` 是否与主板有线口一致；必要时手工 WoL 一次确认链路；
- **Host key changed**：运行 `make keyscan` 即可刷新。

---

## 下一步（与 K8s / Sealos / Ray 的衔接）

- 以 Ansible 继续追加：NVIDIA 驱动对齐、Docker/Containerd 安装、Sealos/Kubeadm 初始化、加入集群；
- 基于 facts 做“按需”部署：例如仅在具备 4090 的节点打上 `gpu=true` 的标签；
- 写一个 `playbooks/keepalive.yml` 的定时器（cron/systemd timer），让“家庭自愈”持续运行。

---

**祝你一路顺利。我们用标准化的 Infra-as-Code，替代脚本堆叠。你只要持续 commit → PR → 合并，集群就会越来越稳。**
