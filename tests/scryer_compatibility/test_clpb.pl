:- module(test_clpb, [
    run_clpb_tests/0,
    run_clpb_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_clpb_case/4
]).

/** <module> Scryer Compatibility: Boolean Constraint Logic Programming (library(clpb))

Tests sat/1, taut/2, and sat_count/2.
*/

:- use_module(library(clpb)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_tautologies(T1, T2) :-
    taut(X =:= X, T1),
    taut(X * ~X, T2).

test_boolean_sat_count(Count) :-
    sat_count(_A + _B, Count).

test_clpb_case(clpb_taut, "taut/2 evaluates valid boolean tautologies and contradictions",
    ":- use_module(library(clpb)).\ntest_tautologies(T1, T2) :-\n    taut(X =:= X, T1),\n    taut(X * ~X, T2).",
    ["test_tautologies(T1, T2)."]).

test_clpb_case(clpb_sat_count, "sat_count/2 counts satisfying assignments for disjunction",
    ":- use_module(library(clpb)).\ntest_boolean_sat_count(Count) :-\n    sat_count(A + B, Count).",
    ["test_boolean_sat_count(C)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_clpb:test_clpb_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_clpb, OutFile),
    generate_scryer_out(OutFile).

run_clpb_tests(OutFile) :-
    format("~n--- Module Compatibility: library(clpb) ---~n", []),
    run_compat_tests_from_file(test_clpb:test_clpb_case, OutFile).
run_clpb_tests :-
    default_scryer_out_path(test_clpb, OutFile),
    run_clpb_tests(OutFile).
