.RECIPEPREFIX := >
.PHONY: galaxy keyscan ping facts bootstrap-linux bootstrap-windows switch-linux switch-windows keepalive lock-kernel setup lint test itest deploy

# Install required Ansible collections
galaxy:
> ansible-galaxy collection install -r requirements.yml

# Refresh SSH host keys
keyscan:
> bash scripts/ssh-keyscan.sh

# Basic connectivity checks
ping:
> ansible -i inventory/hosts.yaml linux -m ansible.builtin.ping
> ansible -i inventory/hosts.yaml windows -m ansible.builtin.command -a "hostname"

# Gather system facts
facts:
> ansible-playbook -i inventory/hosts.yaml playbooks/facts.yml

# Bootstrap hosts
bootstrap-linux:
> ansible-playbook -i inventory/hosts.yaml playbooks/bootstrap-linux.yml

bootstrap-windows:
> ansible-playbook -i inventory/hosts.yaml playbooks/bootstrap-windows.yml

# Switch operating systems
switch-linux:
> ansible-playbook -i inventory/hosts.yaml playbooks/switch-to-linux.yml

switch-windows:
> ansible-playbook -i inventory/hosts.yaml playbooks/switch-to-windows.yml

# Keep services alive
keepalive:
> ansible-playbook -i inventory/hosts.yaml playbooks/keepalive.yml

# Lock kernel version
lock-kernel:
> ansible-playbook -i inventory/hosts.yaml playbooks/lock-kernel.yml

# Runner tools setup
setup:
> ansible-playbook -i localhost, playbooks/runner-prepare.yml

# Gate 1 - lint & static checks
lint:
> ansible-lint
> yamllint .
> ansible-playbook --syntax-check -i inventory/hosts.yaml playbooks/*.yml

# Gate 1 - dry-run and idempotence
test:
> ansible-playbook -i inventory/hosts.yaml playbooks/facts.yml --check --diff
> ansible-playbook -i inventory/hosts.yaml playbooks/facts.yml

# Gate 2 - integration tests
itest:
> ansible-playbook -i inventory/hosts.yaml playbooks/tests/verify_observability.yml

# Deploy observability stack
deploy:
> ansible-playbook -i inventory/hosts.yaml playbooks/deploy-observability-stack.yml
