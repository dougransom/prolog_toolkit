:- module(test_scryer_compat, [
    run/0,
    assert_scryer_crowlog_compat/2,
    assert_scryer_crowlog_compat/3
]).

/** <module> Scryer Compatibility Test Suite

Verifies that Crowlog produces identical answers, variable bindings,
and error behaviors as Scryer Prolog across language features.

Tiers:
1. Basic Toplevel Queries & Reified Conditionals (e.g. if_(3=4, true, false))
2. Absorbed & Core Builtin Predicates
3. Definite Clause Grammars (DCGs)
4. Constraint Logic Programming over Integers (CLP(Z))
*/

:- use_module(library(charsio)).
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

chars_contains(Chars, Sub) :-
    append(_, Rest, Chars),
    append(Sub, _, Rest).

chars_contains_all(_, []).
chars_contains_all(Chars, [Sub|Subs]) :-
    chars_contains(Chars, Sub),
    chars_contains_all(Chars, Subs).

%% assert_scryer_crowlog_compat(+QueryStr, +ExpectedSubstrings)
%  Runs a query in Crowlog and asserts it matches the standard Scryer behavior.
assert_scryer_crowlog_compat(QueryStr, ExpectedSubstrings) :-
    append(QueryStr, "\nhalt.\n", FullInput),
    crowlog_toplevel_string(FullInput, Output),
    (   chars_contains_all(Output, ExpectedSubstrings) ->
        true
    ;   format("Compatibility Mismatch! Query: ~s~nCrowlog Output:~n~s~nExpected Substrings:~n~q~n",
               [QueryStr, Output, ExpectedSubstrings]),
        flush_output,
        fail
    ).

%% assert_scryer_crowlog_compat(+QueryStr, +InitialKBText, +ExpectedSubstrings)
%  Consults InitialKBText into KB, executes QueryStr, and asserts expected behavior.
assert_scryer_crowlog_compat(QueryStr, InitialKBText, ExpectedSubstrings) :-
    initial_toplevel_state(State0),
    phrase(prolog_tokens(Tokens), InitialKBText),
    State0 = state(kb(_), ops(OpT0), opts(Opts)),
    phrase(prolog_parse_program(OpT0, [expand_mode(pure_dcg)], Clauses, OpT1), Tokens),
    State1 = state(kb(Clauses), ops(OpT1), opts(Opts)),
    append(QueryStr, "\nhalt.\n", FullInput),
    crowlog_toplevel_string(FullInput, State1, Output, _),
    (   chars_contains_all(Output, ExpectedSubstrings) ->
        true
    ;   format("Compatibility Mismatch! Query: ~s~nCrowlog Output:~n~s~nExpected Substrings:~n~q~n",
               [QueryStr, Output, ExpectedSubstrings]),
        flush_output,
        fail
    ).

run_compat_test(Name, Goal) :-
    format("  Testing: ~s ... ", [Name]),
    flush_output,
    (   catch(Goal, E, (format("FAIL (exception: ~w)~n", [E]), flush_output, fail)) ->
        format("OK~n", []),
        flush_output
    ;   format("FAIL~n", []),
        flush_output,
        halt(1)
    ).

%% ============================================================================
%% Tier 1: Basic Toplevel Interactions & Reified Conditionals
%% ============================================================================

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

%% ============================================================================
%% Tier 2: Core Builtins Compatibility
%% ============================================================================

test_2_arithmetic_is :-
    assert_scryer_crowlog_compat("X is 2 * 3 + 4.", ["X = 10"]).

test_2_arithmetic_comparison :-
    assert_scryer_crowlog_compat("10 > 5, 3 =< 3, 4 =:= 2 + 2.", ["true."]).

test_2_type_tests :-
    assert_scryer_crowlog_compat("var(X), nonvar(foo), atom(bar), integer(42), float(3.14), compound(f(1)).", [
        "true."
    ]).

test_2_functor_and_arg :-
    assert_scryer_crowlog_compat("functor(f(a, b, c), F, N), arg(2, f(a, b, c), Arg).", [
        "F = f",
        "N = 3",
        "Arg = b"
    ]).

test_2_univ :-
    assert_scryer_crowlog_compat("Term =.. [foo, 1, 2, bar].", [
        "Term = foo(1,2,bar)"
    ]).

