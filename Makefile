INFRA_DIR := infra
STACK     := dev
DIST_DIR  := dist

.DEFAULT_GOAL := help

.PHONY: help \
        local-up local-down local-logs \
        remote-init remote-preview remote-up remote-down \
        tf-init tf-up tf-down \
        build install

help:
	@printf "%-20s %s\n" "Target" "Description"
	@printf "%-20s %s\n" "------" "-----------"
	@printf "%-20s %s\n" "local-up"       "Build and start the app via docker-compose (detached)"
	@printf "%-20s %s\n" "local-down"     "Stop and remove docker-compose containers"
	@printf "%-20s %s\n" "local-logs"     "Tail docker-compose logs"
	@printf "%-20s %s\n" "remote-init"    "Create the Pulumi stack (first-time setup)"
	@printf "%-20s %s\n" "remote-preview" "Preview Pulumi changes without applying"
	@printf "%-20s %s\n" "remote-up"      "Deploy / update the stack with Pulumi"
	@printf "%-20s %s\n" "remote-down"    "Destroy the Pulumi stack"
	@printf "%-20s %s\n" "install"        "Install Pulumi Python dependencies into infra/venv"
	@printf "%-20s %s\n" "build"          "Package app + deps into dist/lambda.zip for Lambda"
	@printf "%-20s %s\n" "tf-init"        "terraform init (first-time setup)"
	@printf "%-20s %s\n" "tf-plan"        "terraform plan"
	@printf "%-20s %s\n" "tf-up"          "Build and deploy serverless stack to AWS via Terraform"
	@printf "%-20s %s\n" "tf-down"        "Destroy the AWS Terraform stack"

# ── Local (docker-compose) ────────────────────────────────────────────────────

local-up:
	docker compose up --build -d

local-down:
	docker compose down

local-logs:
	docker compose logs -f

# ── Remote (Pulumi) ───────────────────────────────────────────────────────────

install:
	python3 -m venv $(INFRA_DIR)/venv
	$(INFRA_DIR)/venv/bin/pip install --quiet -r $(INFRA_DIR)/requirements.txt

remote-init: install
	cd $(INFRA_DIR) && pulumi stack init $(STACK)

remote-preview: install
	cd $(INFRA_DIR) && pulumi preview --stack $(STACK)

remote-up: install
	@if [ -n "$$(docker compose ps -q 2>/dev/null)" ]; then \
		echo "error: local stack is running — run 'make local-down' first"; \
		exit 1; \
	fi
	cd $(INFRA_DIR) && pulumi up --stack $(STACK)

remote-down: install
	cd $(INFRA_DIR) && pulumi destroy --stack $(STACK)

# ── Lambda build ─────────────────────────────────────────────────────────────

build:
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)/package
	pip3 install -r requirements.txt -t $(DIST_DIR)/package --quiet
	cp app.py lambda_handler.py $(DIST_DIR)/package/
	cd $(DIST_DIR)/package && zip -r ../lambda.zip . -x "*.pyc" -x "*__pycache__*" > /dev/null
	@echo "Built $(DIST_DIR)/lambda.zip"

# ── Terraform (AWS serverless) ────────────────────────────────────────────────

TF_DIR := terraform

tf-init:
	terraform -chdir=$(TF_DIR) init

tf-plan: build
	terraform -chdir=$(TF_DIR) plan

tf-up: build
	terraform -chdir=$(TF_DIR) apply -auto-approve

tf-down:
	terraform -chdir=$(TF_DIR) destroy -auto-approve
