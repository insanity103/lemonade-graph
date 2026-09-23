# Headless test suite (Lune; no Roblox Studio). See tests/README.md.
.PHONY: test test-quick test-strict lune

test: ## full suite, the sizes CI runs
	tests/run.sh

test-quick: ## sample sizes x0.1
	tests/run.sh --quick

test-strict: ## known game defects fail the run too
	tests/run.sh --strict

lune: ## install the pinned Lune to ~/.local/bin
	tools/install_lune.sh
