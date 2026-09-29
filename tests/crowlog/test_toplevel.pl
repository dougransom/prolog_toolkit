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
:- use_module(library(dcgs)).
:- use_module(library(dif)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module('../../src/prolog_lexer').
:- use_module('../../src/prolog_reactive_parser').
:- use_module('../../crowlog/crowlog').
:- use_module('../../crowlog/crowlog_toplevel').

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
chars_contains_all(_, []).
chars_contains_all(Chars, [Sub|Subs]) :-
    chars_contains(Chars, Sub),
    chars_contains_all(Chars, Subs).

%% assert_toplevel_contains(+InputChars, +ExpectedSubstrings)
%  Runs a toplevel session string from empty state and asserts all substrings.
assert_toplevel_contains(InputChars, ExpectedSubstrings) :-
    crowlog_toplevel_string(InputChars, Output),
    (   chars_contains_all(Output, ExpectedSubstrings) ->
        true
    ;   format("Mismatch! Output was:~n~s~n", [Output]),
        flush_output,
        fail
    ).

%% assert_toplevel_contains(+InputChars, +State0, +ExpectedSubstrings, -StateFinal)
%  Runs a toplevel session string from State0 and asserts all substrings.
assert_toplevel_contains(InputChars, State0, ExpectedSubstrings, StateFinal) :-
    crowlog_toplevel_string(InputChars, State0, Output, StateFinal),
    (   chars_contains_all(Output, ExpectedSubstrings) ->
        true
    ;   format("Mismatch! Output was:~n~s~n", [Output]),
        flush_output,
        fail
    ).

run_test(Name, Goal) :-
    format("Running: ~s~n", [Name]),
    flush_output,
    (   catch(Goal, E, (format("FAIL (~s): exception: ~w~n", [Name, E]), flush_output, fail)) ->
        format("OK: ~s~n", [Name]),
        flush_output
    ;   format("FAIL: ~s~n", [Name]),
        flush_output,
        halt(1)
    ).

%% ============================================================================
%% Tier 0: State & Derivation Tree Structures
%% ============================================================================

test_0_initial_state :-
    initial_toplevel_state(state(kb(KB), ops(OpT), opts(Opts))),
    KB = [],
    member(tree(false), Opts),
    member(trace(false), Opts),
    dif(OpT, []).

test_0_query_eval :-
    initial_toplevel_state(State0),
    ProgramText = "edge(a, b). edge(b, c). path(X, Y) :- edge(X, Y). path(X, Y) :- edge(X, Z), path(Z, Y).",
    phrase(prolog_tokens(Tokens), ProgramText),
    State0 = state(kb(_), ops(OpT), opts(Opts)),
    phrase(prolog_parse_program(OpT, Clauses, OpT1), Tokens),
    State1 = state(kb(Clauses), ops(OpT1), opts(Opts)),
    crowlog_eval_query(path(a, c), ['X'=_X, 'Y'=_Y], State1, Derivation),
    Derivation = proof(step(path(a, c), _, _)).

test_0_derivation_pretty_print :-
    initial_toplevel_state(State0),
    ProgramText = "edge(a, b). edge(b, c). path(X, Y) :- edge(X, Y). path(X, Y) :- edge(X, Z), path(Z, Y).",
    phrase(prolog_tokens(Tokens), ProgramText),
    State0 = state(kb(_), ops(OpT), opts(Opts)),
    phrase(prolog_parse_program(OpT, Clauses, OpT1), Tokens),
    State1 = state(kb(Clauses), ops(OpT1), opts(Opts)),
    crowlog_eval_query(path(a, c), [], State1, Derivation),
    derivation_tree_chars(Derivation, Chars),
    chars_contains_all(Chars, ["Derivation Tree", "path(a,"]).

%% ============================================================================
%% Tier 1: Pure Unification & Variable Bindings
%% ============================================================================

test_1_ground_success :-
    assert_toplevel_contains("true = true.\nhalt.\n", ["true"]).

test_1_ground_failure :-
    assert_toplevel_contains("fail.\nhalt.\n", ["false."]).

test_1_single_var :-
    assert_toplevel_contains("A = true.\nhalt.\n", ["A = true"]).

test_1_compound_multivar :-
    assert_toplevel_contains("pair(X, Y) = pair(foo, bar).\nhalt.\n", [
        "X = foo",
        "Y = bar"
    ]).

test_1_aliasing :-
    assert_toplevel_contains("A = B, B = 42.\nhalt.\n", [
        "A = 42",
        "B = 42"
    ]).

test_1_unbound_var_in_list :-
    assert_toplevel_contains("X = [Y].\nhalt.\n", [
        "X = [",
        "Y = "
    ]).

%% ============================================================================
%% Tier 2: Arithmetic, Absorbed Builtins & Error Handling
%% ============================================================================

test_2_arithmetic_eval :-
    assert_toplevel_contains("A is 1 + 2.\nhalt.\n", ["A = 3"]).

test_2_arithmetic_eq :-
    assert_toplevel_contains("3 is 1 + 2.\nhalt.\n", ["true"]).

test_2_arithmetic_error :-
    assert_toplevel_contains("1 is A.\nhalt.\n", ["instantiation_error"]).

test_2_dif_success :-
    assert_toplevel_contains("dif(a, b).\nhalt.\n", ["true"]).

test_2_dif_failure :-
    assert_toplevel_contains("dif(a, a).\nhalt.\n", ["false."]).

test_2_if_reif :-
    assert_toplevel_contains("if_(true, X = 1, X = 2).\nhalt.\n", ["X = 1"]).

%% ============================================================================
%% Tier 3: Multi-Solution & Backtracking
%% ============================================================================

test_3_complete_backtracking :-
    assert_toplevel_contains("member(X, [a, b, c]).\n;\n;\nhalt.\n", [
        "X = a",
        "X = b",
        "X = c"
    ]).

test_3_early_termination :-
    assert_toplevel_contains("member(X, [a, b, c]).\nhalt.\n", ["X = a"]).

test_3_multi_goal :-
    assert_toplevel_contains("append(A, B, [1, 2]).\n;\n;\nhalt.\n", [
        "A = []",
        "B = [1,2]",
        "A = [1]",
        "B = [2]",
        "A = [1,2]",
        "B = []"
    ]).

%% ============================================================================
%% Tier 4: Meta-Commands & KB Listing
%% ============================================================================

test_4_help :-
    assert_toplevel_contains("help.\nhalt.\n", [
        "Crowlog Toplevel Commands:",
        "listing(pred). / listing(pred/N)."
    ]).

test_4_opts :-
    assert_toplevel_contains("tree.\nnotree.\ntrace.\nnotrace.\nhalt.\n", [
        "Derivation tree display enabled.",
        "Derivation tree display disabled.",
        "Execution tracing enabled.",
        "Execution tracing disabled."
    ]).

test_4_listing :-
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
    ], _).

