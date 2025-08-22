# Makefile for Laingville repository
# Provides canonical commands for formatting, linting, and testing bash scripts

.PHONY: all format lint lint-powershell test check help

# Default target: run format, lint, then test
all: format lint test
	@echo "✅ All checks passed!"

# Format all bash scripts using shfmt (excluding ShellSpec tests)
format:
	@echo "🎨 Formatting bash scripts..."
	@if command -v shfmt >/dev/null 2>&1; then \
		find . -type f \( -name "*.sh" -o -name "*.bash" \) \
			-not -path "./.git/*" \
			-not -path "./dotfiles/*/.*" \
			-not -name "*_spec.sh" \
			-exec shfmt -w {} \; ; \
		echo "✅ Bash formatting complete"; \
	else \
		echo "⚠️  shfmt not found. Skipping bash formatting"; \
	fi
	@echo "🎨 Formatting ShellSpec tests..."
	@./scripts/format-shellspec.sh
	@echo "✅ All formatting complete"

# Lint all bash scripts using shellcheck
lint:
	@echo "🔍 Linting bash scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -type f \( -name "*.sh" -o -name "*.bash" \) \
			-not -path "./.git/*" \
			-not -path "./dotfiles/*/.*" \
			-exec shellcheck {} \; ; \
		shellcheck setup.sh setup-secrets; \
		echo "✅ Linting complete"; \
	else \
		echo "⚠️  shellcheck not found. Skipping linting"; \
		exit 1; \
	fi

# Lint all PowerShell scripts using PSScriptAnalyzer
lint-powershell:
	@pwsh -ExecutionPolicy Bypass -File scripts/lint-powershell.ps1

# Run all tests using shellspec
test:
	@echo "🧪 Running tests..."
	@if command -v shellspec >/dev/null 2>&1; then \
		shellspec; \
	else \
		echo "⚠️  shellspec not found. Skipping tests"; \
		exit 1; \
	fi

# Check without modifying (CI-friendly)
check:
	@echo "📋 Checking format..."
	@if command -v shfmt >/dev/null 2>&1; then \
		find . -type f \( -name "*.sh" -o -name "*.bash" \) \
			-not -path "./.git/*" \
			-not -path "./dotfiles/*/.*" \
			-exec shfmt -d {} \; ; \
	else \
		echo "⚠️  shfmt not found. Skipping format check"; \
	fi
	@$(MAKE) lint
	@$(MAKE) test

# Help target
help:
	@echo "Laingville Makefile - Available targets:"
	@echo ""
	@echo "  make              - Run format, lint, and test (default)"
	@echo "  make format       - Format all bash scripts with shfmt"
	@echo "  make lint         - Lint all bash scripts with shellcheck"
	@echo "  make lint-powershell - Lint all PowerShell scripts with PSScriptAnalyzer"
	@echo "  make test         - Run all tests with shellspec"
	@echo "  make check        - Check format and run lint/test without modifying files"
	@echo "  make help         - Show this help message"
	@echo ""
	@echo "Recommended workflow:"
	@echo "  1. make           (format, lint, and test)"