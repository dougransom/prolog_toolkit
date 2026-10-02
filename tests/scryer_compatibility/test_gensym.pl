:- module(test_gensym, [
    run_gensym_tests/0,
    run_gensym_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_gensym_case/4
]).

/** <module> Scryer Compatibility: Unique Symbol Generation (library(gensym))

Tests gensym/2 and reset_gensym/1.
*/

:- use_module(library(format)).
:- use_module(library(gensym)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_gensym_seq(G1, G2, G3) :-
    reset_gensym(var),
    gensym(var, G1),
    gensym(var, G2),
    gensym(var, G3).

test_gensym_reset(Before, After) :-
    reset_gensym(test_sym),
    gensym(test_sym, Before),
    reset_gensym(test_sym),
    gensym(test_sym, After).

test_gensym_case(gensym_seq, "sequential symbol generation with gensym/2",
    ":- use_module(library(gensym)).\ntest_gensym_seq(G1, G2, G3) :-\n    reset_gensym(var),\n    gensym(var, G1),\n    gensym(var, G2),\n    gensym(var, G3).",
    ["test_gensym_seq(A, B, C)."]).

test_gensym_case(gensym_reset, "symbol counter reset with reset_gensym/1",
    ":- use_module(library(gensym)).\ntest_gensym_reset(Before, After) :-\n    reset_gensym(test_sym),\n    gensym(test_sym, Before),\n    reset_gensym(test_sym),\n    gensym(test_sym, After).",
    ["test_gensym_reset(X, Y)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_gensym:test_gensym_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_gensym, OutFile),
    generate_scryer_out(OutFile).

run_gensym_tests(OutFile) :-
    format("~n--- Module Compatibility: library(gensym) ---~n", []),
    run_compat_tests_from_file(test_gensym:test_gensym_case, OutFile).
run_gensym_tests :-
    default_scryer_out_path(test_gensym, OutFile),
    run_gensym_tests(OutFile).
