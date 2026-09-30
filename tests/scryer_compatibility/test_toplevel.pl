:- module(test_toplevel, [
    run_toplevel_tests/0,
    test_1_if_reif_false/0,
    test_1_if_reif_true/0,
    test_1_if_reif_dif/0,
    test_1_simple_unification/0,
    test_1_unbound_variable_in_list/0,
    test_1_shared_variables/0,
    test_1_truth_and_failure/0
]).

/** <module> Scryer Compatibility: Toplevel & Reified Conditionals

Tests basic toplevel interactions, variable unifications, truth/failure,
and pure reified conditionals (if_/3) matching Scryer Prolog behavior.
*/

:- use_module(library(format)).
:- use_module(compat_framework).

test_1_if_reif_false :-
    assert_scryer_crowlog_compat("if_(3=4, true, false).", ["false."]).

test_1_if_reif_true :-
    assert_scryer_crowlog_compat("if_(3=3, X = yes, X = no).", ["X = yes"]).

test_1_if_reif_dif :-
    assert_scryer_crowlog_compat("if_(dif(a, b), X = diff, X = same).", ["X = diff"]).

test_1_simple_unification :-
    assert_scryer_crowlog_compat("A = 1.", ["A = 1"]).

test_1_unbound_variable_in_list :-
    assert_scryer_crowlog_compat("A = [B].", ["A = [B]"]).

test_1_shared_variables :-
    assert_scryer_crowlog_compat("A = B, B = foo(bar).", ["A = foo(bar)", "B = foo(bar)"]).

test_1_truth_and_failure :-
    assert_scryer_crowlog_compat("true.", ["true."]),
    assert_scryer_crowlog_compat("fail.", ["false."]).

run_toplevel_tests :-
    format("~n--- Tier 1: Basic Toplevel & Reified Conditionals ---~n", []),
    run_compat_test("if_(3=4, true, false) fails", test_toplevel:test_1_if_reif_false),
    run_compat_test("if_(3=3, X = yes, X = no) binds then branch", test_toplevel:test_1_if_reif_true),
    run_compat_test("if_(dif(a, b), ...) evaluates pure dif condition", test_toplevel:test_1_if_reif_dif),
    run_compat_test("simple unification (A = 1)", test_toplevel:test_1_simple_unification),
    run_compat_test("unbound variable representation (A = [B])", test_toplevel:test_1_unbound_variable_in_list),
    run_compat_test("shared variable aliasing", test_toplevel:test_1_shared_variables),
    run_compat_test("truth and failure queries", test_toplevel:test_1_truth_and_failure).

:- initialization(run_toplevel_tests).
