:- module(test_clpz, [
    run_clpz_tests/0,
    test_4_clpz_ops_unavailable_before_import/0,
    test_4_clpz_ops_available_after_import/0,
    test_4_clpz_linear_equation/0,
    test_4_clpz_inequality_and_domains/0
]).

/** <module> Scryer Compatibility: Constraint Logic Programming (library(clpz))

Tests linear equation solving (#=), domain constraints (in, ins),
inequalities (#\=, #>, #=<), and dynamic operator scoping before/after
loading library(clpz).
*/

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(format)).
:- use_module(library(reif)).
:- use_module('../../src/prolog_lexer').
:- use_module('../../src/prolog_reactive_parser').
:- use_module('../../crowlog/crowlog').
:- use_module('../../crowlog/crowlog_toplevel').
:- use_module(compat_framework).

test_4_clpz_ops_unavailable_before_import :-
    % In bare Scryer, CLP(Z) operators are not defined initially
    initial_toplevel_state(State0),
    State0 = state(_, ops(OpT0), _),
    phrase(prolog_tokens(Tokens), "X #= 1."),
    % Parsing "X #= 1." without clpz loaded must throw syntax error or fail to parse as infix
    (   catch(phrase(prolog_parse_clause(OpT0, Term, _), Tokens), error(syntax_error(_), _), fail) ->
        Term \= (_ :- '#='(_, _)),
        Term \= '#='(_, _)
    ;   true
    ).

test_4_clpz_ops_available_after_import :-
    % At toplevel: use_module(library(clpz)) should import the operators
    % and subsequent CLP(Z) constraint goals should execute identically to Scryer.
    assert_scryer_crowlog_compat("use_module(library(clpz)).\nX #= 2 + 3.", [
        "X = 5"
    ]).

test_4_clpz_linear_equation :-
    KB = ":- use_module(library(clpz)).\nsolve(X, Y) :- X #= Y + 2, Y #= 3.",
    assert_scryer_crowlog_compat("solve(X, Y).", KB, [
        "X = 5",
        "Y = 3"
    ]).

test_4_clpz_inequality_and_domains :-
    KB = ":- use_module(library(clpz)).\nrange(X) :- X in 1..5, X #\\= 3, X #> 2, X #=< 4.",
    assert_scryer_crowlog_compat("range(X).", KB, [
        "X = 4"
    ]).

run_clpz_tests :-
    format("~n--- Tier 4: Constraint Logic Programming (CLP(Z)) & Operator Scoping ---~n", []),
    run_compat_test("CLP(Z) operators unavailable before module import", test_clpz:test_4_clpz_ops_unavailable_before_import),
    run_compat_test("CLP(Z) operators dynamically available after use_module", test_clpz:test_4_clpz_ops_available_after_import),
    run_compat_test("CLP(Z) linear equation solving (#=)", test_clpz:test_4_clpz_linear_equation),
    run_compat_test("CLP(Z) domain constraints and inequalities (in, #\\=, #>, #=<)", test_clpz:test_4_clpz_inequality_and_domains).

:- initialization(run_clpz_tests).
