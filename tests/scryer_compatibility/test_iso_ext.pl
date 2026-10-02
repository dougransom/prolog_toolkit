:- module(test_iso_ext, [
    run_iso_ext_tests/0,
    run_iso_ext_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_iso_ext_case/4
]).

/** <module> Scryer Compatibility: ISO Extensions (library(iso_ext))

Tests succ/2, blackboard global variables (bb_put/2, bb_get/2, bb_b_put/2), and copy_term_nat/2.
*/

:- use_module(library(format)).
:- use_module(library(iso_ext)).
:- use_module(compat_framework).

% Native Scryer predicates
test_succ_computation(I, S) :-
    succ(4, S),
    succ(I, 10).

test_bb_vars(Val1, Val2) :-
    bb_put(compat_key, "Initial"),
    bb_get(compat_key, Val1),
    bb_put(compat_key, "Updated"),
    bb_get(compat_key, Val2).

test_copy_nat(Source, Copy) :-
    Source = term(a, b, c),
    copy_term_nat(Source, Copy).

test_iso_ext_case(succ_modes, "succ/2 computes predecessor and successor integers",
    ":- use_module(library(iso_ext)).\ntest_succ_computation(I, S) :-\n    succ(4, S),\n    succ(I, 10).",
    ["test_succ_computation(I, S)."]).

test_iso_ext_case(blackboard_globals, "bb_put/2 and bb_get/2 store and retrieve terms",
    ":- use_module(library(iso_ext)).\ntest_bb_vars(Val1, Val2) :-\n    bb_put(compat_key, \"Initial\"),\n    bb_get(compat_key, Val1),\n    bb_put(compat_key, \"Updated\"),\n    bb_get(compat_key, Val2).",
    ["test_bb_vars(V1, V2)."]).

test_iso_ext_case(copy_nat, "copy_term_nat/2 deep-copies term",
    ":- use_module(library(iso_ext)).\ntest_copy_nat(Source, Copy) :-\n    Source = term(a, b, c),\n    copy_term_nat(Source, Copy).",
    ["test_copy_nat(S, C)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_iso_ext:test_iso_ext_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_iso_ext, OutFile),
    generate_scryer_out(OutFile).

run_iso_ext_tests(OutFile) :-
    format("~n--- Module Compatibility: library(iso_ext) ---~n", []),
    run_compat_tests_from_file(test_iso_ext:test_iso_ext_case, OutFile).
run_iso_ext_tests :-
    default_scryer_out_path(test_iso_ext, OutFile),
    run_iso_ext_tests(OutFile).
