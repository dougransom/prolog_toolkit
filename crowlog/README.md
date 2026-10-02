# Crowlog: Source-Provenance Prolog Meta-Interpreter & REPL

Crowlog is an interactive toplevel and pure step-level meta-interpreter with source provenance, derivation tree inspection, on-demand backtracking, and decoupled I/O streams.

## Primary Goal: Full Scryer Prolog Program Compatibility

It is an explicit design goal for Crowlog that **it should be able to interpret the same programs as Scryer Prolog**:
- Any valid ISO / Scryer Prolog source code (including modules, directives, DCGs, reified conditionals, term/goal expansions, and library predicates) should run identically under Crowlog.
- Standard libraries from Scryer Prolog (such as `library(lists)`, `library(reif)`, `library(pairs)`, `library(assoc)`, `library(si)`, etc.) can be loaded and executed directly by Crowlog via `consult(library(...))` or `[library(...)]`.
- Query answers, variable binding displays (e.g. `X = [Y]`), and error terms follow ISO and Scryer Prolog standards.

## Features

- **Standard Prolog Term Representation**: Clean homoiconic answers and ISO-standard error messages.
- **Source-Level Provenance & Derivation Trees**: Builds visual proof trees (`tree.` / `notree.`) linking reduction steps to exact line/column source spans.
- **Pure Reified & Control Interpretation**: Host-delegated arithmetic, metalogical tests, delimited control (`reset/3`, `shift/1`), and native reified `if_/3` without procedural cuts.
- **Modular Library Resolution**: Supports loading installed libraries and Scryer Prolog standard library modules via `consult(library(...))` or `[library(...)]`.

## Host Absorption vs. Interpreted Module Isolation

Crowlog strictly distinguishes between modules loaded by the host engine to implement Crowlog and modules available to interpreted user programs:

- **Host-Absorbed Primitives Only**: The host Prolog engine absorbs only a well-defined minimal set of primitives required for core execution, arithmetic, metalogical reflection, and pure control.
- **Environment Isolation**: Modules loaded by the host (e.g. `library(charsio)`, `library(os)`, `library(files)`) are **not** implicitly exposed to interpreted programs.
- **Interpreted Library Loading**: Interpreted programs must explicitly consult library modules (e.g. `consult(library(lists))` or `consult(library(reif))`), which are parsed and interpreted directly inside Crowlog's in-memory Knowledge Base (KB), retaining full source provenance and derivation tree tracking.

### Explicit Inventory of Host-Absorbed Built-ins

| Category | Absorbed Host Primitives |
| :--- | :--- |
| **Control & Logic** | `=`, `\=`, `==`, `\==`, `dif/2`, `true/0`, `fail/0`, `false/0`, `,/2`, `;/2`, `!/0`, `->/2`, `*->/2`, `\+/1`, `call/1..N` |
| **Pure Conditionals** | `if_/3` (core conditional dispatch) |
| **Arithmetic** | `is/2`, `</2`, `>/2`, `=</2`, `>=/2`, `=:=/2`, `=\=/2` |
| **Term Inspection & Metalogical** | `var/1`, `nonvar/1`, `atom/1`, `integer/1`, `float/1`, `compound/1`, `atomic/1`, `functor/3`, `arg/3`, `=../2`, `atom_chars/2`, `number_chars/2` |
| **Delimited Control** | `reset/3`, `shift/1` (via `library(cont)`) |

All other predicates and modules (e.g. `pairs`, `assoc`, `lists`, `ordsets`, custom reified library predicates) are intended to be loaded into Crowlog and executed through the interpreter or compiler.

## Extensible Host Substrate & Compiler Bootstrapping Architecture

Crowlog is designed around a **Declarative Substrate Boundary** that facilitates both meta-interpretation and full compiler code generation:

1. **Declarative Substrate Contract**:
   A backend or target environment specifies which primitives it absorbs (e.g., unification, memory allocation, and basic I/O) versus which predicates are compiled or interpreted.

2. **Abstract Form Emission (IR / WAM / Target Bytecode)**:
   Crowlog's parser and frontend produce a high-fidelity AST. A compiler backend can translate this AST into an abstract form (e.g., WAM instructions, Python AST/bytecode, WebAssembly, or JavaScript).

3. **Self-Bootstrapping**:
   A compiler writer targeting a new platform (e.g., Python, JVM, Node.js, WASM) only needs to:
   - Declare their target's minimal host hooks (the absorbed substrate).
   - Implement an executor for the emitted abstract form.
   - Run the compiled Crowlog core and standard libraries (`lists`, `assoc`, `dcgs`, `reif`, etc.) on top of that substrate to achieve a complete, running Prolog system.

## Environment Variables & Library Search Paths

Crowlog uses the `CROWLOG_LIBRARY_PATH` environment variable to locate libraries when consulting modules (e.g. `consult(library(lists))` or `[library(sample_lib)]`):

```bash
export CROWLOG_LIBRARY_PATH="path/to/custom_lib:path/to/other_lib"
```

If `CROWLOG_LIBRARY_PATH` is not set, Crowlog defaults to:
1. `reference/scryer-prolog/src/lib` (the ISO-compliant Scryer Prolog standard library source in the reference submodule)
2. `crowlog/lib` (Crowlog's local library folder)

## Toplevel Commands

| Command | Description |
| :--- | :--- |
| `consult('file.pl').` or `['file.pl'].` | Load clauses from a local file into the KB |
| `consult(library(lib)).` or `[library(lib)].` | Load clauses from `CROWLOG_LIBRARY_PATH` |
| `listing.` | List all loaded clauses in the KB with source spans |
| `listing(pred).` or `listing(pred/N).` | List clauses for a specific predicate |
| `tree.` / `notree.` | Enable / disable derivation proof tree display |
| `trace.` / `notrace.` | Enable / disable step execution tracing |
| `help.` | Display the built-in help message and environment variables |
| `halt.` | Exit the Crowlog REPL |

## Running Crowlog

Launch the interactive REPL:

```bash
./bin/crowlog
```

Or pass files to consult directly:

```bash
./bin/crowlog tests/fixtures/sample.pl
```
