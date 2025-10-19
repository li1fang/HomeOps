# Makefile — Option A: no local .venv dependency; tools expected on PATH (workflow injects)
INVENTORY := inventory/hosts.yaml
ART_TEST := artifacts/test
ART_ITEST := artifacts/itest

export ANSIBLE_STDOUT_CALLBACK=ansible.builtin.yaml
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

.PHONY: setup lint test itest deploy

setup:
	@echo "--- Gate0: record tool versions (PATH-venv expected) ---"
	@mkdir -p $(ART_TEST)
	@{ \
	  ansible --version | head -n1 || echo 'ansible not found'; \
	  ansible-lint --version || echo 'ansible-lint not found'; \
	  yamllint --version || echo 'yamllint not found'; \
	} > $(ART_TEST)/tools_versions.txt

lint:
	@echo "--- Gate1/Step1: Static Analysis ---"
	@ansible-lint || exit $$?
	@yamllint . || exit $$?
	@echo "Syntax-check all playbooks..."
	@set -e; for f in $(shell find playbooks -type f -name "*.yml" 2>/dev/null); do \
		ansible-playbook -i $(INVENTORY) --syntax-check $$f; \
	done

test:
	@echo "--- Gate1/Step2: Safe local checks ---"
	@mkdir -p $(ART_TEST)
	@ansible-playbook -i $(INVENTORY) playbooks/ping.yml --check --diff

itest:
	@echo "--- Gate2: Integration tests on self-hosted runner ---"
	@mkdir -p $(ART_ITEST)
	@ansible-playbook -i $(INVENTORY) playbooks/tests/verify_observability.yml -e output_dir=$(ART_ITEST)

deploy:
	@echo "--- Deploy (conditional) ---"
	@ansible-playbook -i $(INVENTORY) playbooks/deploy-observability-stack.yml
