:- module(test_reif, [
    run_reif_tests/0,
    run_reif_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_reif_case/4
]).

/** <module> Scryer Compatibility: Reification (library(reif))

Tests if_/3, (=)/3, dif/3, memberd_t/3, tfilter/3, and tpartition/4.
*/

:- use_module(library(format)).
:- use_module(library(reif)).
:- use_module(library(dif)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_reif_if(Branch1, Branch2) :-
    if_(=(a, a), Branch1 = match, Branch1 = mismatch),
    if_(=(a, b), Branch2 = match, Branch2 = mismatch).

test_reif_filter_partition(Filtered, As, NonAs) :-
    tfilter(=(a), [a, b, a, c, a], Filtered),
    tpartition(=(a), [a, b, a, c, a], As, NonAs).

test_reif_member(T1, T2) :-
    memberd_t(a, [b, a, c], T1),
    memberd_t(z, [b, a, c], T2).

test_reif_case(reif_if, "if_/3 with (=)/3",
    ":- use_module(library(reif)).\n:- use_module(library(dif)).\ntest_reif_if(Branch1, Branch2) :-\n    if_(=(a, a), Branch1 = match, Branch1 = mismatch),\n    if_(=(a, b), Branch2 = match, Branch2 = mismatch).",
    ["test_reif_if(B1, B2)."]).

test_reif_case(reif_filter_partition, "tfilter/3 and tpartition/4",
    ":- use_module(library(reif)).\n:- use_module(library(dif)).\ntest_reif_filter_partition(Filtered, As, NonAs) :-\n    tfilter(=(a), [a, b, a, c, a], Filtered),\n    tpartition(=(a), [a, b, a, c, a], As, NonAs).",
    ["test_reif_filter_partition(F, As, NonAs)."]).

test_reif_case(reif_member, "memberd_t/3 truth value test",
    ":- use_module(library(reif)).\n:- use_module(library(dif)).\ntest_reif_member(T1, T2) :-\n    memberd_t(a, [b, a, c], T1),\n    memberd_t(z, [b, a, c], T2).",
    ["test_reif_member(T1, T2)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_reif:test_reif_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_reif, OutFile),
    generate_scryer_out(OutFile).

run_reif_tests(OutFile) :-
    format("~n--- Module Compatibility: library(reif) ---~n", []),
    run_compat_tests_from_file(test_reif:test_reif_case, OutFile).
run_reif_tests :-
    default_scryer_out_path(test_reif, OutFile),
    run_reif_tests(OutFile).
