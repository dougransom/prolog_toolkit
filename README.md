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

4. **ISO-Compatible & Provenance-Annotated Term Reading**
   - Full ISO-compliant `read_term/N` (e.g. `read_term/2,3`) supporting standard read options (`variables/1`, `variable_names/1`, `singletons/1`, etc.).
   - Strict ISO error handling: Syntax and parsing errors throw ISO-standard `error(syntax_error(Detail), Context)` exception terms, embedding rich source and token provenance into `Context`.
   - `read_term_ex/N` extending standard reading with rich provenance and source origin metadata attached to terms, subterms, and variables via attributed variables:
     - **Token & Term Provenance**: Source spans, line/column offsets, and origin identifiers (file path, interactive toplevel, URL, or stream).
     - **Macro & Expansion Lineage**: When terms are generated through macro expansions (`term_expansion/2`, `goal_expansion/2`, DCG rules), metadata traces back to the original source term and locates the specific expansion rules/macros used.

5. **Crowlog: Source-Provenance Meta-Interpreter & Debugger**
   - Located in [`crowlog/`](crowlog): A pure, step-level meta-interpreter capable of executing user code and interpreted Scryer standard library modules (patched if necessary).
   - **Interactive Top-Level & Standard Term Representation**: An interactive REPL that adheres to pure, standard Prolog term representation for query answers and unhandled ISO error terms similar to Scryer Prolog.
   - **Library Search Paths**: Configurable via `CROWLOG_LIBRARY_PATH` (defaults to `reference/scryer-prolog/src/lib:crowlog/lib`) for `consult(library(...))` and `[library(...)]`.
   - **Execution Tracing & Step Debugging**: Inspect each reduction step, variable binding, choice point, and failure with line and column source spans attached directly to goals.
   - **Derivation Trees**: Construct explicit, visual proof trees / derivation DAGs linking each proof step to exact AST source positions.
   - **Host Engine Primitive Absorption & Environment Isolation**: The host Prolog engine absorbs only core ISO primitives (`=`, control constructs, `dif/2`, arithmetic, metalogical reflection, delimited control `reset`/`shift`, and pure reified `if_/3`). Host-loaded modules are **not** leaked to user code; standard libraries and user modules are parsed and interpreted in Crowlog's internal KB with full derivation trees.

## Test Runner Strategy & Test Suites

The test infrastructure is designed for high reliability, zero host contamination, and dynamic machine-adaptive execution timeouts.

### 1. Dynamic Timed Test Runner & Timeout Adaptation

