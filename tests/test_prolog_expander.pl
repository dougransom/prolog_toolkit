:- module(test_prolog_expander, [
    run/0
]).

:- use_module(library(charsio)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(si)).
:- use_module('../src/prolog_toolkit').
:- use_module(testing).

test("identity expansion (expand_mode none)", (
    prolog_initial_expander_state([expand_mode(none)], State0),
    prolog_expand_term([expand_mode(none)], (foo --> [a]), Terms, State0, _),
    Terms = [(foo --> [a])]
)).

test("pure DCG expansion for terminal sequence", (
    prolog_dcg_expand_rule((foo --> [a, b]), Clause),
    Clause = (foo(S0, S) :- S0 = [a, b|S])
)).

test("pure DCG expansion for non-terminal sequencing and goals", (
    prolog_dcg_expand_rule((sentence --> noun, verb, { check }), Clause),
    Clause = (sentence(S0, S) :- (noun(S0, S1), verb(S1, S2), (check, S2 = S)))
)).

test("pure DCG expansion with pushback list", (
    prolog_dcg_expand_rule(((lookahead(X), [X]) --> [X]), Clause),
    Clause = (lookahead(X, S0, S) :- (S0 = [X|S1], S = [X|S1]))
)).

custom_macro(hello(Name), [greeting(Name), audit(hello(Name))]) :- !.
custom_macro(declare_custom_op, (:- op(750, xfx, '<++>'))) :- !.
custom_macro(T, T).

test("custom delegate expansion (one-to-many)", (
    prolog_initial_expander_state([expand_mode(delegate(test_prolog_expander:custom_macro))], State0),
    prolog_expand_statement([expand_mode(delegate(test_prolog_expander:custom_macro))], clause(hello("Alice"), meta([])), Stmts, State0, _),
    Stmts = [clause(greeting("Alice"), _), clause(audit(hello("Alice")), _)]
)).

test("local rewrite rules expansion", (
    Rules = [rule(square(X), expr(X * X))],
    prolog_initial_expander_state([expand_mode(rules(Rules))], State0),
    prolog_expand_term([expand_mode(rules(Rules))], square(5), Terms, State0, _),
    Terms = [expr(5 * 5)]
)).

test("expansion affecting the remainder of program parse (dynamic operator declaration via expansion)", (
    Input = ":- declare_custom_op. left <++> right.",
    prolog_default_operator_table(OpTable0),
    \+ prolog_is_operator(OpTable0, "<++>", _, _),
    phrase(prolog_tokens(Tokens), Input),
    phrase(prolog_parse_program(OpTable0, [expand_mode(delegate(test_prolog_expander:custom_macro)), expand_directives(true)], Stmts, FinalOpTable), Tokens),
    Stmts = [directive(op(750, xfx, '<++>'), _), clause(InfixTerm, _)],
    InfixTerm =.. ['<++>', left, right],
    prolog_is_operator(FinalOpTable, "<++>", 750, xfx)
)).

test("prolog_parse_clause with pure_dcg expand_mode", (
    prolog_default_operator_table(OpTable0),
    phrase(prolog_tokens(Tokens), "digits --> [1, 2]."),
    phrase(prolog_parse_clause(OpTable0, [expand_mode(pure_dcg)], Stmt, _), Tokens),
    Stmt = clause((digits(S0, S) :- S0 = [1, 2|S]), _)
)).

test("host delegation expand_mode", (
    prolog_default_operator_table(OpTable0),
    phrase(prolog_tokens(Tokens), "item --> [x]."),
    phrase(prolog_parse_clause(OpTable0, [expand_mode(host)], Stmt, _), Tokens),
    Stmt = clause((item(S0, S) :- S0 = [x|S]), _)
)).

run :-
    run_tests,
    halt.

:- initialization(run).
