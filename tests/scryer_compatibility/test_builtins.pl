:- module(test_builtins, [
    run_builtins_tests/0,
    test_2_arithmetic_is/0,
    test_2_arithmetic_comparison/0,
    test_2_type_tests/0,
    test_2_functor_and_arg/0,
    test_2_univ/0,
    test_2_chars_conversion/0,
    test_2_pure_dif/0
]).

/** <module> Scryer Compatibility: Absorbed & Core Builtin Predicates

Tests arithmetic evaluation (is/2), relational comparisons, metalogical
type predicates, functor/arg/univ decomposition, and char list conversions.
*/

:- use_module(library(format)).
:- use_module(compat_framework).

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

run_builtins_tests :-
    format("~n--- Tier 2: Core Builtins Compatibility ---~n", []),
    run_compat_test("arithmetic evaluation (is/2)", test_builtins:test_2_arithmetic_is),
    run_compat_test("arithmetic comparisons (>, =<, =:=)", test_builtins:test_2_arithmetic_comparison),
    run_compat_test("metalogical type tests (var, atom, integer, etc.)", test_builtins:test_2_type_tests),
    run_compat_test("functor/3 and arg/3 decomposition", test_builtins:test_2_functor_and_arg),
    run_compat_test("univ (=../2) term construction", test_builtins:test_2_univ),
    run_compat_test("atom_chars/2 and number_chars/2 ISO char lists", test_builtins:test_2_chars_conversion),
    run_compat_test("dif/2 pure constraint", test_builtins:test_2_pure_dif).

:- initialization(run_builtins_tests).