%% ============================================================================
%% Tier 5: Provenance Proof Trees
%% ============================================================================

test_5_proof_tree :-
    initial_toplevel_state(State0),
    ProgramText = "edge(a, b). edge(b, c). path(X, Y) :- edge(X, Y). path(X, Y) :- edge(X, Z), path(Z, Y).",
    phrase(prolog_tokens(Tokens), ProgramText),
    State0 = state(kb(_), ops(OpT), opts(Opts)),
    phrase(prolog_parse_program(OpT, Clauses, OpT1), Tokens),
    State1 = state(kb(Clauses), ops(OpT1), opts(Opts)),
    assert_toplevel_contains("tree.\npath(a, c).\nhalt.\n", State1, [
        "--- Derivation Tree ---",
        "|- path(a,"
    ], _).

%% ============================================================================
%% Tier 6: Malformed Input & Error Resilience
%% ============================================================================

test_6_syntax_error_incomplete_term :-
    assert_toplevel_contains("A=.\nhalt.\n", [
        "error(syntax_error(cannot_parse_term)",
        "Exiting Crowlog."
    ]).

test_6_quoted_dot_atom :-
    assert_toplevel_contains("A = '.'.\nhalt.\n", ["A = '.'"]).

test_6_float_dot :-
    assert_toplevel_contains("A = 3.14.\nhalt.\n", ["A = 3.14"]).

test_6_undefined_graphic_atom :-
    assert_toplevel_contains("a=.\nhalt.\n", ["error(syntax_error(cannot_parse_term)"]).

