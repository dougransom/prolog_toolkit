# Prolog Language Toolkit (`prolog_toolkit`)

A pure, ISO-compliant lexical and syntactic analysis toolkit for the Prolog language in Scryer Prolog.

## Status & Architecture

- **`src/prolog_toolkit.pl`**: Core entry point module.
- **Dependency Roadmap (`parser_experiments`)**:
  > **Note**: The streaming lexical and syntactic pipeline from `parser_experiments` is currently referenced via direct relative file paths (`../../parser_experiments/src/parser_experiments`). Eventually, `parser_experiments` will be published and imported as a package via `bakage` (e.g. `:- use_module(pkg(parser_experiments)).`). Imports and manifests will be refactored at that time.

## Running Tests

Run unit tests with Scryer Prolog:

```bash
scryer-prolog tests/test_prolog_toolkit.pl
```
