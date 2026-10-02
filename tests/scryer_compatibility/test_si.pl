:- module(test_si, [
    run_si_tests/0,
    run_si_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_si_case/4
]).

/** <module> Scryer Compatibility: Sufficiently Instantiated Tests (library(si))

Tests atom_si/1, integer_si/1, list_si/1, chars_si/1 purity.
*/

:- use_module(library(format)).
:- use_module(library(si)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_si(A, I, L) :-
    atom_si(hello),
    integer_si(42),
    list_si([1, 2]),
    A = ok,
    I = ok,
    L = ok.

test_si_case(type_predicates, "atom_si/1, integer_si/1, list_si/1",
    ":- use_module(library(si)).\ntest_si(A, I, L) :-\n    atom_si(hello),\n    integer_si(42),\n    list_si([1, 2]),\n    A = ok,\n    I = ok,\n    L = ok.",
    ["test_si(A, I, L)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_si:test_si_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_si, OutFile),
    generate_scryer_out(OutFile).

run_si_tests(OutFile) :-
    format("~n--- Module Compatibility: library(si) ---~n", []),
    run_compat_tests_from_file(test_si:test_si_case, OutFile).
run_si_tests :-
    default_scryer_out_path(test_si, OutFile),
    run_si_tests(OutFile).
