:- module(test_lambda, [
    run_lambda_tests/0,
    run_lambda_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_lambda_case/4
]).

/** <module> Scryer Compatibility: Lambda Expressions (library(lambda))

Tests lambda abstraction with maplist/3 and foldl/4.
*/

:- use_module(library(format)).
:- use_module(library(lambda)).
:- use_module(library(lists)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_lambda_map(Out) :-
    maplist(\X^Y^(Y is X * 2), [1, 2, 3], Out).

test_lambda_free(Base, Out) :-
    Base = 10,
    maplist(Base+\X^Y^(Y is X + Base), [1, 2, 3], Out).

test_lambda_zip(Out) :-
    maplist(\X^Y^Z^(Z = X-Y), [a, b, c], [1, 2, 3], Out).

test_lambda_case(lambda_map, "lambda expression with maplist/3",
    ":- use_module(library(lambda)).\n:- use_module(library(lists)).\ntest_lambda_map(Out) :-\n    maplist(\\X^Y^(Y is X * 2), [1, 2, 3], Out).",
    ["test_lambda_map(Out)."]).

test_lambda_case(lambda_free, "lambda with free parameter capture",
    ":- use_module(library(lambda)).\n:- use_module(library(lists)).\ntest_lambda_free(Base, Out) :-\n    Base = 10,\n    maplist(Base+\\X^Y^(Y is X + Base), [1, 2, 3], Out).",
    ["test_lambda_free(Base, Out)."]).

test_lambda_case(lambda_zip, "lambda expression with maplist/4 zip",
    ":- use_module(library(lambda)).\n:- use_module(library(lists)).\ntest_lambda_zip(Out) :-\n    maplist(\\X^Y^Z^(Z = X-Y), [a, b, c], [1, 2, 3], Out).",
    ["test_lambda_zip(Out)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_lambda:test_lambda_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_lambda, OutFile),
    generate_scryer_out(OutFile).

run_lambda_tests(OutFile) :-
    format("~n--- Module Compatibility: library(lambda) ---~n", []),
    run_compat_tests_from_file(test_lambda:test_lambda_case, OutFile).
run_lambda_tests :-
    default_scryer_out_path(test_lambda, OutFile),
    run_lambda_tests(OutFile).
