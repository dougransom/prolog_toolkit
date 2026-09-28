:- module(test_toplevel, [
    run/0,
    chars_contains/2,
    chars_contains_all/2,
    assert_toplevel_contains/2,
    assert_toplevel_contains/4
]).

/** <module> Unit Tests for Crowlog Toplevel (REPL)

Tests are organized hierarchically from foundation primitives up to meta-commands
and provenance derivation trees, using declarative assertion helpers.
*/

:- use_module(library(charsio)).
:- use_module(library(dif)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module('../../src/prolog_toolkit').
:- use_module('../../crowlog/crowlog').
:- use_module('../../crowlog/crowlog_toplevel').
:- use_module('../testing').

%% ============================================================================
%% Test Assertion Helpers
%% ============================================================================

%% chars_contains(+Chars, +Sub)
%  Succeeds if Sub is a contiguous sublist of Chars.
chars_contains(Chars, Sub) :-
    append(_, Rest, Chars),
    append(Sub, _, Rest).

%% chars_contains_all(+Chars, +Substrings)
%  Succeeds if every substring in Substrings is present in Chars.
chars_contains_all(Chars, Substrings) :-
    maplist(chars_contains(Chars), Substrings).

%% assert_toplevel_contains(+InputChars, +ExpectedSubstrings)
%  Runs a toplevel session string from empty state and asserts all substrings.
assert_toplevel_contains(InputChars, ExpectedSubstrings) :-
    crowlog_toplevel_string(InputChars, Output),
    chars_contains_all(Output, ExpectedSubstrings).

%% assert_toplevel_contains(+InputChars, +State0, +ExpectedSubstrings, -StateFinal)
%  Runs a toplevel session string from State0 and asserts all substrings.
assert_toplevel_contains(InputChars, State0, ExpectedSubstrings, StateFinal) :-
    crowlog_toplevel_string(InputChars, State0, Output, StateFinal),
    chars_contains_all(Output, ExpectedSubstrings).

%% ============================================================================
%% Tier 0: State & Derivation Tree Structures
%% ============================================================================

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
    Derivation = proof(step(path(a, c), _, _))
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
    chars_contains_all(Chars, ["Derivation Tree", "path(a,c)"])
)).

%% ============================================================================
%% Tier 1: Pure Unification & Variable Bindings
%% ============================================================================

test("tier 1: ground success (true=true)", (
    assert_toplevel_contains("true = true.\nhalt.\n", ["true"])
)).

test("tier 1: ground failure (fail)", (
    assert_toplevel_contains("fail.\nhalt.\n", ["false."])
)).

test("tier 1: single variable binding (A = true)", (
    assert_toplevel_contains("A = true.\nhalt.\n", ["A = true"])
)).

test("tier 1: compound multi-variable binding", (
    assert_toplevel_contains("pair(X, Y) = pair(foo, bar).\nhalt.\n", [
        "X = foo",
        "Y = bar"
    ])
)).

test("tier 1: shared variables and aliasing (A = B, B = 42)", (
    assert_toplevel_contains("A = B, B = 42.\nhalt.\n", [
        "A = 42",
        "B = 42"
    ])
)).

%% ============================================================================
%% Tier 2: Arithmetic, Absorbed Builtins & Error Handling
%% ============================================================================

test("tier 2: arithmetic evaluation (A is 1 + 2)", (
    assert_toplevel_contains("A is 1 + 2.\nhalt.\n", ["A = 3"])
)).

test("tier 2: arithmetic equality check (3 is 1 + 2)", (
    assert_toplevel_contains("3 is 1 + 2.\nhalt.\n", ["true"])
)).

test("tier 2: arithmetic error reporting (1 is A)", (
    assert_toplevel_contains("1 is A.\nhalt.\n", ["instantiation_error"])
)).

test("tier 2: pure inequality success (dif(a, b))", (
    assert_toplevel_contains("dif(a, b).\nhalt.\n", ["true"])
)).

test("tier 2: pure inequality failure (dif(a, a))", (
    assert_toplevel_contains("dif(a, a).\nhalt.\n", ["false."])
)).

test("tier 2: reified conditional (if_/3)", (
    assert_toplevel_contains("if_(true, X = 1, X = 2).\nhalt.\n", ["X = 1"])
)).

%% ============================================================================
%% Tier 3: Multi-Solution & Backtracking
%% ============================================================================

test("tier 3: complete backtracking through choices (;)", (
    assert_toplevel_contains("member(X, [a, b, c]).\n;\n;\nhalt.\n", [
        "X = a",
        "X = b",
        "X = c"
    ])
)).

test("tier 3: early termination without backtracking", (
    assert_toplevel_contains("member(X, [a, b, c]).\nhalt.\n", ["X = a"])
)).

test("tier 3: multi-goal backtracking (append/3)", (
    assert_toplevel_contains("append(A, B, [1, 2]).\n;\n;\n;\nhalt.\n", [
        "A = []",
        "B = [1,2]",
        "A = [1]",
        "B = [2]",
        "A = [1,2]",
        "B = []"
    ])
)).

%% ============================================================================
%% Tier 4: Meta-Commands & KB Listing
%% ============================================================================

test("tier 4: help command", (
    assert_toplevel_contains("help.\nhalt.\n", [
        "Crowlog Toplevel Commands:",
        "listing(pred). / listing(pred/N)."
    ])
)).

test("tier 4: option toggles (tree and trace)", (
    assert_toplevel_contains("tree.\nnotree.\ntrace.\nnotrace.\nhalt.\n", [
        "Derivation tree display enabled.",
        "Derivation tree display disabled.",
        "Execution tracing enabled.",
        "Execution tracing disabled."
    ])
)).

test("tier 4: listing clauses from KB", (
    initial_toplevel_state(State0),
    ProgramText = "num(1). num(2). edge(a, b).",
    phrase(prolog_tokens(Tokens), ProgramText),
    State0 = state(kb(_), ops(OpT), opts(Opts)),
    phrase(prolog_parse_program(OpT, Clauses, OpT1), Tokens),
    State1 = state(kb(Clauses), ops(OpT1), opts(Opts)),
    assert_toplevel_contains("listing.\nlisting(edge).\nhalt.\n", State1, [
        "num(1).",
        "num(2).",
        "edge(a,b)."
    ], _)
)).

%% ============================================================================
%% Tier 5: Provenance Proof Trees
%% ============================================================================

test("tier 5: proof tree rendering in toplevel session", (
    initial_toplevel_state(State0),
    ProgramText = "edge(a, b). edge(b, c). path(X, Y) :- edge(X, Y). path(X, Y) :- edge(X, Z), path(Z, Y).",
    phrase(prolog_tokens(Tokens), ProgramText),
    State0 = state(kb(_), ops(OpT), opts(Opts)),
    phrase(prolog_parse_program(OpT, Clauses, OpT1), Tokens),
    State1 = state(kb(Clauses), ops(OpT1), opts(Opts)),
    assert_toplevel_contains("tree.\npath(a, c).\nhalt.\n", State1, [
        "--- Derivation Tree ---",
        "|- path(a,c)"
    ], _)
)).

run :-
    format("~n=== Running Crowlog Toplevel Tests ===~n", []),
    run_tests,
    exit_test_process.

:- initialization(run).
