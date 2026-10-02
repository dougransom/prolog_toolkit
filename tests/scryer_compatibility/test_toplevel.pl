:- module(test_toplevel, [
    run_toplevel_tests/0,
    run_toplevel_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_toplevel_case/4
]).

/** <module> Scryer Compatibility: Toplevel & Reified Conditionals

Tests basic toplevel interactions, variable unifications, truth/failure,
and pure reified conditionals (if_/3) matching Scryer Prolog behavior.
*/

:- use_module(library(format)).
:- use_module(library(reif)).
:- use_module(library(dif)).
:- use_module(compat_framework).

test_toplevel_case(if_reif_false, "if_(3=4, true, false) fails", "", ["if_(3=4, true, false)."]).
test_toplevel_case(if_reif_true, "if_(3=3, X = yes, X = no) binds then branch", "", ["if_(3=3, X = yes, X = no)."]).
test_toplevel_case(if_reif_dif, "if_(dif(a, b), ...) evaluates pure dif condition", "", ["if_(dif(a, b), X = diff, X = same)."]).
test_toplevel_case(simple_unification, "simple unification (A = 1)", "", ["A = 1."]).
test_toplevel_case(unbound_variable_in_list, "unbound variable representation (A = [B])", "", ["A = [B]."]).
test_toplevel_case(shared_variables, "shared variable aliasing", "", ["A = B, B = foo(bar)."]).
test_toplevel_case(truth, "truth query (true.)", "", ["true."]).
test_toplevel_case(failure, "failure query (fail.)", "", ["fail."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_toplevel:test_toplevel_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_toplevel, OutFile),
    generate_scryer_out(OutFile).

run_toplevel_tests(OutFile) :-
    format("~n--- Tier 1: Basic Toplevel & Reified Conditionals ---~n", []),
    run_compat_tests_from_file(test_toplevel:test_toplevel_case, OutFile).
run_toplevel_tests :-
    default_scryer_out_path(test_toplevel, OutFile),
    run_toplevel_tests(OutFile).
