# Scryer Prolog Reference Tracking

This document tracks reference files from [mthom/scryer-prolog](https://github.com/mthom/scryer-prolog) used to guide our ISO-compliant lexical analyzer, parser, and canonical term representation.

## Baseline Reference

- **Upstream Repository**: `https://github.com/mthom/scryer-prolog`
- **Tracked Baseline Commit**: `964977a761c7d6381f2cffb891e3dedec35991fa`
- **Submodule Target (Proposed)**: `reference/scryer-prolog` or `vendor/scryer-prolog`

## Monitored Files

| Scryer Source File | Purpose / Role | Toolkit Modules Affected |
| :--- | :--- | :--- |
| `src/parser/lexer.rs` | Token generation, escape sequences, number parsing, layout & comments, Open vs OpenCT | `lexer.pl`, `stream_annotator.pl` |
| `src/parser/parser.rs` | Operator precedence parsing, clauses, directives, expressions, syntax error handling | `parser.pl` |
| `src/parser/ast.rs` | Operator definitions, fixities, AST representations, Literals, Token enums | `token.pl`, `ast.pl` |
| `src/tests/parse_tokens.rs` | Unit tests for tokens, escape sequences, comments | `tests/test_lexer.pl` |

## Change Detection Protocol

When Scryer Prolog upstream is updated or pulled:
1. Run `git diff <old_hash> <new_hash> -- src/parser/ src/tests/parse_tokens.rs`.
2. Inspect any changes in token classification, escape sequence handling, operator rules, or edge cases.
3. Mirror corresponding test cases into `tests/test_lexer.pl` and update toolkit logic accordingly.
4. Record the update date, commit hash, and summary in this log.

## Update Log

- **2026-09-05**: Baseline established at commit `964977a761c7d6381f2cffb891e3dedec35991fa`.
