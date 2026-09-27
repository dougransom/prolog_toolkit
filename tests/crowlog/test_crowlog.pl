:- module(test_crowlog, [
    run/0
]).

:- use_module(library(charsio)).
:- use_module(library(dif)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module('../../src/prolog_toolkit').
:- use_module('../../crowlog/crowlog').
:- use_module('../testing').

test("interpret basic facts and rules", (
    prolog_default_operator_table(OpT),
    ProgramText = "parent(pam, bob). parent(tom, bob). ancestor(X, Y) :- parent(X, Y).",
    phrase(prolog_tokens(Tokens), ProgramText),
    phrase(prolog_parse_program(OpT, KB, _), Tokens),
    crowlog_interpret(ancestor(pam, bob), KB),
    \+ crowlog_interpret(ancestor(tom, pam), KB)
)).

test("interpret recursive rules with answer generation", (
    prolog_default_operator_table(OpT),
    ProgramText = "edge(a, b). edge(b, c). edge(c, d). path(X, Y) :- edge(X, Y). path(X, Y) :- edge(X, Z), path(Z, Y).",
    phrase(prolog_tokens(Tokens), ProgramText),
    phrase(prolog_parse_program(OpT, KB, _), Tokens),
    crowlog_interpret(path(a, d), KB),
    findall(Target, crowlog_interpret(path(a, Target), KB), Targets),
    Targets = [b, c, d]
)).

test("derivation tree generation with source spans", (
    prolog_default_operator_table(OpT),
    ProgramText = "likes(john, pizza).",
    phrase(prolog_tokens(Tokens), ProgramText),
    phrase(prolog_parse_program(OpT, KB, _), Tokens),
    crowlog_interpret(likes(john, pizza), KB, Tree),
    Tree = proof(step(likes(john, pizza), Span, proof(true))),
    dif(Span, no_span)
)).

test("absorbed builtins execution", (
    KB = [],
    crowlog_interpret((X is 2 + 3, X > 4, dif(X, 10)), KB)
)).

test("interpret pure reified if_ conditional", (
    KB = [
        clause((sign(N, S) :- if_(N = 0, S = zero, S = nonzero)), meta([]))
    ],
    crowlog_interpret(sign(0, S1), KB),
    S1 = zero,
    crowlog_interpret(sign(5, S2), KB),
    S2 = nonzero
)).

run :-
    format("~n=== Running Crowlog Meta-Interpreter Tests ===~n", []),
    run_tests,
    exit_test_process.

:- initialization(run).
