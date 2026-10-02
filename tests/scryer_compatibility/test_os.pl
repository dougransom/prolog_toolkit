:- module(test_os, [
    run_os_tests/0,
    run_os_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_os_case/4
]).

/** <module> Scryer Compatibility: Operating System Environment (library(os))

Tests setenv/2, getenv/2, unsetenv/1, and pid/1.
*/

:- use_module(library(format)).
:- use_module(library(os)).
:- use_module(compat_framework).

% Native Scryer predicates
test_env_lifecycle(Val) :-
    setenv("SCRYER_COMPAT_ENV_TEST", "PrologToolkit"),
    getenv("SCRYER_COMPAT_ENV_TEST", Val),
    unsetenv("SCRYER_COMPAT_ENV_TEST").

test_pid_is_integer(IsInt) :-
    pid(PID),
    (   integer(PID), PID > 0 -> IsInt = true ; IsInt = false ).

test_os_case(env_lifecycle, "setenv/2, getenv/2, and unsetenv/1 manage process environment",
    ":- use_module(library(os)).\ntest_env_lifecycle(Val) :-\n    setenv(\"SCRYER_COMPAT_ENV_TEST\", \"PrologToolkit\"),\n    getenv(\"SCRYER_COMPAT_ENV_TEST\", Val),\n    unsetenv(\"SCRYER_COMPAT_ENV_TEST\").",
    ["test_env_lifecycle(V)."]).

test_os_case(pid_query, "pid/1 retrieves positive integer process identifier",
    ":- use_module(library(os)).\ntest_pid_is_integer(IsInt) :-\n    pid(PID),\n    (   integer(PID), PID > 0 -> IsInt = true ; IsInt = false ).",
    ["test_pid_is_integer(Ok)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_os:test_os_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_os, OutFile),
    generate_scryer_out(OutFile).

run_os_tests(OutFile) :-
    format("~n--- Module Compatibility: library(os) ---~n", []),
    run_compat_tests_from_file(test_os:test_os_case, OutFile).
run_os_tests :-
    default_scryer_out_path(test_os, OutFile),
    run_os_tests(OutFile).
