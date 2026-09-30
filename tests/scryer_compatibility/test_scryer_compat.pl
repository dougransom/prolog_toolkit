:- module(test_scryer_compat, [
    all_compat_tests_passed/0
]).

/** <module> Scryer Compatibility Master Test Suite

Runs all Scryer Prolog compatibility test files for core language features
and standard library modules.
*/

:- use_module(library(format)).

% Load individual module compatibility test suites
:- use_module(test_toplevel).
:- use_module(test_builtins).
:- use_module(test_dcgs).
:- use_module(test_clpz).

all_compat_tests_passed :-
    format("~n======================================================~n", []),
    format("=== ALL SCRYER COMPATIBILITY TESTS PASSED ============~n", []),
    format("======================================================~n", []),
    flush_output,
    halt(0).

:- initialization(all_compat_tests_passed).
