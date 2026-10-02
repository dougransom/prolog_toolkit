:- module(test_when, [
    run_when_tests/0,
    run_when_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_when_case/4
]).

/** <module> Scryer Compatibility: Coroutining (library(when))

Tests when/2 with nonvar and ground conditions.
*/

:- use_module(library(when)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_when_nonvar(X, Y) :-
    when(nonvar(X), Y = bound),
    X = 42.

test_when_ground(A, B, Status) :-
    when((ground(A), ground(B)), Status = ready),
    A = first,
    B = second.

test_when_case(when_nonvar, "when/2 delays goal until variable is instantiated",
    ":- use_module(library(when)).\ntest_when_nonvar(X, Y) :-\n    when(nonvar(X), Y = bound),\n    X = 42.",
    ["test_when_nonvar(X, Y)."]).

test_when_case(when_ground, "when/2 delays goal until compound condition is ground",
    ":- use_module(library(when)).\ntest_when_ground(A, B, Status) :-\n    when((ground(A), ground(B)), Status = ready),\n    A = first,\n    B = second.",
    ["test_when_ground(A, B, S)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_when:test_when_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_when, OutFile),
    generate_scryer_out(OutFile).

run_when_tests(OutFile) :-
    format("~n--- Module Compatibility: library(when) ---~n", []),
    run_compat_tests_from_file(test_when:test_when_case, OutFile).
run_when_tests :-
    default_scryer_out_path(test_when, OutFile),
    run_when_tests(OutFile).
