# Makefile for Prolog Language Toolkit (prolog_toolkit)

PROLOG ?= nice scryer-safe -f
TBUFFER ?= 90
TIMED_RUNNER ?= ./scripts/timed_test_runner.sh

.PHONY: all test test-tmin test-core test-crowlog crowlog test-module-loader test-iso-conformity test-scryer-compat test-all test-scryer-lib update-reference clean help

all: test

help:
	@echo "Available targets:"
	@echo "  make test                 Run consolidated core unit test suite"
	@echo "  make test-tmin            Estimate minimal probe run time (TMIN)"
	@echo "  make test-core            Run consolidated core tests in a single process"
	@echo "  make test-crowlog         Run Crowlog meta-interpreter & toplevel tests"
	@echo "  make crowlog              Launch interactive Crowlog toplevel REPL"
	@echo "  make test-module-loader   Run module loader tests (standalone on-demand/pre-checkin)"
	@echo "  make test-iso-conformity  Run ISO conformity test suite (from reference/scryer-prolog)"
	@echo "  make test-scryer-compat   Run Scryer Prolog compatibility test suite"
	@echo "  make test-all             Run core tests, Crowlog tests, module loader, ISO, and Scryer compat tests"
	@echo "  make test-scryer-lib      Parse all Scryer standard library files in reference/scryer-prolog/src/lib"
	@echo "  make update-reference     Pull latest Scryer reference submodule"

test: test-core

test-tmin:
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) tmin $(PROLOG)

crowlog:
	$(PROLOG) crowlog/main.pl

test-crowlog:
	@echo "=== Running Crowlog Meta-Interpreter Tests ==="
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_crowlog $(PROLOG) tests/crowlog/test_crowlog.pl
	@echo "=== Running Crowlog Toplevel Tests ==="
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_crowlog_toplevel $(PROLOG) tests/crowlog/test_toplevel.pl
	@echo "=== All Crowlog Tests Passed ==="

test-core:
	@echo "=== Running Consolidated Core Toolkit Test Suite ==="
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_core $(PROLOG) tests/run_all_core_tests.pl
	@echo "=== All Consolidated Core Tests Passed ==="

test-module-loader:
	@echo "=== Running Module Loader Test Suite ==="
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_module_loader $(PROLOG) tests/test_module_loader.pl
	@echo "=== Module Loader Tests Passed ==="

test-iso-conformity:
	@echo "=== Running ISO Conformity Test Suite ==="
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_iso_conformity $(PROLOG) tests/test_iso_conformity.pl
	@echo "=== ISO Conformity Tests Passed ==="

test-scryer-compat:
	@echo "=== Running Scryer Compatibility Test Suite ==="
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_compat $(PROLOG) tests/scryer_compatibility/test_scryer_compat.pl
	@echo "=== Scryer Compatibility Tests Passed ==="

update-reference:
	@echo "=== Updating Scryer Reference Submodule ==="
	git submodule update --remote --merge reference/scryer-prolog

test-all: test-core test-crowlog test-module-loader test-iso-conformity test-scryer-compat

test-scryer-lib:
	@echo "=== Testing Parsing Across Scryer Standard Library ==="
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_lib $(PROLOG) tests/test_parse_all_scryer_lib.pl