test_6_unbound_variable_query :-
    assert_toplevel_contains("X.\nhalt.\n", ["instantiation_error"]).

test_6_non_callable_number_query :-
    assert_toplevel_contains("123.\nhalt.\n", ["type_error(callable,123)"]).

test_6_zero_divisor_error :-
    assert_toplevel_contains("1 is 5 / 0.\nhalt.\n", ["evaluation_error(zero_divisor)"]).

test_6_invalid_operator :-
    assert_toplevel_contains("A =: 3.\nhalt.\n", [
        "error(syntax_error(cannot_parse_term)",
        "Exiting Crowlog."
    ]).

test_6_syntax_error_recovery :-
    assert_toplevel_contains("A=:\n.\nA = 42.\nhalt.\n", [
        "error(syntax_error(cannot_parse_term)",
        "A = 42."
    ]).

test_6_multiline_query :-
    assert_toplevel_contains("append([1],\n  [2],\n  Res\n).\nhalt.\n", ["Res = [1,2]"]).

%% ============================================================================
%% Runner
%% ============================================================================

run :-
    format("~n=== Running Crowlog Toplevel Tests ===~n", []),
    flush_output,
    run_test("tier 0: initial toplevel state creation", test_0_initial_state),
    run_test("tier 0: query evaluation against toplevel state", test_0_query_eval),
    run_test("tier 0: derivation tree pretty printing", test_0_derivation_pretty_print),
    run_test("tier 1: ground success (true=true)", test_1_ground_success),
    run_test("tier 1: ground failure (fail)", test_1_ground_failure),
    run_test("tier 1: single variable binding (A = true)", test_1_single_var),
    run_test("tier 1: compound multi-variable binding", test_1_compound_multivar),
    run_test("tier 1: shared variables and aliasing (A = B, B = 42)", test_1_aliasing),
    run_test("tier 1: unbound variable in compound term (X = [Y])", test_1_unbound_var_in_list),
    run_test("tier 2: arithmetic evaluation (A is 1 + 2)", test_2_arithmetic_eval),
    run_test("tier 2: arithmetic equality check (3 is 1 + 2)", test_2_arithmetic_eq),
    run_test("tier 2: arithmetic error reporting (1 is A)", test_2_arithmetic_error),
    run_test("tier 2: pure inequality success (dif(a, b))", test_2_dif_success),
    run_test("tier 2: pure inequality failure (dif(a, a))", test_2_dif_failure),
    run_test("tier 2: reified conditional (if_/3)", test_2_if_reif),
    run_test("tier 3: complete backtracking through choices (;)", test_3_complete_backtracking),
    run_test("tier 3: early termination without backtracking", test_3_early_termination),
    run_test("tier 3: multi-goal backtracking (append/3)", test_3_multi_goal),
    run_test("tier 4: help command", test_4_help),
    run_test("tier 4: option toggles (tree and trace)", test_4_opts),
    run_test("tier 4: listing clauses from KB", test_4_listing),
    run_test("tier 5: proof tree rendering in toplevel session", test_5_proof_tree),
    run_test("tier 6: syntax error on incomplete term (A=.)", test_6_syntax_error_incomplete_term),
    run_test("tier 6: quoted dot atom (A = '.')", test_6_quoted_dot_atom),
    run_test("tier 6: float dot (A = 3.14)", test_6_float_dot),
    run_test("tier 6: undefined graphic atom (a=.)", test_6_undefined_graphic_atom),
    run_test("tier 6: unbound variable query (X.)", test_6_unbound_variable_query),
    run_test("tier 6: non-callable number query (123.)", test_6_non_callable_number_query),
    run_test("tier 6: zero divisor error (1 is 5 / 0)", test_6_zero_divisor_error),
    run_test("tier 6: invalid operator syntax error (A =: 3)", test_6_invalid_operator),
    run_test("tier 6: syntax error recovery (A=: . then A = 42)", test_6_syntax_error_recovery),
    run_test("tier 6: multiline query formatting", test_6_multiline_query),
    format("~n=== All 32 Crowlog Toplevel Tests Passed Successfully ===~n", []),
    flush_output,
    halt(0).

:- initialization(run).
