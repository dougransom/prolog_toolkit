:- module(test_pio, [
    run_pio_tests/0,
    run_pio_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_pio_case/4
]).

/** <module> Scryer Compatibility: Pure I/O (library(pio))

Tests phrase_to_file/2 and phrase_from_file/2 with DCG descriptions.
*/

:- use_module(library(pio)).
:- use_module(library(dcgs)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_write_and_read_file(Content) :-
    phrase_to_file(format_("Pure Prolog IO: ~d~n", [100]), "build/scryer_compatibility/pio_test.txt"),
    phrase_from_file(seq(Content), "build/scryer_compatibility/pio_test.txt").

test_pio_case(phrase_to_from_file, "phrase_to_file/2 and phrase_from_file/2 roundtrip with DCG",
    ":- use_module(library(pio)).\n:- use_module(library(dcgs)).\n:- use_module(library(format)).\ntest_write_and_read_file(Content) :-\n    phrase_to_file(format_(\"Pure Prolog IO: ~d~n\", [100]), \"build/scryer_compatibility/pio_test.txt\"),\n    phrase_from_file(seq(Content), \"build/scryer_compatibility/pio_test.txt\").",
    ["test_write_and_read_file(C)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_pio:test_pio_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_pio, OutFile),
    generate_scryer_out(OutFile).

run_pio_tests(OutFile) :-
    format("~n--- Module Compatibility: library(pio) ---~n", []),
    run_compat_tests_from_file(test_pio:test_pio_case, OutFile).
run_pio_tests :-
    default_scryer_out_path(test_pio, OutFile),
    run_pio_tests(OutFile).
