:- module(test_prolog_lexer, [
    run_tests/0
]).

/** <module> Prolog Lexer Unit Tests Matching Scryer parse_tokens.rs & ISO

Tests Ported from Scryer Prolog reference:
  reference/scryer-prolog/src/tests/parse_tokens.rs
*/

:- use_module(library(charsio)).
:- use_module(library(dif)).
:- use_module(library(format)).
:- use_module(library(iso_ext), [maplist/3]).
:- use_module(library(reif)).
:- use_module('../src/prolog_token').
:- use_module('../../parser_experiments/src/annotate_position').
:- use_module('../src/prolog_lexer').
:- use_module('../src/prolog_streaming_lexer').
:- use_module(testing, [exit_test_process/0]).

run_tests :-
    format("Running lexer tests...~n", []),
    format("  1. test_scryer_parity...~n", []), test_scryer_parity, !,
    format("  2. test_radix_integers...~n", []), test_radix_integers, !,
    format("  3. test_floats...~n", []), test_floats, !,
    format("  4. test_open_vs_open_ct...~n", []), test_open_vs_open_ct, !,
    format("  5. test_dot_and_graphic_atoms...~n", []), test_dot_and_graphic_atoms, !,
    format("  6. test_strings...~n", []), test_strings, !,
    format("  7. test_comment_options...~n", []), test_comment_options, !,
    format("  8. test_nested_comments...~n", []), test_nested_comments, !,
    format("  9. test_lazy_streaming...~n", []), test_lazy_streaming, !,
    format("  10. test_source_spans...~n", []), test_source_spans, !,
    format("  11. test_dcg_interface...~n", []), test_dcg_interface, !,
    format("  12. test_unlifted_lexer...~n", []), test_unlifted_lexer, !,
    format("  13. test_lifted_lexer...~n", []), test_lifted_lexer, !,
    format("All lexer tests passed!~n", []),
    testing:exit_test_process.

% -------------------------------------------------------------------------
% 1. Scryer parse_tokens.rs Parity Tests
% -------------------------------------------------------------------------

test_scryer_parity :-
    format("    empty_multiline_comment...~n", []),
    tokenize([], "/**/ 4\n", [T1]),
    T1 = integer(4, _),

    format("    any_char_multiline_comment...~n", []),
    tokenize([], "/* █╗╚═══╝ © */ 4\n", [T2]),
    T2 = integer(4, _),

    format("    simple_char...~n", []),
    tokenize([], "'a'\n", [T3]),
    T3 = atom("a", _),

    format("    char_with_meta_seq M1...~n", []),
    tokenize([], "'\\\\'", [M1]),
    M1 = atom("\\", _),

    format("    char_with_meta_seq M2...~n", []),
    tokenize([], "'\\''", [M2]),
    M2 = atom("'", _),

    format("    char_with_meta_seq M3...~n", []),
    tokenize([], "'\\\"'", [M3]),
    M3 = atom("\"", _),

    format("    char_with_meta_seq M4...~n", []),
    tokenize([], "'\\`'", [M4]),
    M4 = atom("`", _),

    format("    char_with_control_seq...~n", []),
    tokenize([], "'\\a' '\\b' '\\r' '\\f' '\\t' '\\n' '\\v' ", [C1, C2, C3, C4, C5, C6, C7]),
    C1 = atom(['\a'], _),
    C2 = atom(['\b'], _),
    C3 = atom(['\r'], _),
    C4 = atom(['\f'], _),
    C5 = atom(['\t'], _),
    C6 = atom(['\n'], _),
    C7 = atom(['\v'], _),

    format("    char_with_octseq...~n", []),
    tokenize([], "'\\60433\\' ", [Oct1]),
    Oct1 = atom("愛", _),

    format("    char_with_octseq_0...~n", []),
    tokenize([], "'\\0\\' ", [Oct0]),
    Oct0 = atom([Char0], _),
    char_code(Char0, 0),

    format("    char_with_hexseq...~n", []),
    tokenize([], "'\\x2124\\' ", [Hex1]),
    Hex1 = atom("ℤ", _),

    format("    empty...~n", []),
    tokenize([], "", []),

    format("    comment_then_eof...~n", []),
    tokenize([], "% only a comment", []).

% -------------------------------------------------------------------------
% 2. Radix Integers
% -------------------------------------------------------------------------

