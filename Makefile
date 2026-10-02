# Makefile for Prolog Language Toolkit (prolog_toolkit)

PROLOG ?= nice scryer-safe -f
TBUFFER ?= 120
TIMED_RUNNER ?= ./scripts/timed_test_runner.sh

BUILD_DIR ?= build
SCRYER_COMPAT_DIR ?= tests/scryer_compatibility
SCRYER_COMPAT_BUILD_DIR = $(BUILD_DIR)/scryer_compatibility

SCRYER_COMPAT_MODULES = \
	test_toplevel \
	test_builtins \
	test_dcgs \
	test_clpz \
	test_pairs \
	test_assoc \
	test_lists \
	test_si \
	test_between \
	test_format \
	test_ordsets \
	test_queues \
	test_reif \
	test_dif \
	test_charsio \
	test_lambda \
	test_freeze \
	test_gensym \
	test_terms \
	test_ugraphs \
	test_csv \
	test_random \
	test_iso_ext \
	test_time \
	test_crypto \
	test_uuid \
	test_error \
	test_clpb \
	test_files \
	test_os \
	test_pio \
	test_simplex \
	test_arithmetic \
	test_when \
	test_debug \
	test_cont \
	test_sgml \
	test_xpath \
	test_diag \
	test_atts

SCRYER_COMPAT_SRCS = $(patsubst %,$(SCRYER_COMPAT_DIR)/%.pl,$(SCRYER_COMPAT_MODULES))
SCRYER_COMPAT_OUTS = $(patsubst %,$(SCRYER_COMPAT_BUILD_DIR)/%.scryer_out,$(SCRYER_COMPAT_MODULES))

.PHONY: all test test-tmin test-core test-crowlog crowlog test-module-loader test-iso-conformity \
        test-scryer-compat scryer-test-parity test-scryer-compat-generate \
        test-scryer-toplevel test-scryer-builtins test-scryer-dcgs test-scryer-clpz \
        test-scryer-pairs test-scryer-assoc test-scryer-lists test-scryer-si \
        test-scryer-between test-scryer-format test-scryer-ordsets test-scryer-queues \
        test-scryer-reif test-scryer-dif test-scryer-charsio test-scryer-lambda \
        test-scryer-freeze test-scryer-gensym test-scryer-terms test-scryer-ugraphs \
        test-scryer-csv test-scryer-random test-scryer-iso-ext test-scryer-time \
        test-scryer-crypto test-scryer-uuid test-scryer-error test-scryer-clpb \
        test-scryer-files test-scryer-os test-scryer-pio test-scryer-simplex test-scryer-arithmetic test-scryer-when test-scryer-debug test-scryer-cont test-scryer-sgml test-scryer-xpath test-scryer-diag test-scryer-atts \
        test-all test-scryer-lib update-reference clean help

all: test

help:
	@echo "Available targets:"
	@echo "  make test                       Run consolidated core unit test suite"
	@echo "  make test-tmin                  Estimate minimal probe run time (TMIN)"
	@echo "  make test-core                  Run consolidated core tests in a single process"
	@echo "  make test-crowlog               Run Crowlog meta-interpreter & toplevel tests"
	@echo "  make crowlog                    Launch interactive Crowlog toplevel REPL"
	@echo "  make test-module-loader         Run module loader tests (standalone on-demand/pre-checkin)"
	@echo "  make test-iso-conformity        Run ISO conformity test suite (from reference/scryer-prolog)"
	@echo "  make test-scryer-compat         Run all Scryer Prolog compatibility & parity tests"
	@echo "  make scryer-test-parity         Alias for test-scryer-compat"
	@echo "  make test-scryer-<module>       Run compatibility test for individual module (e.g. test-scryer-assoc)"
	@echo "  make test-scryer-compat-generate Generate all Scryer reference outputs into $(SCRYER_COMPAT_BUILD_DIR)/"
	@echo "  make test-all                   Run core tests, Crowlog tests, module loader, ISO, and Scryer compat tests"
	@echo "  make test-scryer-lib            Parse all Scryer standard library files in reference/scryer-prolog/src/lib"
	@echo "  make update-reference           Pull latest Scryer reference submodule"
	@echo "  make clean                      Remove build directory, generated test outputs, and cached timings"

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

# Build directory creation
$(SCRYER_COMPAT_BUILD_DIR):
	mkdir -p $(SCRYER_COMPAT_BUILD_DIR)

