# Makefile for Laingville repository
# Provides canonical commands for formatting, linting, and testing bash scripts

.PHONY: all format lint lint-powershell test test-bash test-powershell check help

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
			-not -path "./spec/fixtures/*" \
			-not -name "*_spec.sh" \
			-exec shfmt -w {} \; ; \
		echo "🎨 Formatting mrdavidlaing's Claude scripts..."; \
		find ./dotfiles/mrdavidlaing/.claude/scripts -type f -name "*.bash" -exec shfmt -w {} \; 2>/dev/null || true; \
		find ./dotfiles/mrdavidlaing/.claude/wrappers -type f -exec shfmt -w {} \; 2>/dev/null || true; \
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
	@./scripts/lint-bash.sh

# Lint all PowerShell scripts using PSScriptAnalyzer
lint-powershell:
	@pwsh -ExecutionPolicy Bypass -File scripts/lint-powershell.ps1

# Run all tests (bash + PowerShell)
test: test-bash test-powershell
	@echo "✅ All tests completed!"

# Run bash tests using shellspec
test-bash:
	@echo "🧪 Running bash tests..."
	@if command -v shellspec >/dev/null 2>&1; then \
		shellspec; \
	else \
		echo "⚠️  shellspec not found. Skipping bash tests"; \
		exit 1; \
	fi

# Run PowerShell tests using Pester
test-powershell:
	@echo "🧪 Running PowerShell tests..."
	@if command -v pwsh >/dev/null 2>&1; then \
		if [ -f ".pester.ps1" ] && [ -d "spec/powershell" ]; then \
			pwsh -NoProfile -Command "Invoke-Pester -Path ./spec/powershell -Output Detailed"; \
		else \
			echo "ℹ️  No PowerShell tests found. Skipping PowerShell tests"; \
		fi; \
	else \
		echo "ℹ️  PowerShell not available. Skipping PowerShell tests"; \
	fi

# Check without modifying (CI-friendly)
check:
	@echo "📋 Checking format..."
	@if command -v shfmt >/dev/null 2>&1; then \
		find . -type f \( -name "*.sh" -o -name "*.bash" \) \
			-not -path "./.git/*" \
			-not -path "./dotfiles/*/.*" \
			-exec shfmt -d {} \; ; \
		echo "📋 Checking format of mrdavidlaing's Claude scripts..."; \
		find ./dotfiles/mrdavidlaing/.claude/scripts -type f -name "*.bash" -exec shfmt -d {} \; 2>/dev/null || true; \
		find ./dotfiles/mrdavidlaing/.claude/wrappers -type f -exec shfmt -d {} \; 2>/dev/null || true; \
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
	@echo "  make test         - Run all tests (bash + PowerShell)"
	@echo "  make test-bash    - Run bash tests with shellspec"
	@echo "  make test-powershell - Run PowerShell tests with Pester"
	@echo "  make check        - Check format and run lint/test without modifying files"
	@echo "  make help         - Show this help message"
	@echo ""
	@echo "Recommended workflow:"
	@echo "  1. make           (format, lint, and all tests)"
	@echo "  2. make test-bash (run only bash tests for faster iteration)"