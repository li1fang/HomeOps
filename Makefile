# Makefile for HomeOps - The Golden Path
# Gate0: setup | Gate1: lint/test | Gate2: itest | deploy (conditional)

SHELL := /bin/bash
.ONESHELL:
.SILENT:

VENV := .venv
PY := python3
PIP := $(VENV)/bin/pip

ANSIBLE_PLAYBOOK := $(VENV)/bin/ansible-playbook
ANSIBLE_LINT := $(VENV)/bin/ansible-lint
YAMLLINT := $(VENV)/bin/yamllint

INVENTORY := inventory/hosts.yaml
ART_TEST := artifacts/test
ART_ITEST := artifacts/itest

# Ensure venv binaries are on PATH for all commands invoked via make
export PATH := $(abspath $(VENV)/bin):$(PATH)

.PHONY: setup lint test itest deploy ensure-venv

ensure-venv:
	if [ ! -x "$(ANSIBLE_PLAYBOOK)" ]; then \
		echo "--- Bootstrapping Ansible toolchain into $(VENV) ---"; \
		$(PY) -m venv $(VENV) || (sudo apt-get update && sudo apt-get install -y python3-venv python3-pip && $(PY) -m venv $(VENV)); \
		$(PIP) install -U pip wheel >/dev/null; \
		$(PIP) install "ansible-core>=2.16" "ansible-lint>=24.0" "yamllint>=1.32"; \
	fi

setup: ensure-venv
	mkdir -p $(ART_TEST)
	$(ANSIBLE_PLAYBOOK) -i localhost, -c local playbooks/runner-prepare.yml -e artifacts_dir=$(ART_TEST)

lint: ensure-venv
	echo "--- Running ansible-lint / yamllint / syntax-check ---"
	$(ANSIBLE_LINT) || exit $$?
	$(YAMLLINT) .
	FILES="$$(find playbooks -type f -name "*.yml" 2>/dev/null)"; \
	if [ -n "$$FILES" ]; then \
		$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) --syntax-check $$FILES; \
	else \
		echo "No playbooks to syntax-check"; \
	fi

test: ensure-venv
	echo "--- Running check mode sanity (ping) ---"
	mkdir -p $(ART_TEST)
	if [ -f playbooks/ping.yml ]; then \
		$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/ping.yml --check --diff; \
	else \
		echo "No ping.yml; skipping"; \
	fi

itest: ensure-venv
	echo "--- Running integration verification ---"
	mkdir -p $(ART_ITEST)
	if [ -f playbooks/tests/verify_observability.yml ]; then \
		$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/tests/verify_observability.yml -e artifacts_dir=$(ART_ITEST); \
	else \
		echo "verify_observability.yml missing; skipping"; \
	fi

deploy: ensure-venv
	echo "--- Deploying Observability Stack ---"
	if [ -f playbooks/deploy-observability-stack.yml ]; then \
		$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/deploy-observability-stack.yml; \
	else \
		echo "deploy-observability-stack.yml missing"; exit 2; \
	fi