# Pattern rule: generate .scryer_out by running Scryer Prolog natively on test file into build directory
$(SCRYER_COMPAT_BUILD_DIR)/%.scryer_out: $(SCRYER_COMPAT_DIR)/%.pl $(SCRYER_COMPAT_DIR)/compat_framework.pl | $(SCRYER_COMPAT_BUILD_DIR)
	@echo "--- Generating Scryer reference output: $< -> $@ ---"
	$(PROLOG) $< -g "$*:generate_scryer_out('$@')" -g "halt"

test-scryer-compat-generate: $(SCRYER_COMPAT_OUTS)

# Individual module test rules
test-scryer-toplevel: $(SCRYER_COMPAT_BUILD_DIR)/test_toplevel.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_toplevel $(PROLOG) $(SCRYER_COMPAT_DIR)/test_toplevel.pl -g "test_toplevel:run_toplevel_tests('$^')" -g "halt"

test-scryer-builtins: $(SCRYER_COMPAT_BUILD_DIR)/test_builtins.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_builtins $(PROLOG) $(SCRYER_COMPAT_DIR)/test_builtins.pl -g "test_builtins:run_builtins_tests('$^')" -g "halt"

test-scryer-dcgs: $(SCRYER_COMPAT_BUILD_DIR)/test_dcgs.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_dcgs $(PROLOG) $(SCRYER_COMPAT_DIR)/test_dcgs.pl -g "test_dcgs:run_dcg_tests('$^')" -g "halt"

test-scryer-clpz: $(SCRYER_COMPAT_BUILD_DIR)/test_clpz.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_clpz $(PROLOG) $(SCRYER_COMPAT_DIR)/test_clpz.pl -g "test_clpz:run_clpz_tests('$^')" -g "halt"

test-scryer-pairs: $(SCRYER_COMPAT_BUILD_DIR)/test_pairs.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_pairs $(PROLOG) $(SCRYER_COMPAT_DIR)/test_pairs.pl -g "test_pairs:run_pairs_tests('$^')" -g "halt"

test-scryer-assoc: $(SCRYER_COMPAT_BUILD_DIR)/test_assoc.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_assoc $(PROLOG) $(SCRYER_COMPAT_DIR)/test_assoc.pl -g "test_assoc:run_assoc_tests('$^')" -g "halt"

test-scryer-lists: $(SCRYER_COMPAT_BUILD_DIR)/test_lists.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_lists $(PROLOG) $(SCRYER_COMPAT_DIR)/test_lists.pl -g "test_lists:run_lists_tests('$^')" -g "halt"

test-scryer-si: $(SCRYER_COMPAT_BUILD_DIR)/test_si.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_si $(PROLOG) $(SCRYER_COMPAT_DIR)/test_si.pl -g "test_si:run_si_tests('$^')" -g "halt"

test-scryer-between: $(SCRYER_COMPAT_BUILD_DIR)/test_between.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_between $(PROLOG) $(SCRYER_COMPAT_DIR)/test_between.pl -g "test_between:run_between_tests('$^')" -g "halt"

test-scryer-format: $(SCRYER_COMPAT_BUILD_DIR)/test_format.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_format $(PROLOG) $(SCRYER_COMPAT_DIR)/test_format.pl -g "test_format:run_format_tests('$^')" -g "halt"

test-scryer-ordsets: $(SCRYER_COMPAT_BUILD_DIR)/test_ordsets.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_ordsets $(PROLOG) $(SCRYER_COMPAT_DIR)/test_ordsets.pl -g "test_ordsets:run_ordsets_tests('$^')" -g "halt"

test-scryer-queues: $(SCRYER_COMPAT_BUILD_DIR)/test_queues.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_queues $(PROLOG) $(SCRYER_COMPAT_DIR)/test_queues.pl -g "test_queues:run_queues_tests('$^')" -g "halt"

test-scryer-reif: $(SCRYER_COMPAT_BUILD_DIR)/test_reif.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_reif $(PROLOG) $(SCRYER_COMPAT_DIR)/test_reif.pl -g "test_reif:run_reif_tests('$^')" -g "halt"

test-scryer-dif: $(SCRYER_COMPAT_BUILD_DIR)/test_dif.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_dif $(PROLOG) $(SCRYER_COMPAT_DIR)/test_dif.pl -g "test_dif:run_dif_tests('$^')" -g "halt"

