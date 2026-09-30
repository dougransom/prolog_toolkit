:- module(test_dcgs, [
    run_dcg_tests/0,
    test_3_basic_dcg/0,
    test_3_dcg_arguments_and_generation/0
]).

/** <module> Scryer Compatibility: Definite Clause Grammars (library(dcgs))

Tests pure DCG grammar rule expansion, terminal/non-terminal parsing,
arguments, and { ExtraGoal } execution via phrase/2,3.
*/

:- use_module(library(format)).
:- use_module(compat_framework).

test_3_basic_dcg :-
    KB = ":- use_module(library(dcgs)).\nnoun --> [cat]. noun --> [dog]. sentence --> noun, [runs].",
    assert_scryer_crowlog_compat("phrase(sentence, [cat, runs]).", KB, ["true."]),
    assert_scryer_crowlog_compat("phrase(sentence, [dog, runs]).", KB, ["true."]),
    assert_scryer_crowlog_compat("phrase(sentence, [fish, runs]).", KB, ["false."]).

test_3_dcg_arguments_and_generation :-
    KB = ":- use_module(library(dcgs)).\nexpr(N) --> [N], { integer(N) }. expr(A + B) --> [A, +], expr(B).",
    assert_scryer_crowlog_compat("phrase(expr(Tree), [1, +, 2]).", KB, [
        "Tree = 1+2"
    ]).

run_dcg_tests :-
    format("~n--- Tier 3: Definite Clause Grammars (DCGs) ---~n", []),
    run_compat_test("basic terminal and non-terminal DCG parsing", test_dcgs:test_3_basic_dcg),
    run_compat_test("DCG arguments and curly brace extra goals", test_dcgs:test_3_dcg_arguments_and_generation).

:- initialization(run_dcg_tests).
