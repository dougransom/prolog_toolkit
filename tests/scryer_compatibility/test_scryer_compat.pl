:- module(test_scryer_compat, [
    run_all_scryer_compat_tests/0
]).

/** <module> Scryer Compatibility Master Test Suite

Runs all Scryer Prolog compatibility test files for core language features
and standard library modules against the generated Scryer outputs.
*/

:- use_module(library(format)).

:- use_module(test_toplevel).
:- use_module(test_builtins).
:- use_module(test_dcgs).
:- use_module(test_clpz).
:- use_module(test_pairs).
:- use_module(test_assoc).
:- use_module(test_lists).
:- use_module(test_si).
:- use_module(test_between).
:- use_module(test_format).

run_all_scryer_compat_tests :-
    run_toplevel_tests,
    run_builtins_tests,
    run_dcg_tests,
    run_clpz_tests,
    run_pairs_tests,
    run_assoc_tests,
    run_lists_tests,
    run_si_tests,
    run_between_tests,
    run_format_tests,
    format("~n======================================================~n", []),
    format("=== ALL SCRYER COMPATIBILITY TESTS PASSED ============~n", []),
    format("======================================================~n", []),
    flush_output,
    halt(0).
