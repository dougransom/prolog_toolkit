# Scryer Test Parity Rule

Whenever implementing, refactoring, or auditing lexical analysis or parsing features in this toolkit:

1. **Reference Scryer Upstream**: Check the reference submodule at `reference/scryer-prolog/src/tests/parse_tokens.rs` and `reference/scryer-prolog/src/parser/lexer.rs`.
2. **Keep Tests Synchronized**: When any new test cases, edge cases, or bug fixes are introduced upstream in `parse_tokens.rs`, immediately port or verify them in `tests/test_lexer.pl`.
3. **Tracking Log**: Maintain the commit baseline and notes in `docs/scryer_reference_tracking.md`.
4. **Safety & Purity**: Ensure all ported tests pass with Scryer Prolog using `library(reif)` purity, `chars` strings, and no impure cuts where `if_/3` or pure DCGs apply.
