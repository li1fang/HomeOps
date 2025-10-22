# Incident Report: Persistent dpkg Lock (PID 90709)

## Summary
On `ctrl-linux-01`, repeated CI failures traced back to a stuck `dpkg` frontend lock. Using `lsof` and `ps` during a failing run showed that **PID 90709** was the long-running `unattended-upgrades` worker spawned by systemd's scheduled `apt-daily` jobs. Because the worker held `/var/lib/dpkg/lock-frontend` for minutes at a time, every `apt` invocation in our deployment playbooks returned exit code 2 and aborted the pipeline.

## Mitigation
The fix shipped in Issue #55 neutralizes the offending automation in two layers:

1. **Stop and mask systemd units**: `unattended-upgrades.service`, `apt-daily(.service|.timer)`, and `apt-daily-upgrade(.service|.timer)` are now explicitly stopped, disabled, and masked before any package tasks run. This prevents systemd from relaunching the background job mid-play.
2. **Disable APT periodic tasks**: a managed drop-in (`/etc/apt/apt.conf.d/99homeops-disable-periodic`) sets every `APT::Periodic::*` switch to `"0"`, ensuring package timers remain off even after package upgrades.

These actions are executed on the controller as well as every Linux target before the playbooks touch `apt`, guaranteeing a clean package manager state for Gate1/Gate2.

## Follow-up
- Monitor upcoming Gate2 runs (`make itest`) for the absence of `dpkg` lock contention.
- If unattended security updates are desired in the future, consider re-enabling them via a controlled maintenance window or an Ansible task that coordinates downtime outside CI.