test_2_chars_conversion :-
    assert_scryer_crowlog_compat("atom_chars(hello, Cs), number_chars(123, Ns).", [
        "Cs = [h,e,l,l,o]",
        "Ns = ['1','2','3']"
    ]).

test_2_pure_dif :-
    assert_scryer_crowlog_compat("dif(X, a), X = b.", [
        "X = b"
    ]).

%% ============================================================================
%% Tier 3: Definite Clause Grammars (DCGs)
%% ============================================================================

test_3_basic_dcg :-
    KB = "noun --> [cat]. noun --> [dog]. sentence --> noun, [runs].",
    assert_scryer_crowlog_compat("phrase(sentence, [cat, runs]).", KB, ["true."]),
    assert_scryer_crowlog_compat("phrase(sentence, [dog, runs]).", KB, ["true."]),
    assert_scryer_crowlog_compat("phrase(sentence, [fish, runs]).", KB, ["false."]).

test_3_dcg_arguments_and_generation :-
    KB = "expr(N) --> [N], { integer(N) }. expr(A + B) --> [A, +], expr(B).",
    assert_scryer_crowlog_compat("phrase(expr(Tree), [1, +, 2]).", KB, [
        "Tree = 1+2"
    ]).

%% ============================================================================
%% Tier 4: Constraint Logic Programming over Integers (CLP(Z)) & Operator Scoping
%% ============================================================================

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

%% ============================================================================
%% Main Runner
%% ============================================================================

run :-
    format("~n======================================================~n", []),
    format("=== RUNNING SCRYER PROLOG COMPATIBILITY TESTS ========~n", []),
    format("======================================================~n~n", []),
    
    format("--- Tier 1: Basic Toplevel & Reified Conditionals ---~n", []),
    run_compat_test("if_(3=4, true, false) fails", test_1_if_reif_false),
    run_compat_test("if_(3=3, X = yes, X = no) binds then branch", test_1_if_reif_true),
    run_compat_test("if_(dif(a, b), ...) evaluates pure dif condition", test_1_if_reif_dif),
    run_compat_test("simple unification (A = 1)", test_1_simple_unification),
    run_compat_test("unbound variable representation (A = [B])", test_1_unbound_variable_in_list),
    run_compat_test("shared variable aliasing", test_1_shared_variables),
    run_compat_test("truth and failure queries", test_1_truth_and_failure),

    format("~n--- Tier 2: Core Builtins Compatibility ---~n", []),
    run_compat_test("arithmetic evaluation (is/2)", test_2_arithmetic_is),
    run_compat_test("arithmetic comparisons (>, =<, =:=)", test_2_arithmetic_comparison),
    run_compat_test("metalogical type tests (var, atom, integer, etc.)", test_2_type_tests),
    run_compat_test("functor/3 and arg/3 decomposition", test_2_functor_and_arg),
    run_compat_test("univ (=../2) term construction", test_2_univ),
    run_compat_test("atom_chars/2 and number_chars/2 ISO char lists", test_2_chars_conversion),
    run_compat_test("dif/2 pure constraint", test_2_pure_dif),

    format("~n--- Tier 3: Definite Clause Grammars (DCGs) ---~n", []),
    run_compat_test("basic terminal and non-terminal DCG parsing", test_3_basic_dcg),
    run_compat_test("DCG arguments and curly brace extra goals", test_3_dcg_arguments_and_generation),

    format("~n--- Tier 4: Constraint Logic Programming (CLP(Z)) & Operator Scoping ---~n", []),
    run_compat_test("CLP(Z) operators unavailable before module import", test_4_clpz_ops_unavailable_before_import),
    run_compat_test("CLP(Z) operators dynamically available after use_module", test_4_clpz_ops_available_after_import),
    run_compat_test("CLP(Z) linear equation solving (#=)", test_4_clpz_linear_equation),
    run_compat_test("CLP(Z) domain constraints and inequalities (in, #\\=, #>, #=<)", test_4_clpz_inequality_and_domains),

    format("~n======================================================~n", []),
    format("=== ALL SCRYER COMPATIBILITY TESTS PASSED ============~n", []),
    format("======================================================~n", []),
    flush_output,
    halt(0).

:- initialization(run).
