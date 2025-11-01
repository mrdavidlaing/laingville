# Makefile for Laingville repository
# Provides canonical commands for formatting, linting, and testing bash scripts

.PHONY: all format lint test test-bash test-powershell check help

# Default target: run format, lint, then test
all: format lint test
	@echo "✅ All checks passed!"

# Format all scripts using centralized batch formatter
format:
	@echo "🎨 Formatting scripts..."
	@files_to_format=$$(find . -type f \( -name "*.sh" -o -name "*.bash" -o -name "*.ps1" \) \
		-not -path "./.git/*" \
		-not -path "./dotfiles/*/.*" \
		-not -path "./spec/fixtures/*" \
		2>/dev/null); \
	claude_scripts=$$(find ./dotfiles/mrdavidlaing/.claude/scripts -type f -name "*.bash" 2>/dev/null || true); \
	claude_wrappers=$$(find ./dotfiles/mrdavidlaing/.claude/wrappers -type f 2>/dev/null || true); \
	all_files="$$files_to_format $$claude_scripts $$claude_wrappers"; \
	if [ -n "$$all_files" ]; then \
		./scripts/format-files.sh --batch $$all_files; \
	else \
		echo "ℹ️  No files found to format"; \
	fi

# Lint all bash scripts using shellcheck, and PowerShell scripts if pwsh is available
lint:
	@echo "🔍 Linting bash scripts..."
	@./scripts/lint-bash.sh
	@if command -v pwsh >/dev/null 2>&1; then \
		echo "🔍 Linting PowerShell scripts..."; \
		pwsh -ExecutionPolicy Bypass -File scripts/lint-powershell.ps1; \
	else \
		echo "ℹ️  PowerShell not available. Skipping PowerShell linting"; \
	fi

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
	@files_to_check=$$(find . -type f \( -name "*.sh" -o -name "*.bash" -o -name "*.ps1" \) \
		-not -path "./.git/*" \
		-not -path "./dotfiles/*/.*" \
		-not -path "./spec/fixtures/*" \
		2>/dev/null); \
	claude_scripts=$$(find ./dotfiles/mrdavidlaing/.claude/scripts -type f -name "*.bash" 2>/dev/null || true); \
	claude_wrappers=$$(find ./dotfiles/mrdavidlaing/.claude/wrappers -type f 2>/dev/null || true); \
	all_files="$$files_to_check $$claude_scripts $$claude_wrappers"; \
	if [ -n "$$all_files" ]; then \
		./scripts/format-files.sh --check --batch $$all_files || exit 1; \
	else \
		echo "ℹ️  No files found to check"; \
	fi
	@$(MAKE) lint
	@$(MAKE) test

# Help target
help:
	@echo "Laingville Makefile - Available targets:"
	@echo ""
	@echo "  make              - Run format, lint, and test (default)"
	@echo "  make format       - Format all bash scripts with shfmt"
	@echo "  make lint         - Lint bash + PowerShell scripts (if pwsh available)"
	@echo "  make test         - Run all tests (bash + PowerShell)"
	@echo "  make test-bash    - Run bash tests with shellspec"
	@echo "  make test-powershell - Run PowerShell tests with Pester"
	@echo "  make check        - Check format and run lint/test without modifying files"
	@echo "  make help         - Show this help message"
	@echo ""
	@echo "Recommended workflow:"
	@echo "  1. make           (format, lint, and all tests)"
	@echo "  2. make test-bash (run only bash tests for faster iteration)"