All test targets in the [`Makefile`](file:///home/doug/code/prolog_toolkit/Makefile) are executed through the build system wrapper [`scripts/timed_test_runner.sh`](file:///home/doug/code/prolog_toolkit/scripts/timed_test_runner.sh):

- **Zero-Contamination Bare Launch**: All Prolog processes are started with `PROLOG ?= nice scryer-safe -f`, ensuring no ambient `~/.scryerrc` or host settings leak into tests.
- **Prolog-Native Timing Database**: Test durations are recorded into [`.test_timings.pl`](file:///home/doug/code/prolog_toolkit/.test_timings.pl) as valid ISO Prolog facts:
  ```prolog
  % Prolog Test Timings Database
  test_timing(tmin, 0.429, 1790777007).
  test_timing(test_core, 88.674, 1790777583).
  test_timing(test_crowlog, 14.884, 1790777598).
  test_timing(test_crowlog_toplevel, 20.174, 1790777619).
  test_timing(test_module_loader, 26.167, 1790777645).
  test_timing(test_iso_conformity, 1.376, 1790777646).
  test_timing(test_scryer_compat, 8.447, 1790777655).
  ```
- **Minimal Probe Baseline (`TMIN`)**: `make test-tmin` measures the minimal process startup and goal execution time (`$PROLOG -g halt`).
- **Adaptive Timeout Calculation**:
  - **First Run (Unseen Target)**: `Timeout = TMIN + TBUFFER` (where `TBUFFER` defaults to 90s in [`Makefile`](file:///home/doug/code/prolog_toolkit/Makefile), overridable via environment or command-line: `make test-all TBUFFER=120`).
  - **Subsequent Runs**: `Timeout = (LastElapsed * 1.20) + 5.0` with a safety floor of `max(Timeout, TMIN + TBUFFER)` to prevent false timeouts caused by load spikes, small test sample sizes (<= 5 tests), or machine variance.

---

### 2. Test Suites & Packages

The test suite is partitioned into targeted, layered verification targets:

| Target | Command | Description & Scope | Test File |
| :--- | :--- | :--- | :--- |
| **Core Suite** | `make test-core` | Consolidated unit tests in a single process: native lexer/clause tokenizer, parser, expander, AST isomorphism against Scryer across 6 standard library files, term I/O with rich provenance metadata, and incremental reactive AST patching. | [`tests/run_all_core_tests.pl`](file:///home/doug/code/prolog_toolkit/tests/run_all_core_tests.pl) |
| **Crowlog Engine** | `make test-crowlog` | Meta-interpreter reduction steps, derivation trees, cut handling, and delimited control (`reset`/`shift`), followed by interactive REPL transcript and answer formatting tests. | [`tests/crowlog/test_crowlog.pl`](file:///home/doug/code/prolog_toolkit/tests/crowlog/test_crowlog.pl), [`tests/crowlog/test_toplevel.pl`](file:///home/doug/code/prolog_toolkit/tests/crowlog/test_toplevel.pl) |
| **Module Loader** | `make test-module-loader` | Multi-file search path resolution, circular import prevention, module interface metadata extraction, and dynamic operator export propagation. | [`tests/test_module_loader.pl`](file:///home/doug/code/prolog_toolkit/tests/test_module_loader.pl) |
| **ISO Conformity** | `make test-iso-conformity` | 102 ISO standard conformity test cases imported from Scryer Prolog reference test suite. | [`tests/test_iso_conformity.pl`](file:///home/doug/code/prolog_toolkit/tests/test_iso_conformity.pl) |
| **Scryer Compatibility** | `make test-scryer-compat` | Validates that Crowlog reproduces identical answers, variable bindings, and operator scoping to Scryer across 4 tiers: (1) toplevel queries & `if_/3`, (2) core builtins & metalogical tests, (3) DCGs, and (4) CLP(Z) linear equations, inequality domains, and dynamic operator scoping before/after `use_module(library(clpz))`. | [`tests/scryer_compatibility/test_scryer_compat.pl`](file:///home/doug/code/prolog_toolkit/tests/scryer_compatibility/test_scryer_compat.pl) |
| **Full Library Parse** | `make test-scryer-lib` | Recursive parsing validation across all 50+ files in Scryer Prolog standard library (`reference/scryer-prolog/src/lib/`). | [`tests/test_parse_all_scryer_lib.pl`](file:///home/doug/code/prolog_toolkit/tests/test_parse_all_scryer_lib.pl) |
| **All Test Suites** | `make test-all` | Runs `test-core`, `test-crowlog`, `test-module-loader`, `test-iso-conformity`, and `test-scryer-compat` sequentially with dynamic timing. | [`Makefile`](file:///home/doug/code/prolog_toolkit/Makefile) |

---

### 3. Package Dependencies & Test Frameworks

- **[QUADS (Queries Using Answer Descriptions)](https://github.com/mthom/quads)**: Declared in [`bakage.toml`](file:///home/doug/code/prolog_toolkit/bakage.toml#L8-L11), QUADS enables transcript-driven specification and verification of Prolog toplevel interactions and error terms.
- **Pure ISO Test Scaffold**: Test assertions use pure reified conditionals (`if_/3`, `dif/2`) and standard ISO term I/O without procedural side-effects.

---

## Running Tests

```bash
# Run all core, Crowlog, module loader, ISO, and Scryer compatibility tests
make test-all

# Run individual test suites
make test-core
make test-crowlog
make test-module-loader
make test-iso-conformity
make test-scryer-compat

# Generate Scryer reference output (.scryer_out) intermediate files
make test-scryer-compat-generate

# Clean generated test outputs and cached timings (forces regeneration on next test run)
make clean

# Measure baseline minimal probe run time (TMIN)
make test-tmin

# Run with custom buffer (e.g. 120s on slower CI machines)
make test-all TBUFFER=120
```

---

## Documentation

- [Architecture & Design](file:///home/doug/code/prolog_toolkit/docs/architecture.md)
- [Scryer Test Parity & Approximation Guidelines](file:///home/doug/code/prolog_toolkit/docs/scryer_test_parity.md)
- [Scryer Reference Tracking](file:///home/doug/code/prolog_toolkit/docs/scryer_reference_tracking.md)



