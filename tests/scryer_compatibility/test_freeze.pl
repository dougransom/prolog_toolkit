:- module(test_freeze, [
    run_freeze_tests/0,
    run_freeze_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_freeze_case/4
]).

/** <module> Scryer Compatibility: Delayed Execution (library(freeze))

Tests freeze/2 delayed goal invocation on variable instantiation.
*/

:- use_module(library(format)).
:- use_module(library(freeze)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_freeze_bind(X, Y) :-
    freeze(X, Y = bound),
    X = 42.

test_freeze_arith(X, Result) :-
    freeze(X, Result is X * 2),
    X = 10.

test_freeze_case(freeze_bind, "freeze/2 goal runs on variable binding",
    ":- use_module(library(freeze)).\ntest_freeze_bind(X, Y) :-\n    freeze(X, Y = bound),\n    X = 42.",
    ["test_freeze_bind(X, Y)."]).

test_freeze_case(freeze_arith, "freeze/2 arithmetic evaluation on binding",
    ":- use_module(library(freeze)).\ntest_freeze_arith(X, Result) :-\n    freeze(X, Result is X * 2),\n    X = 10.",
    ["test_freeze_arith(X, R)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_freeze:test_freeze_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_freeze, OutFile),
    generate_scryer_out(OutFile).

run_freeze_tests(OutFile) :-
    format("~n--- Module Compatibility: library(freeze) ---~n", []),
    run_compat_tests_from_file(test_freeze:test_freeze_case, OutFile).
run_freeze_tests :-
    default_scryer_out_path(test_freeze, OutFile),
    run_freeze_tests(OutFile).