test_radix_integers :-
    tokenize([], "0x1f 0X2A 0o77 0b1010 0'a 0'\\n", [H1, H2, O1, B1, C1, C2]),
    H1 = integer(31, _),
    H2 = integer(42, _),
    O1 = integer(63, _),
    B1 = integer(10, _),
    C1 = integer(97, _),
    C2 = integer(10, _).

% -------------------------------------------------------------------------
% 3. Floats
% -------------------------------------------------------------------------

test_floats :-
    tokenize([], "12.34 0.5 1.0e2 2.5E-1", [F1, F2, F3, F4]),
    F1 = float(12.34, _),
    F2 = float(0.5, _),
    F3 = float(100.0, _),
    F4 = float(0.25, _).

% -------------------------------------------------------------------------
% 4. Open vs. OpenCT
% -------------------------------------------------------------------------

test_open_vs_open_ct :-
    % foo(X) -> open_ct
    tokenize([], "foo(X)", [atom("foo", _), open_ct(_), var("X", _), close(_)]),

    % foo (X) -> open
    tokenize([], "foo (X)", [atom("foo", _), open(_), var("X", _), close(_)]),

    % (X) at start -> open
    tokenize([], "(X)", [open(_), var("X", _), close(_)]).

% -------------------------------------------------------------------------
% 5. Dot and Graphic Atoms
% -------------------------------------------------------------------------

test_dot_and_graphic_atoms :-
    % Full stop
    tokenize([], "foo. bar.", [atom("foo", _), end(_), atom("bar", _), end(_)]),

    % Clause tokens stops at end(_)
    clause_tokens([], Clause1, "parent(a, b). parent(c, d).", RestChars),
    Clause1 = [atom("parent", _), open_ct(_), atom("a", _), comma(_), atom("b", _), close(_), end(_)],
    dif(RestChars, []),

    % Graphic atoms
    tokenize([], ":- --> =.. ..", [atom(":-", _), atom("-->", _), atom("=..", _), atom("..", _)]).

% -------------------------------------------------------------------------
% 6. Strings
% -------------------------------------------------------------------------

test_strings :-
    format("    string S1...~n", []),
    tokenize([], "\"hello world\"", [S1]),
    S1 = string("hello world", _),

    format("    string S2...~n", []),
    tokenize([], "\"line\\nbreak\"", [S2]),
    S2 = string("line\nbreak", _),

    format("    string S3...~n", []),
    tokenize([], "\"\"\"quote\"\"\"", [S3]),
    S3 = string("\"quote\"", _).

% -------------------------------------------------------------------------
% 7. Comment Options
% -------------------------------------------------------------------------

test_comment_options :-
    tokenize([comments(Cs)], "% line 1\nfoo. /* block 1 */ bar.", [atom("foo", _), end(_), atom("bar", _), end(_)]),
    Cs = [comment(line, " line 1", _), comment(block, " block 1 ", _)].

% -------------------------------------------------------------------------
% 8. Nested Comments Extension
% -------------------------------------------------------------------------

test_nested_comments :-
    tokenize([comments_nesting(true)], "/* outer /* inner */ still outer */ 42.", [integer(42, _), end(_)]).

% -------------------------------------------------------------------------
% 9. Lazy Streaming
% -------------------------------------------------------------------------

test_lazy_streaming :-
    lazy_tokenize([], "a b c d e.", [T1, T2, T3|_]),
    T1 = atom("a", _),
    T2 = atom("b", _),
    T3 = atom("c", _).

% -------------------------------------------------------------------------
% 10. Source Spans & Coordinates
% -------------------------------------------------------------------------

test_source_spans :-
    tokenize([], "hello\n  world", [T1, T2]),
    token_span(T1, span(Pos1, Pos2)),
    pos_line(Pos1, 1),
    pos_col(Pos1, 1),
    pos_line(Pos2, 1),
    pos_col(Pos2, 6),
    token_span(T2, span(Pos3, Pos4)),
    pos_line(Pos3, 2),
    pos_col(Pos3, 3),
    pos_line(Pos4, 2),
    pos_col(Pos4, 8).

% -------------------------------------------------------------------------
% 11. DCG Public Interface
% -------------------------------------------------------------------------

