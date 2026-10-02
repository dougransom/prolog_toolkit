:- module(test_clpz, [
    run_clpz_tests/0,
    run_clpz_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_clpz_case/4
]).

/** <module> Scryer Compatibility: Constraint Logic Programming (library(clpz))

Tests linear equation solving (#=), domain constraints (in, ins),
inequalities (#\=, #>, #=<), and dynamic operator scoping before/after
loading library(clpz).
*/

:- use_module(library(clpz)).
:- use_module(library(format)).
:- use_module(library(reif)).
:- use_module('../../src/prolog_lexer').
:- use_module('../../src/prolog_reactive_parser').
:- use_module('../../crowlog/crowlog_toplevel').
:- use_module(compat_framework).

% Predicates for native Scryer execution
solve(X, Y) :- X #= Y + 2, Y #= 3.
range(X) :- X in 1..5, X #\= 3, X #> 2, X #=< 4.

test_clpz_case(clpz_constraints, "CLP(Z) linear equations, domains, and inequalities",
    ":- use_module(library(clpz)).\nsolve(X, Y) :- X #= Y + 2, Y #= 3.\nrange(X) :- X in 1..5, X #\\= 3, X #> 2, X #=< 4.",
    [
        "solve(X, Y).",
        "range(R)."
    ]).

test_4_clpz_ops_unavailable_before_import :-
    % In bare Scryer, CLP(Z) operators are not defined initially
    initial_toplevel_state(State0),
    State0 = state(_, ops(OpT0), _),
    phrase(prolog_tokens(Tokens), "X #= 1."),
    (   catch(phrase(prolog_parse_clause(OpT0, Term, _), Tokens), error(syntax_error(_), _), fail) ->
        Term \= (_ :- '#='(_, _)),
        Term \= '#='(_, _)
    ;   true
    ).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_clpz:test_clpz_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_clpz, OutFile),
    generate_scryer_out(OutFile).

run_clpz_tests(OutFile) :-
    format("~n--- Tier 4: Constraint Logic Programming (CLP(Z)) & Operator Scoping ---~n", []),
    run_compat_test("CLP(Z) operators unavailable before module import", test_clpz:test_4_clpz_ops_unavailable_before_import),
    run_compat_tests_from_file(test_clpz:test_clpz_case, OutFile).
run_clpz_tests :-
    default_scryer_out_path(test_clpz, OutFile),
    run_clpz_tests(OutFile).
