:- module(test_format, [
    run_format_tests/0,
    run_format_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_format_case/4
]).

/** <module> Scryer Compatibility: String Formatting (library(format))

Tests format_//2, format_to_chars/3, format/2.
*/

:- use_module(library(format)).
:- use_module(library(dcgs)).
:- use_module(library(lists)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_fmt(Len, Chars) :-
    phrase(format_("Hello ~a, count is ~d!", [world, 42]), Chars),
    length(Chars, Len).

test_format_case(format_phrase, "format_//2 formatted output to character list",
    ":- use_module(library(format)).\n:- use_module(library(dcgs)).\n:- use_module(library(lists)).\ntest_fmt(Len, Chars) :-\n    phrase(format_(\"Hello ~a, count is ~d!\", [world, 42]), Chars),\n    length(Chars, Len).",
    ["test_fmt(L, C)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_format:test_format_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_format, OutFile),
    generate_scryer_out(OutFile).

run_format_tests(OutFile) :-
    format("~n--- Module Compatibility: library(format) ---~n", []),
    run_compat_tests_from_file(test_format:test_format_case, OutFile).
run_format_tests :-
    default_scryer_out_path(test_format, OutFile),
    run_format_tests(OutFile).
