:- module(test_charsio, [
    run_charsio_tests/0,
    run_charsio_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_charsio_case/4
]).

/** <module> Scryer Compatibility: Chars I/O (library(charsio))

Tests read_from_chars/2, write_term_to_chars/3, char_type/2,
chars_utf8bytes/2, and chars_base64/3.
*/

:- use_module(library(format)).
:- use_module(library(charsio)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_read_write(Term, Chars) :-
    read_from_chars("foo(1, 2).", Term),
    write_term_to_chars(bar(x, y), [], Chars).

test_char_props(IsAlpha, IsDigit) :-
    char_type('a', alphabetic),
    char_type('5', decimal_digit),
    IsAlpha = yes,
    IsDigit = yes.

test_encoding(Bytes, Encoded) :-
    chars_utf8bytes("hello", Bytes),
    chars_base64("hello", Encoded, []).

test_charsio_case(charsio_read_write, "read_from_chars/2 and write_term_to_chars/3",
    ":- use_module(library(charsio)).\ntest_read_write(Term, Chars) :-\n    read_from_chars(\"foo(1, 2).\", Term),\n    write_term_to_chars(bar(x, y), [], Chars).",
    ["test_read_write(T, C)."]).

test_charsio_case(charsio_char_props, "char_type/2 queries",
    ":- use_module(library(charsio)).\ntest_char_props(IsAlpha, IsDigit) :-\n    char_type('a', alphabetic),\n    char_type('5', decimal_digit),\n    IsAlpha = yes,\n    IsDigit = yes.",
    ["test_char_props(A, D)."]).

test_charsio_case(charsio_encodings, "chars_utf8bytes/2 and chars_base64/3",
    ":- use_module(library(charsio)).\ntest_encoding(Bytes, Encoded) :-\n    chars_utf8bytes(\"hello\", Bytes),\n    chars_base64(\"hello\", Encoded, []).",
    ["test_encoding(B, E)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_charsio:test_charsio_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_charsio, OutFile),
    generate_scryer_out(OutFile).

run_charsio_tests(OutFile) :-
    format("~n--- Module Compatibility: library(charsio) ---~n", []),
    run_compat_tests_from_file(test_charsio:test_charsio_case, OutFile).
run_charsio_tests :-
    default_scryer_out_path(test_charsio, OutFile),
    run_charsio_tests(OutFile).
