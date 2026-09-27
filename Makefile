# Makefile for Prolog Language Toolkit (prolog_toolkit)

PROLOG ?= nice scryer-safe -f

.PHONY: all test test-core test-crowlog crowlog test-module-loader test-all test-scryer-lib clean help

all: test

help:
	@echo "Available targets:"
	@echo "  make test                Run consolidated core unit test suite"
	@echo "  make test-core           Run consolidated core tests in a single process"
	@echo "  make test-crowlog        Run Crowlog meta-interpreter & toplevel tests"
	@echo "  make crowlog             Launch interactive Crowlog toplevel REPL"
	@echo "  make test-module-loader  Run module loader tests (standalone on-demand/pre-checkin)"
	@echo "  make test-all            Run consolidated core tests and module loader"
	@echo "  make test-scryer-lib     Parse all Scryer standard library files in reference/scryer-prolog/src/lib"

test: test-core

crowlog:
	$(PROLOG) crowlog/main.pl

test-crowlog:
	@echo "=== Running Crowlog Meta-Interpreter Tests ==="
	PROLOG_TIMEOUT=60s PROLOG_MEMORY_MAX=1G $(PROLOG) tests/crowlog/test_crowlog.pl
	@echo "=== Running Crowlog Toplevel Tests ==="
	PROLOG_TIMEOUT=60s PROLOG_MEMORY_MAX=1G $(PROLOG) tests/crowlog/test_toplevel.pl
	@echo "=== All Crowlog Tests Passed ==="

test-core:
	@echo "=== Running Consolidated Core Toolkit Test Suite ==="
	PROLOG_TIMEOUT=180s PROLOG_MEMORY_MAX=2G $(PROLOG) tests/run_all_core_tests.pl
	@echo "=== All Consolidated Core Tests Passed ==="

test-module-loader:
	@echo "=== Running Module Loader Test Suite ==="
	PROLOG_TIMEOUT=120s PROLOG_MEMORY_MAX=2G $(PROLOG) tests/test_module_loader.pl
	@echo "=== Module Loader Tests Passed ==="

test-all: test-core test-module-loader

test-scryer-lib:
	@echo "=== Testing Parsing Across Scryer Standard Library ==="
	PROLOG_TIMEOUT=300s PROLOG_MEMORY_MAX=2G $(PROLOG) tests/test_parse_all_scryer_lib.pl

