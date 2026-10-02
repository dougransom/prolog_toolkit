:- module(test_cont, [
    run_cont_tests/0,
    run_cont_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_cont_case/4
]).

/** <module> Scryer Compatibility: Delimited Control (library(cont))

Tests reset/3 and shift/1 for delimited continuations and custom control effects.
*/

:- use_module(library(cont)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
producer(Final) :-
    shift(item(42)),
    Final = finished.

test_reset_shift(Yielded) :-
    reset(producer(_Final), Yielded, _Cont).

test_cont_case(reset_shift, "reset/3 captures control effect triggered by shift/1",
    ":- use_module(library(cont)).\nproducer(Final) :-\n    shift(item(42)),\n    Final = finished.\ntest_reset_shift(Yielded) :-\n    reset(producer(_Final), Yielded, _Cont).",
    ["test_reset_shift(Y)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_cont:test_cont_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_cont, OutFile),
    generate_scryer_out(OutFile).

run_cont_tests(OutFile) :-
    format("~n--- Module Compatibility: library(cont) ---~n", []),
    run_compat_tests_from_file(test_cont:test_cont_case, OutFile).
run_cont_tests :-
    default_scryer_out_path(test_cont, OutFile),
    run_cont_tests(OutFile).
