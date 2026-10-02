:- module(test_between, [
    run_between_tests/0,
    run_between_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_between_case/4
]).

/** <module> Scryer Compatibility: Integers and Ranges (library(between))

Tests between/3 and numlist/3.
*/

:- use_module(library(format)).
:- use_module(library(between)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_b(X) :- between(1, 3, X).
test_num(L) :- numlist(1, 5, L).

test_between_case(between_gen, "between/3 range generation",
    ":- use_module(library(between)).\ntest_b(X) :- between(1, 3, X).",
    ["test_b(X)."]).

test_between_case(numlist_gen, "numlist/3 list generation",
    ":- use_module(library(between)).\ntest_num(L) :- numlist(1, 5, L).",
    ["test_num(L)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_between:test_between_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_between, OutFile),
    generate_scryer_out(OutFile).

run_between_tests(OutFile) :-
    format("~n--- Module Compatibility: library(between) ---~n", []),
    run_compat_tests_from_file(test_between:test_between_case, OutFile).
run_between_tests :-
    default_scryer_out_path(test_between, OutFile),
    run_between_tests(OutFile).
