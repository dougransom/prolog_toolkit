:- module(test_diag, [
    run_diag_tests/0,
    run_diag_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_diag_case/4
]).

/** <module> Scryer Compatibility: WAM Diagnostics (library(diag))

Tests wam_instructions/2 to inspect compiled Warren Abstract Machine bytecode instructions.
*/

:- use_module(library(diag)).
:- use_module(library(lists)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_wam_inspect(FirstInstr) :-
    wam_instructions(lists:(append/3), Instrs),
    Instrs = [FirstInstr|_].

test_diag_case(wam_disassembly, "wam_instructions/2 decompiles predicate indicator into WAM instructions",
    ":- use_module(library(diag)).\n:- use_module(library(lists)).\ntest_wam_inspect(FirstInstr) :-\n    wam_instructions(lists:(append/3), Instrs),\n    Instrs = [FirstInstr|_].",
    ["test_wam_inspect(I)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_diag:test_diag_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_diag, OutFile),
    generate_scryer_out(OutFile).

run_diag_tests(OutFile) :-
    format("~n--- Module Compatibility: library(diag) ---~n", []),
    run_compat_tests_from_file(test_diag:test_diag_case, OutFile).
run_diag_tests :-
    default_scryer_out_path(test_diag, OutFile),
    run_diag_tests(OutFile).
