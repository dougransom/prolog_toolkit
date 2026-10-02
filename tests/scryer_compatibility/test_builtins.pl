:- module(test_builtins, [
    run_builtins_tests/0,
    run_builtins_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_builtins_case/4
]).

/** <module> Scryer Compatibility: Absorbed & Core Builtin Predicates

Tests arithmetic evaluation (is/2), relational comparisons, metalogical
type predicates, functor/arg/univ decomposition, and char list conversions.
*/

:- use_module(library(format)).
:- use_module(library(dif)).
:- use_module(compat_framework).

test_builtins_case(arithmetic_is, "arithmetic evaluation (is/2)", "", ["X is 2 * 3 + 4."]).
test_builtins_case(arithmetic_comparison, "arithmetic comparisons (>, =<, =:=)", "", ["10 > 5, 3 =< 3, 4 =:= 2 + 2."]).
test_builtins_case(type_tests, "metalogical type tests (var, atom, integer, etc.)", "", ["var(X), nonvar(foo), atom(bar), integer(42), float(3.14), compound(f(1))."]).
test_builtins_case(functor_and_arg, "functor/3 and arg/3 decomposition", "", ["functor(f(a, b, c), F, N), arg(2, f(a, b, c), Arg)."]).
test_builtins_case(univ, "univ (=../2) term construction", "", ["Term =.. [foo, 1, 2, bar]."]).
test_builtins_case(chars_conversion, "atom_chars/2 and number_chars/2 ISO char lists", "", ["atom_chars(hello, Cs), number_chars(123, Ns)."]).
test_builtins_case(pure_dif, "dif/2 pure constraint", "", ["dif(X, a), X = b."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_builtins:test_builtins_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_builtins, OutFile),
    generate_scryer_out(OutFile).

run_builtins_tests(OutFile) :-
    format("~n--- Tier 2: Core Builtins Compatibility ---~n", []),
    run_compat_tests_from_file(test_builtins:test_builtins_case, OutFile).
run_builtins_tests :-
    default_scryer_out_path(test_builtins, OutFile),
    run_builtins_tests(OutFile).
