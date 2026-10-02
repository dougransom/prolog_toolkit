:- module(test_debug, [
    run_debug_tests/0,
    run_debug_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_debug_case/4
]).

/** <module> Scryer Compatibility: Declarative Debugging (library(debug))

Tests (*)/1 to generalize away / disable goals declaratively.
*/

:- use_module(library(debug)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_debug_generalize(X, Y) :-
    X = 10,
    *(X = 99),
    *(Y = 999),
    Y = 20.

test_debug_case(debug_star, "(*)/1 generalizes away subgoals without altering logical solutions",
    ":- use_module(library(debug)).\ntest_debug_generalize(X, Y) :-\n    X = 10,\n    *(X = 99),\n    *(Y = 999),\n    Y = 20.",
    ["test_debug_generalize(X, Y)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_debug:test_debug_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_debug, OutFile),
    generate_scryer_out(OutFile).

run_debug_tests(OutFile) :-
    format("~n--- Module Compatibility: library(debug) ---~n", []),
    run_compat_tests_from_file(test_debug:test_debug_case, OutFile).
run_debug_tests :-
    default_scryer_out_path(test_debug, OutFile),
    run_debug_tests(OutFile).
