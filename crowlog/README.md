# Crowlog: Source-Provenance Prolog Meta-Interpreter & REPL

Crowlog is an interactive toplevel and pure step-level meta-interpreter with source provenance, derivation tree inspection, on-demand backtracking, and decoupled I/O streams.

## Features

- **Standard Prolog Term Representation**: Clean homoiconic answers and ISO-standard error messages.
- **Source-Level Provenance & Derivation Trees**: Builds visual proof trees (`tree.` / `notree.`) linking reduction steps to exact line/column source spans.
- **Pure Reified & Control Interpretation**: Host-delegated arithmetic, metalogical tests, delimited control (`reset/3`, `shift/1`), and native reified `if_/3` without procedural cuts.
- **Modular Library Resolution**: Supports loading installed libraries and Scryer Prolog standard library modules via `consult(library(...))` or `[library(...)]`.

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
