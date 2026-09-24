# Makefile for Prolog Language Toolkit (prolog_toolkit)

PROLOG ?= PROLOG_TIMEOUT=60s nice scryer-safe

.PHONY: all test test-core test-scryer-lib clean help

all: test

help:
	@echo "Available targets:"
	@echo "  make test             Run core unit test suites"
	@echo "  make test-core        Run unit tests (lexer, parser, expander, loader)"
	@echo "  make test-scryer-lib  Parse all Scryer standard library files in reference/scryer-prolog/src/lib"

test: test-core

test-core:
	@echo "=== Running Core Toolkit Test Suite ==="
	$(PROLOG) tests/test_prolog_toolkit.pl
	$(PROLOG) tests/test_prolog_parser.pl
	$(PROLOG) tests/test_prolog_lexer.pl
	$(PROLOG) tests/test_prolog_expander.pl
	$(PROLOG) tests/test_module_loader.pl
	$(PROLOG) tests/test_scryer_lib.pl
	$(PROLOG) tests/test_term_io.pl
	$(PROLOG) tests/test_prolog_reactive_ast.pl
	$(PROLOG) tests/test_prolog_reactive_parser.pl
	$(PROLOG) tests/test_incremental_ast_patching.pl
	@echo "=== All Core Tests Passed ==="

test-scryer-lib:
	@echo "=== Testing Parsing Across Scryer Standard Library ==="
	PROLOG_TIMEOUT=300s PROLOG_MEMORY_MAX=2G $(PROLOG) tests/test_parse_all_scryer_lib.pl
