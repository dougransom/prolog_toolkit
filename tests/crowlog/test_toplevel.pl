:- module(test_toplevel, [
    run/0
]).

:- use_module(library(charsio)).
:- use_module(library(dif)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module('../../src/prolog_toolkit').
:- use_module('../../crowlog/crowlog').
:- use_module('../../crowlog/crowlog_toplevel').
:- use_module('../testing').

test("initial toplevel state creation", (
    initial_toplevel_state(state(kb(KB), ops(OpT), opts(Opts))),
    KB = [],
    member(tree(false), Opts),
    member(trace(false), Opts),
    dif(OpT, [])
)).

test("query evaluation against toplevel state", (
    initial_toplevel_state(State0),
    ProgramText = "edge(a, b). edge(b, c). path(X, Y) :- edge(X, Y). path(X, Y) :- edge(X, Z), path(Z, Y).",
    phrase(prolog_tokens(Tokens), ProgramText),
    State0 = state(kb(_), ops(OpT), opts(Opts)),
    phrase(prolog_parse_program(OpT, Clauses, OpT1), Tokens),
    State1 = state(kb(Clauses), ops(OpT1), opts(Opts)),
    crowlog_eval_query(path(a, c), ['X'=_X, 'Y'=_Y], State1, Derivation),
    Tree = Derivation,
    Tree = proof(step(path(a, c), _, _))
)).

test("derivation tree pretty printing", (
    initial_toplevel_state(State0),
    ProgramText = "edge(a, b). edge(b, c). path(X, Y) :- edge(X, Y). path(X, Y) :- edge(X, Z), path(Z, Y).",
    phrase(prolog_tokens(Tokens), ProgramText),
    State0 = state(kb(_), ops(OpT), opts(Opts)),
    phrase(prolog_parse_program(OpT, Clauses, OpT1), Tokens),
    State1 = state(kb(Clauses), ops(OpT1), opts(Opts)),
    crowlog_eval_query(path(a, c), [], State1, Derivation),
    derivation_tree_chars(Derivation, Chars),
    chars_contains(Chars, "Derivation Tree"),
    chars_contains(Chars, "path(a,c)")
)).

chars_contains(Chars, Sub) :-
    append(_, Rest, Chars),
    append(Sub, _, Rest).

run :-
    format("~n=== Running Crowlog Toplevel Tests ===~n", []),
    run_tests,
    exit_test_process.

:- initialization(run).
