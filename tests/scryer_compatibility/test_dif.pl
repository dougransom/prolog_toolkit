:- module(test_dif, [
    run_dif_tests/0,
    run_dif_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_dif_case/4
]).

/** <module> Scryer Compatibility: Inequality Constraint (library(dif))

Tests dif/2 with ground terms, variable unifications, and compound terms.
*/

:- use_module(library(format)).
:- use_module(library(dif)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_dif_ground :-
    dif(a, b),
    dif(1, 2),
    dif(foo(a), foo(b)).

test_dif_var_inst(X) :-
    dif(X, a),
    X = b.

test_dif_compound_var(X, Y) :-
    dif([X, 1], [2, Y]),
    X = 2,
    Y = 3.

test_dif_case(dif_ground, "dif/2 ground terms",
    ":- use_module(library(dif)).\ntest_dif_ground :-\n    dif(a, b),\n    dif(1, 2),\n    dif(foo(a), foo(b)).",
    ["test_dif_ground."]).

test_dif_case(dif_var_inst, "dif/2 variable constraint followed by valid instantiation",
    ":- use_module(library(dif)).\ntest_dif_var_inst(X) :-\n    dif(X, a),\n    X = b.",
    ["test_dif_var_inst(V)."]).

test_dif_case(dif_compound, "dif/2 compound term variables instantiated to distinct values",
    ":- use_module(library(dif)).\ntest_dif_compound_var(X, Y) :-\n    dif([X, 1], [2, Y]),\n    X = 2,\n    Y = 3.",
    ["test_dif_compound_var(A, B)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_dif:test_dif_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_dif, OutFile),
    generate_scryer_out(OutFile).

run_dif_tests(OutFile) :-
    format("~n--- Module Compatibility: library(dif) ---~n", []),
    run_compat_tests_from_file(test_dif:test_dif_case, OutFile).
run_dif_tests :-
    default_scryer_out_path(test_dif, OutFile),
    run_dif_tests(OutFile).
