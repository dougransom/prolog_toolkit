:- module(test_time, [
    run_time_tests/0,
    run_time_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_time_case/4
]).

/** <module> Scryer Compatibility: Time Reasoning (library(time))

Tests format_time//2 and max_sleep_time/1.
*/

:- use_module(library(dcgs)).
:- use_module(library(format)).
:- use_module(library(time)).
:- use_module(compat_framework).

% Native Scryer predicates
test_format_timestamp(Cs) :-
    TimeStamp = [('Y')="2026", ('m')="10", ('d')="01", ('H')="15", ('M')="30", ('S')="45"],
    phrase(format_time("%Y-%m-%d %H:%M:%S", TimeStamp), Cs).

test_format_literal_percent(Cs) :-
    TimeStamp = [('Y')="2026"],
    phrase(format_time("Year: %Y (%%)", TimeStamp), Cs).

test_max_sleep(Max) :-
    max_sleep_time(Max).

test_time_case(time_format, "phrase(format_time(...)) formats timestamp attributes",
    ":- use_module(library(dcgs)).\n:- use_module(library(time)).\ntest_format_timestamp(Cs) :-\n    TimeStamp = [('Y')=\"2026\", ('m')=\"10\", ('d')=\"01\", ('H')=\"15\", ('M')=\"30\", ('S')=\"45\"],\n    phrase(format_time(\"%Y-%m-%d %H:%M:%S\", TimeStamp), Cs).",
    ["test_format_timestamp(Cs)."]).

test_time_case(time_format_percent, "phrase(format_time(...)) handles literal %%",
    ":- use_module(library(dcgs)).\n:- use_module(library(time)).\ntest_format_literal_percent(Cs) :-\n    TimeStamp = [('Y')=\"2026\"],\n    phrase(format_time(\"Year: %Y (%%)\", TimeStamp), Cs).",
    ["test_format_literal_percent(Cs)."]).

test_time_case(time_max_sleep, "max_sleep_time/1 returns valid upper bound",
    ":- use_module(library(time)).\ntest_max_sleep(Max) :-\n    max_sleep_time(Max).",
    ["test_max_sleep(M)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_time:test_time_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_time, OutFile),
    generate_scryer_out(OutFile).

run_time_tests(OutFile) :-
    format("~n--- Module Compatibility: library(time) ---~n", []),
    run_compat_tests_from_file(test_time:test_time_case, OutFile).
run_time_tests :-
    default_scryer_out_path(test_time, OutFile),
    run_time_tests(OutFile).