test_dcg_interface :-
    % Full tokenization via phrase(tokens(Tokens), Chars)
    phrase(tokens(Toks1), "foo(X, 42)."),
    Toks1 = [atom("foo", _), open_ct(_), var("X", _), comma(_), integer(42, _), close(_), end(_)],

    % Full tokenization with options via phrase(tokens(Opts, Tokens), Chars)
    phrase(tokens([comments(Cs)], Toks2), "% greeting\nhello."),
    Cs = [comment(line, " greeting", _)],
    Toks2 = [atom("hello", _), end(_)],

    % Single token scanning via phrase(token(Token), CharsIn, CharsOut)
    phrase(token(Tok), "atom_one atom_two", Rest1),
    Tok = atom("atom_one", _),
    phrase(tokens(RemainingToks), Rest1),
    RemainingToks = [atom("atom_two", _)],

    % Clause-at-a-time via phrase(clause_tokens(Clause), CharsIn, CharsOut)
    phrase(clause_tokens(Clause1), "p(1). q(2).", Rest2),
    Clause1 = [atom("p", _), open_ct(_), integer(1, _), close(_), end(_)],
    phrase(clause_tokens(Clause2), Rest2),
    Clause2 = [atom("q", _), open_ct(_), integer(2, _), close(_), end(_)],

    % Lazy streaming via phrase(lazy_tokens(LazyToks), Chars)
    phrase(lazy_tokens(LazyToks), "first second third."),
    LazyToks = [T1, T2, T3|_],
    T1 = atom("first", _),
    T2 = atom("second", _),
    T3 = atom("third", _).

% -------------------------------------------------------------------------
% 12. Unlifted Lexer Tests (Pure Chars, No Spans)
% -------------------------------------------------------------------------

test_unlifted_lexer :-
    % Pure unlifted tokens on plain chars
    phrase(unlifted_tokens(Toks1), "foo(X, 42)."),
    Toks1 = [atom("foo"), open_ct, var("X"), comma, integer(42), close, end],

    % Unlifted with comments
    phrase(unlifted_tokens([comments(Cs)], Toks2), "% test\nbar."),
    Cs = [comment(line, " test")],
    Toks2 = [atom("bar"), end],

    % Unlifted clause tokens
    phrase(unlifted_clause_tokens(C1), "a(1). b(2).", Rest),
    C1 = [atom("a"), open_ct, integer(1), close, end],
    phrase(unlifted_clause_tokens(C2), Rest),
    C2 = [atom("b"), open_ct, integer(2), close, end],

    % Convenience wrapper unlifted_tokenize/2
    unlifted_tokenize("baz.", [atom("baz"), end]).

% -------------------------------------------------------------------------
% 13. Lifted Lexer Tests (Position-Annotated Stream via parser_experiments)
% -------------------------------------------------------------------------

test_lifted_lexer :-
    % Lifted tokens via parser_experiments stream_annotator and dcg_annotator:span
    phrase(lifted_tokens(Toks1), "foo(X, 42)."),
    Toks1 = [
        atom("foo", span(pos(1, 1, 0, _), pos(1, 4, 3, _))),
        open_ct(span(pos(1, 4, 3, _), pos(1, 5, 4, _))),
        var("X", span(pos(1, 5, 4, _), pos(1, 6, 5, _))),
        comma(span(pos(1, 6, 5, _), pos(1, 7, 6, _))),
        integer(42, span(pos(1, 8, 7, _), pos(1, 10, 9, _))),
        close(span(pos(1, 10, 9, _), pos(1, 11, 10, _))),
        end(span(pos(1, 11, 10, _), pos(1, 12, 11, _)))
    ],

    % Round-trip conversion between lifted and unlifted tokens
    unlift_token_list(Toks1, UnliftedList),
    UnliftedList = [atom("foo"), open_ct, var("X"), comma, integer(42), close, end],

    % Lifted clause tokens
    phrase(lifted_clause_tokens(Clause1), "parent(a). parent(b).", Rest),
    Clause1 = [atom("parent", _), open_ct(_), atom("a", _), close(_), end(_)],
    phrase(lifted_clause_tokens(Clause2), Rest),
    Clause2 = [atom("parent", _), open_ct(_), atom("b", _), close(_), end(_)].

unlift_token_list([], []).
unlift_token_list([L|Ls], [U|Us]) :-
    unlift_token(L, U),
    unlift_token_list(Ls, Us).

:- initialization(run_tests).
