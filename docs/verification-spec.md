# Observability Stack Verification Spec (Gate 2)

**Scope**: Validate the Loki + Grafana + Alloy stack deployed on the controller `ctrl-linux-01` and ingestion from all Linux nodes (e.g., `ctrl-linux-01`, `ws-01-linux`).

## Acceptance Criteria (machine-verifiable)

### A. Services are installed and running on controller
- `loki` systemd service is **active (running)** and **enabled**.
- `grafana-server` systemd service is **active (running)** and **enabled**.
- `alloy` systemd service is **active (running)** and **enabled** on target hosts (`controllers` + `linux`).

### B. Endpoints are reachable on controller
- Loki readiness endpoint responds with HTTP **200**: `http://127.0.0.1:3100/ready`
- Grafana responds on port **3000**; `/api/health` should return **200** (OK) or **401** (Unauthorized), both indicate reachability without credentials.

### C. Logs are flowing
- A query against Loki for `{job="systemd-journal"}` returns **at least 1** entry from **each** of:
  - `ctrl-linux-01`
  - `ws-01-linux`
- Freshness: the newest entry from each host is **≤ 10 minutes** old.

## Reference Implementation Hints (Ansible)
A real `playbooks/tests/verify_observability.yml` SHOULD:
1. **Check systemd** status and enablement
   ```yaml
   - ansible.builtin.service_facts:
   - ansible.builtin.assert:
       that:
         - "'loki.service' in ansible_facts.services and ansible_facts.services['loki.service'].state == 'running'"
         - "'grafana-server.service' in ansible_facts.services and ansible_facts.services['grafana-server.service'].state == 'running'"
   ```
2. **Probe endpoints**
   ```yaml
   - ansible.builtin.uri:
       url: "http://127.0.0.1:3100/ready"
       status_code: 200
   - ansible.builtin.uri:
       url: "http://127.0.0.1:3000/api/health"
       status_code: [200, 401]
   ```
3. **Query Loki for journal entries**
   - Either call the Loki HTTP API:
     ```yaml
     - ansible.builtin.uri:
         url: "http://127.0.0.1:3100/loki/api/v1/query"
         method: GET
         return_content: true
         params:
           query: '{job="systemd-journal"}'
     ```
   - Or shell out to `journalctl` as a minimal smoke:
     ```yaml
     - ansible.builtin.command: journalctl -n 1 -o short-iso
       register: jctl
     - ansible.builtin.assert:
         that: jctl.stdout != ""
     ```
4. **Collect artifacts** (logs, `systemctl status` outputs, API responses) under `artifacts/itest/` for CI review.

## Scoring
- Gate 2 passes if **A + B + C** all hold.
- If any check fails, the playbook MUST `failed_when: true` with clear messages and write relevant outputs to `artifacts/itest/`.

---
**Note**: The current repository includes a placeholder `playbooks/tests/verify_observability.yml` so CI can run. Replace it per this spec in Issue #27.
