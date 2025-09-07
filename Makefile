.PHONY: galaxy ping facts bootstrap-linux bootstrap-windows switch-linux switch-windows keepalive keyscan lock-kernel

galaxy:
	ansible-galaxy collection install -r requirements.yml

keyscan:
	bash scripts/ssh-keyscan.sh

ping:
	ansible -i inventory/hosts.yaml linux -m ansible.builtin.ping
	ansible -i inventory/hosts.yaml windows -m ansible.builtin.command -a "hostname"

facts:
	ansible-playbook -i inventory/hosts.yaml playbooks/facts.yml

bootstrap-linux:
	ansible-playbook -i inventory/hosts.yaml playbooks/bootstrap-linux.yml

bootstrap-windows:
	ansible-playbook -i inventory/hosts.yaml playbooks/bootstrap-windows.yml

switch-linux:
	ansible-playbook -i inventory/hosts.yaml playbooks/switch-to-linux.yml

switch-windows:
	ansible-playbook -i inventory/hosts.yaml playbooks/switch-to-windows.yml

keepalive:
        ansible-playbook -i inventory/hosts.yaml playbooks/keepalive.yml

lock-kernel:
        ansible-playbook -i inventory/hosts.yaml playbooks/lock-kernel.yml
