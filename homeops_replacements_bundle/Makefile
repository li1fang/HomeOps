# Makefile — HomeOps Golden Path

INVENTORY := inventory/hosts.yaml
ART_TEST := artifacts/test
ART_ITEST := artifacts/itest

.PHONY: setup lint test itest deploy

setup:
	@echo "--- Local setup (optional) ---"
	@python3 -m pip install --upgrade pip >/dev/null 2>&1 || true
	@python3 -m pip install ansible ansible-lint yamllint >/dev/null 2>&1 || true

lint:
	@echo "--- Gate 1 / Step 1: Static Analysis ---"
	@ansible-lint || exit $$?
	@yamllint . || exit $$?
	@echo "Syntax-check all playbooks..."
	@set -e; for f in $(shell find playbooks -type f -name "*.yml" 2>/dev/null); do \
		ansible-playbook -i $(INVENTORY) --syntax-check $$f; \
	done

test:
	@echo "--- Gate 1 / Step 2: Safe local checks (no remote state change) ---"
	@mkdir -p $(ART_TEST)
	@ansible-playbook -i $(INVENTORY) playbooks/ping.yml --check --diff

itest:
	@echo "--- Gate 2: Integration tests on self-hosted runner ---"
	@mkdir -p $(ART_ITEST)
	@ansible-playbook -i $(INVENTORY) playbooks/tests/verify_observability.yml -e output_dir=$(ART_ITEST)

deploy:
	@echo "--- Deploy (conditional; only enabled via CI conditions) ---"
	@ansible-playbook -i $(INVENTORY) playbooks/deploy-observability-stack.yml
