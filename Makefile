.PHONY: build dist test lint install-local uninstall-local

VERSION ?= dev

build: ## Build the trustguard-claude-code hook binary into ./bin/
	@mkdir -p bin
	go build -buildvcs=false -trimpath -ldflags "-s -w" -o bin/trustguard-claude-code ./cli

dist: ## Cross-compile every release binary into ./dist/ (VERSION=X.Y.Z)
	@scripts/build-dist.sh $(VERSION)

test: ## Run the test suite
	go test -race ./cli/

lint: ## Vet the sources
	go vet ./cli/

# Install binary for local testing. Load the plugin with:
#   claude --plugin-dir ./trustguard
# or add the marketplace: /plugin marketplace add ./
install-local: build ## Install binary to ~/.trustguard/bin for local testing
	@mkdir -p "$(HOME)/.trustguard/bin"
	@cp bin/trustguard-claude-code "$(HOME)/.trustguard/bin/trustguard-claude-code"
	@chmod 0755 "$(HOME)/.trustguard/bin/trustguard-claude-code" trustguard/hooks/trustguard-hook.sh
	@echo "installed $(HOME)/.trustguard/bin/trustguard-claude-code"
	@echo "run: claude --plugin-dir $(CURDIR)/trustguard"
	@echo "or:  /plugin marketplace add $(CURDIR)  then install @neuraltrust/trustguard"
	@echo "config: ~/.trustguard/claude-code.json  (see README)"

uninstall-local: ## Remove the locally installed binary
	@rm -f "$(HOME)/.trustguard/bin/trustguard-claude-code"
	@echo "removed local trustguard-claude-code binary"
