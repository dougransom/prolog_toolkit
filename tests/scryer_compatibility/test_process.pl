:- module(test_process, [
    run_process_tests/0,
    run_process_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_process_case/4
]).

/** <module> Scryer Compatibility: External Process Management (library(process))

Tests process_create/3, process_id/2, process_wait/2, and process_release/1.
*/

:- use_module(library(process)).
:- use_module(library(charsio)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_process_spawn(Output, ExitStatus) :-
    process_create("/bin/echo", ["hello_prolog_process"], [stdout(pipe(Stream)), process(P)]),
    process_id(P, _Pid),
    get_n_chars(Stream, _N, Output),
    close(Stream),
    process_wait(P, ExitStatus),
    process_release(P).

test_process_case(process_execution, "process_create/3 spawns subprocess and captures stdout via pipe",
    ":- use_module(library(process)).\n:- use_module(library(charsio)).\ntest_process_spawn(Output, ExitStatus) :-\n    process_create(\"/bin/echo\", [\"hello_prolog_process\"], [stdout(pipe(Stream)), process(P)]),\n    process_id(P, _Pid),\n    get_n_chars(Stream, _N, Output),\n    close(Stream),\n    process_wait(P, ExitStatus),\n    process_release(P).",
    ["test_process_spawn(Out, Exit)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_process:test_process_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_process, OutFile),
    generate_scryer_out(OutFile).

run_process_tests(OutFile) :-
    format("~n--- Module Compatibility: library(process) ---~n", []),
    run_compat_tests_from_file(test_process:test_process_case, OutFile).
run_process_tests :-
    default_scryer_out_path(test_process, OutFile),
    run_process_tests(OutFile).