test-scryer-charsio: $(SCRYER_COMPAT_BUILD_DIR)/test_charsio.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_charsio $(PROLOG) $(SCRYER_COMPAT_DIR)/test_charsio.pl -g "test_charsio:run_charsio_tests('$^')" -g "halt"

test-scryer-lambda: $(SCRYER_COMPAT_BUILD_DIR)/test_lambda.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_lambda $(PROLOG) $(SCRYER_COMPAT_DIR)/test_lambda.pl -g "test_lambda:run_lambda_tests('$^')" -g "halt"

test-scryer-freeze: $(SCRYER_COMPAT_BUILD_DIR)/test_freeze.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_freeze $(PROLOG) $(SCRYER_COMPAT_DIR)/test_freeze.pl -g "test_freeze:run_freeze_tests('$^')" -g "halt"

test-scryer-gensym: $(SCRYER_COMPAT_BUILD_DIR)/test_gensym.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_gensym $(PROLOG) $(SCRYER_COMPAT_DIR)/test_gensym.pl -g "test_gensym:run_gensym_tests('$^')" -g "halt"

test-scryer-terms: $(SCRYER_COMPAT_BUILD_DIR)/test_terms.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_terms $(PROLOG) $(SCRYER_COMPAT_DIR)/test_terms.pl -g "test_terms:run_terms_tests('$^')" -g "halt"

test-scryer-ugraphs: $(SCRYER_COMPAT_BUILD_DIR)/test_ugraphs.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_ugraphs $(PROLOG) $(SCRYER_COMPAT_DIR)/test_ugraphs.pl -g "test_ugraphs:run_ugraphs_tests('$^')" -g "halt"

test-scryer-csv: $(SCRYER_COMPAT_BUILD_DIR)/test_csv.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_csv $(PROLOG) $(SCRYER_COMPAT_DIR)/test_csv.pl -g "test_csv:run_csv_tests('$^')" -g "halt"

test-scryer-random: $(SCRYER_COMPAT_BUILD_DIR)/test_random.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_random $(PROLOG) $(SCRYER_COMPAT_DIR)/test_random.pl -g "test_random:run_random_tests('$^')" -g "halt"

test-scryer-iso-ext: $(SCRYER_COMPAT_BUILD_DIR)/test_iso_ext.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_iso_ext $(PROLOG) $(SCRYER_COMPAT_DIR)/test_iso_ext.pl -g "test_iso_ext:run_iso_ext_tests('$^')" -g "halt"

test-scryer-time: $(SCRYER_COMPAT_BUILD_DIR)/test_time.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_time $(PROLOG) $(SCRYER_COMPAT_DIR)/test_time.pl -g "test_time:run_time_tests('$^')" -g "halt"

test-scryer-crypto: $(SCRYER_COMPAT_BUILD_DIR)/test_crypto.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_crypto $(PROLOG) $(SCRYER_COMPAT_DIR)/test_crypto.pl -g "test_crypto:run_crypto_tests('$^')" -g "halt"

test-scryer-uuid: $(SCRYER_COMPAT_BUILD_DIR)/test_uuid.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_uuid $(PROLOG) $(SCRYER_COMPAT_DIR)/test_uuid.pl -g "test_uuid:run_uuid_tests('$^')" -g "halt"

test-scryer-error: $(SCRYER_COMPAT_BUILD_DIR)/test_error.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_error $(PROLOG) $(SCRYER_COMPAT_DIR)/test_error.pl -g "test_error:run_error_tests('$^')" -g "halt"

test-scryer-clpb: $(SCRYER_COMPAT_BUILD_DIR)/test_clpb.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_clpb $(PROLOG) $(SCRYER_COMPAT_DIR)/test_clpb.pl -g "test_clpb:run_clpb_tests('$^')" -g "halt"

test-scryer-files: $(SCRYER_COMPAT_BUILD_DIR)/test_files.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_files $(PROLOG) $(SCRYER_COMPAT_DIR)/test_files.pl -g "test_files:run_files_tests('$^')" -g "halt"

test-scryer-os: $(SCRYER_COMPAT_BUILD_DIR)/test_os.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_os $(PROLOG) $(SCRYER_COMPAT_DIR)/test_os.pl -g "test_os:run_os_tests('$^')" -g "halt"

test-scryer-pio: $(SCRYER_COMPAT_BUILD_DIR)/test_pio.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_pio $(PROLOG) $(SCRYER_COMPAT_DIR)/test_pio.pl -g "test_pio:run_pio_tests('$^')" -g "halt"

