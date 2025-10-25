# Makefile — reproducible tooling with local venv + collection cache
INVENTORY := inventory/hosts.yaml
ART_TEST := artifacts/test
ART_ITEST := artifacts/itest

VENV_DIR := .venv
VENV_BIN := $(VENV_DIR)/bin
VENV_PYTHON := $(VENV_BIN)/python
VENV_MARKER := $(VENV_DIR)/.bootstrapped
VENV_ABS := $(abspath $(VENV_DIR))

COLLECTIONS_DIR := collections
COLLECTIONS_MARKER := $(COLLECTIONS_DIR)/.install-complete

ANSIBLE_CMD := $(VENV_BIN)/ansible
ANSIBLE_PLAYBOOK := $(VENV_BIN)/ansible-playbook
ANSIBLE_LINT := $(VENV_BIN)/ansible-lint
YAMLLINT := $(VENV_BIN)/yamllint
GALAXY := $(VENV_BIN)/ansible-galaxy
INSTALL_COLLECTIONS := scripts/install_collections.sh
LINT_PATHS := playbooks group_vars host_vars inventory templates

export ANSIBLE_CONFIG := $(CURDIR)/ansible.cfg
export ANSIBLE_STDOUT_CALLBACK ?= ansible.builtin.yaml
export ANSIBLE_DISPLAY_SKIPPED_HOSTS ?= false
export ANSIBLE_LINT_WARNINGS ?= skip-path-validation

.PHONY: setup lint test itest deploy clean

$(VENV_MARKER): requirements.txt
	@echo "--- creating local venv at $(VENV_ABS) ---"
	@python3 -m venv $(VENV_DIR)
	@$(VENV_PYTHON) -m pip install --upgrade pip wheel
	@$(VENV_PYTHON) -m pip install --requirement requirements.txt
	@touch $@

$(COLLECTIONS_MARKER): requirements.yml $(VENV_MARKER)
	@echo "--- installing Ansible collections into $(abspath $(COLLECTIONS_DIR)) ---"
	@$(INSTALL_COLLECTIONS) "$(GALAXY)" requirements.yml "$(COLLECTIONS_DIR)"
	@touch $@

setup: $(VENV_MARKER) $(COLLECTIONS_MARKER)
	@echo "--- Gate0: bootstrap reproducible toolchain ---"
	@mkdir -p $(ART_TEST)
	@$(VENV_PYTHON) scripts/record_tool_versions.py \
	--venv-path "$(VENV_ABS)" \
	--python "$(VENV_PYTHON)" \
	--ansible "$(ANSIBLE_CMD)" \
	--ansible-lint "$(ANSIBLE_LINT)" \
	--yamllint "$(YAMLLINT)" \
	--output "$(ART_TEST)/tools_versions.txt"

lint: $(VENV_MARKER) $(COLLECTIONS_MARKER)
	@echo "--- Gate1/Step1: Static Analysis ---"
	@$(ANSIBLE_LINT) $(LINT_PATHS)
	@$(YAMLLINT) $(LINT_PATHS) .github/workflows
	@echo "--- Syntax-check all playbooks ---"
	@$(VENV_PYTHON) scripts/syntax_check_playbooks.py \
	--ansible-playbook "$(ANSIBLE_PLAYBOOK)" \
	--inventory "$(INVENTORY)" \
	--playbooks-root "playbooks"

test: $(VENV_MARKER) $(COLLECTIONS_MARKER)
	@echo "--- Gate1/Step2: Safe local checks ---"
	@mkdir -p $(ART_TEST)
	@bash -c "set -euo pipefail; '$(ANSIBLE_PLAYBOOK)' -i localhost, -c local playbooks/ping.yml --check --diff | tee '$(ART_TEST)/ping.log'"

itest: $(VENV_MARKER) $(COLLECTIONS_MARKER)
	@echo "--- Gate2: Deploy & verify on self-hosted runner ---"
	@$(MAKE) setup
	@mkdir -p $(ART_ITEST)
	@$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/deploy-observability-stack.yml
	@$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/tests/verify_observability.yml -e output_dir=$(ART_ITEST)

deploy: $(VENV_MARKER) $(COLLECTIONS_MARKER)
	@echo "--- Deploy (conditional) ---"
	@$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/deploy-observability-stack.yml

clean:
	@rm -rf $(VENV_DIR) $(COLLECTIONS_DIR) $(ART_TEST) $(ART_ITEST)
