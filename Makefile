# Makefile — PEP668-safe: setup does NOT install system packages
INVENTORY := inventory/hosts.yaml
ART_TEST := artifacts/test
ART_ITEST := artifacts/itest

export ANSIBLE_STDOUT_CALLBACK=ansible.builtin.yaml
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

.PHONY: setup lint test itest deploy

setup:
	@echo "--- Gate0: record venv tool versions (no system installs) ---"
	@mkdir -p $(ART_TEST)
	@if [ -x ".venv/bin/ansible" ]; then \
		. .venv/bin/activate; \
		{ \
		  echo "ansible      : $$(ansible --version | head -n1)"; \
		  echo "ansible-lint : $$(ansible-lint --version | head -n1)"; \
		  echo "yamllint     : $$(yamllint --version)"; \
		} > $(ART_TEST)/tools_versions.txt; \
	else \
		echo "venv not present; this is expected on first run. Gate1 will create it in the workflow." > $(ART_TEST)/tools_versions.txt; \
	fi

lint:
	@echo "--- Gate1/Step1: Static Analysis ---"
	@. .venv/bin/activate; ansible-lint || exit $$?
	@. .venv/bin/activate; yamllint . || exit $$?
	@echo "Syntax-check all playbooks..."
	@set -e; for f in $(shell find playbooks -type f -name "*.yml" 2>/dev/null); do \
		. .venv/bin/activate; ansible-playbook -i $(INVENTORY) --syntax-check $$f; \
	done

test:
	@echo "--- Gate1/Step2: Safe local checks ---"
	@. .venv/bin/activate; ansible-playbook -i $(INVENTORY) playbooks/ping.yml --check --diff

itest:
	@echo "--- Gate2: Integration tests on self-hosted runner ---"
	@mkdir -p $(ART_ITEST)
	@. .venv/bin/activate; ansible-playbook -i $(INVENTORY) playbooks/tests/verify_observability.yml -e output_dir=$(ART_ITEST)

deploy:
	@echo "--- Deploy (conditional) ---"
	@. .venv/bin/activate; ansible-playbook -i $(INVENTORY) playbooks/deploy-observability-stack.yml