test-scryer-simplex: $(SCRYER_COMPAT_BUILD_DIR)/test_simplex.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_simplex $(PROLOG) $(SCRYER_COMPAT_DIR)/test_simplex.pl -g "test_simplex:run_simplex_tests('$^')" -g "halt"

test-scryer-arithmetic: $(SCRYER_COMPAT_BUILD_DIR)/test_arithmetic.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_arithmetic $(PROLOG) $(SCRYER_COMPAT_DIR)/test_arithmetic.pl -g "test_arithmetic:run_arithmetic_tests('$^')" -g "halt"

test-scryer-when: $(SCRYER_COMPAT_BUILD_DIR)/test_when.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_when $(PROLOG) $(SCRYER_COMPAT_DIR)/test_when.pl -g "test_when:run_when_tests('$^')" -g "halt"

test-scryer-debug: $(SCRYER_COMPAT_BUILD_DIR)/test_debug.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_debug $(PROLOG) $(SCRYER_COMPAT_DIR)/test_debug.pl -g "test_debug:run_debug_tests('$^')" -g "halt"

test-scryer-cont: $(SCRYER_COMPAT_BUILD_DIR)/test_cont.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_cont $(PROLOG) $(SCRYER_COMPAT_DIR)/test_cont.pl -g "test_cont:run_cont_tests('$^')" -g "halt"

test-scryer-sgml: $(SCRYER_COMPAT_BUILD_DIR)/test_sgml.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_sgml $(PROLOG) $(SCRYER_COMPAT_DIR)/test_sgml.pl -g "test_sgml:run_sgml_tests('$^')" -g "halt"

test-scryer-xpath: $(SCRYER_COMPAT_BUILD_DIR)/test_xpath.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_xpath $(PROLOG) $(SCRYER_COMPAT_DIR)/test_xpath.pl -g "test_xpath:run_xpath_tests('$^')" -g "halt"

test-scryer-diag: $(SCRYER_COMPAT_BUILD_DIR)/test_diag.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_diag $(PROLOG) $(SCRYER_COMPAT_DIR)/test_diag.pl -g "test_diag:run_diag_tests('$^')" -g "halt"

test-scryer-atts: $(SCRYER_COMPAT_BUILD_DIR)/test_atts.scryer_out
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_atts $(PROLOG) $(SCRYER_COMPAT_DIR)/test_atts.pl -g "test_atts:run_atts_tests('$^')" -g "halt"

test-scryer-compat: \
	test-scryer-toplevel \
	test-scryer-builtins \
	test-scryer-dcgs \
	test-scryer-clpz \
	test-scryer-pairs \
	test-scryer-assoc \
	test-scryer-lists \
	test-scryer-si \
	test-scryer-between \
	test-scryer-format \
	test-scryer-ordsets \
	test-scryer-queues \
	test-scryer-reif \
	test-scryer-dif \
	test-scryer-charsio \
	test-scryer-lambda \
	test-scryer-freeze \
	test-scryer-gensym \
	test-scryer-terms \
	test-scryer-ugraphs \
	test-scryer-csv \
	test-scryer-random \
	test-scryer-iso-ext \
	test-scryer-time \
	test-scryer-crypto \
	test-scryer-uuid \
	test-scryer-error \
	test-scryer-clpb \
	test-scryer-files \
	test-scryer-os \
	test-scryer-pio \
	test-scryer-simplex \
	test-scryer-arithmetic \
	test-scryer-when \
	test-scryer-debug \
	test-scryer-cont \
	test-scryer-sgml \
	test-scryer-xpath \
	test-scryer-diag \
	test-scryer-atts
	@echo "=== All Scryer Compatibility & Parity Tests Passed ==="

scryer-test-parity: test-scryer-compat
scryer_test_parity: test-scryer-compat
test-scryer-parity: test-scryer-compat

clean:
	@echo "=== Cleaning Build Directory and Test Timings ==="
	rm -rf $(BUILD_DIR) tests/scryer_compatibility/*.scryer_out .test_timings.pl

update-reference:
	@echo "=== Updating Scryer Reference Submodule ==="
	git submodule update --remote --merge reference/scryer-prolog

test-all: test-core test-crowlog test-module-loader test-iso-conformity test-scryer-compat

test-scryer-lib:
	@echo "=== Testing Parsing Across Scryer Standard Library ==="
	TBUFFER=$(TBUFFER) $(TIMED_RUNNER) test_scryer_lib $(PROLOG) tests/test_parse_all_scryer_lib.pl
