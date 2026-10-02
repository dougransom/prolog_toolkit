:- module(test_simplex, [
    run_simplex_tests/0,
    run_simplex_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_simplex_case/4
]).

/** <module> Scryer Compatibility: Linear Programming / Simplex (library(simplex))

Tests gen_state/1, constraint/3, maximize/3, minimize/3, and variable_value/3.
*/

:- use_module(library(simplex)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_simplex_max(Vx, Vy) :-
    gen_state(S0),
    constraint([2*x, 1*y] =< 100, S0, S1),
    constraint([1*x, 1*y] =< 80, S1, S2),
    constraint([x] >= 0, S2, S3),
    constraint([y] >= 0, S3, S4),
    maximize([3*x, 2*y], S4, Sol),
    variable_value(Sol, x, Vx),
    variable_value(Sol, y, Vy).

test_simplex_min(Vx, Vy) :-
    gen_state(S0),
    constraint([1*x, 1*y] >= 10, S0, S1),
    constraint([2*x, 1*y] >= 14, S1, S2),
    constraint([x] >= 0, S2, S3),
    constraint([y] >= 0, S3, S4),
    minimize([3*x, 2*y], S4, Sol),
    variable_value(Sol, x, Vx),
    variable_value(Sol, y, Vy).

test_simplex_case(simplex_maximize, "maximize/3 finds optimal point for linear objective function",
    ":- use_module(library(simplex)).\ntest_simplex_max(Vx, Vy) :-\n    gen_state(S0),\n    constraint([2*x, 1*y] =< 100, S0, S1),\n    constraint([1*x, 1*y] =< 80, S1, S2),\n    constraint([x] >= 0, S2, S3),\n    constraint([y] >= 0, S3, S4),\n    maximize([3*x, 2*y], S4, Sol),\n    variable_value(Sol, x, Vx),\n    variable_value(Sol, y, Vy).",
    ["test_simplex_max(Vx, Vy)."]).

test_simplex_case(simplex_minimize, "minimize/3 finds minimal cost satisfying inequality constraints",
    ":- use_module(library(simplex)).\ntest_simplex_min(Vx, Vy) :-\n    gen_state(S0),\n    constraint([1*x, 1*y] >= 10, S0, S1),\n    constraint([2*x, 1*y] >= 14, S1, S2),\n    constraint([x] >= 0, S2, S3),\n    constraint([y] >= 0, S3, S4),\n    minimize([3*x, 2*y], S4, Sol),\n    variable_value(Sol, x, Vx),\n    variable_value(Sol, y, Vy).",
    ["test_simplex_min(Vx, Vy)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_simplex:test_simplex_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_simplex, OutFile),
    generate_scryer_out(OutFile).

run_simplex_tests(OutFile) :-
    format("~n--- Module Compatibility: library(simplex) ---~n", []),
    run_compat_tests_from_file(test_simplex:test_simplex_case, OutFile).
run_simplex_tests :-
    default_scryer_out_path(test_simplex, OutFile),
    run_simplex_tests(OutFile).
