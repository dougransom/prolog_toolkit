# Prolog Language Toolkit (`prolog_toolkit`)

A pure, ISO-compliant lexical and syntactic analysis toolkit for the Prolog language in Scryer Prolog.

## Status & Architecture

- **`src/prolog_toolkit.pl`**: Core entry point module.
- **Dependency Roadmap (`parser_experiments`)**:
  > **Note**: The streaming lexical and syntactic pipeline from `parser_experiments` is currently referenced via direct relative file paths (`../../parser_experiments/src/parser_experiments`). Eventually, `parser_experiments` will be published and imported as a package via `bakage` (e.g. `:- use_module(pkg(parser_experiments)).`). Imports and manifests will be refactored at that time.

## Project Goals & Roadmap

1. **Full Scryer Program Parsing & Transitive Module Loading**
   - Parse entire multi-file Scryer Prolog programs starting from an entry point.
   - Configurable library search path resolution (supporting `--include-dir` or `register_search_path(library, Path)` pointing to Scryer's `src/lib`).
   - Automatically resolve `:- use_module(library(...))` and `:- include(...)` directives, importing exported operators, predicate interfaces, and expansion rules into the parse context.

2. **Toolkit-Native Macro & Goal Expansion**
   - Pure, engine-independent term and goal expansion engine.
   - Full ISO DCG rule translation (`Head --> Body` and pushback lists).
   - In-memory collection and evaluation of `term_expansion/2` and `goal_expansion/2` declared across loaded modules (such as `atts.pl`).
   - Optional host delegation (`expand_mode(host)`) when running natively in Scryer.

3. **Standard Library Verification Suite & Makefile**
   - Provide a standard `Makefile` with targets: `make test`, `make test-scryer-lib`.
   - Comprehensive test runner that recursively parses all `.pl` files in `reference/scryer-prolog/src/lib/` (50+ files), reporting per-file success, parse times, term counts, and syntax/operator issues.
   - Achieve 100% parse pass rate across the entire Scryer standard library.

## Running Tests

Run unit tests with `make` or directly with Scryer Prolog:

```bash
# Run core test suite
make test

# Run full Scryer standard library parsing test
make test-scryer-lib
```

Or invoke individual test suites:

```bash
scryer-prolog tests/test_prolog_toolkit.pl
scryer-prolog tests/test_prolog_parser.pl
scryer-prolog tests/test_prolog_lexer.pl
scryer-prolog tests/test_prolog_expander.pl
scryer-prolog tests/test_module_loader.pl
scryer-prolog tests/test_scryer_lib.pl
```

