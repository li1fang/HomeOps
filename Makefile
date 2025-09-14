# Makefile — HomeOps Golden Path (hotfix: default stdout callback)
INVENTORY := inventory/hosts.yaml
ART_TEST := artifacts/test
ART_ITEST := artifacts/itest

# Force default callback to avoid missing community.general.yaml on fresh machines
export ANSIBLE_STDOUT_CALLBACK=default
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

.PHONY: setup lint test itest deploy

setup:
	@echo "--- Local setup (optional) ---"
	@python3 -m pip install --upgrade pip >/dev/null 2>&1 || true
	@python3 -m pip install ansible ansible-lint yamllint >/dev/null 2>&1 || true
	@mkdir -p $(ART_TEST)
	@echo "tools: $$(ansible --version | head -n1 2>/dev/null || echo 'ansible not found')" > $(ART_TEST)/tools_versions.txt || true
	@echo "ansible-lint: $$(ansible-lint --version 2>/dev/null || echo 'not found')" >> $(ART_TEST)/tools_versions.txt || true
	@echo "yamllint: $$(yamllint --version 2>/dev/null || echo 'not found')" >> $(ART_TEST)/tools_versions.txt || true

lint:
	@echo "--- Gate 1 / Step 1: Static Analysis ---"
	@ansible-lint || exit $$?
	@yamllint . || exit $$?
	@echo "Syntax-check all playbooks..."
	@set -e; for f in $(shell find playbooks -type f -name "*.yml" 2>/dev/null); do \
		ANSIBLE_STDOUT_CALLBACK=default ansible-playbook -i $(INVENTORY) --syntax-check $$f; \
	done

test:
	@echo "--- Gate 1 / Step 2: Safe local checks (no remote state change) ---"
	@mkdir -p $(ART_TEST)
	@ANSIBLE_STDOUT_CALLBACK=default ansible-playbook -i $(INVENTORY) playbooks/ping.yml --check --diff

itest:
	@echo "--- Gate 2: Integration tests on self-hosted runner ---"
	@mkdir -p $(ART_ITEST)
	@ANSIBLE_STDOUT_CALLBACK=default ansible-playbook -i $(INVENTORY) playbooks/tests/verify_observability.yml -e output_dir=$(ART_ITEST)

deploy:
	@echo "--- Deploy (conditional; only enabled via CI conditions) ---"
	@ANSIBLE_STDOUT_CALLBACK=default ansible-playbook -i $(INVENTORY) playbooks/deploy-observability-stack.yml
