:- module(test_terms, [
    run_terms_tests/0,
    run_terms_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_terms_case/4
]).

/** <module> Scryer Compatibility: Term Manipulation (library(terms))

Tests numbervars/3.
*/

:- use_module(library(format)).
:- use_module(library(terms)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_numvars_simple(Term, N0, N) :-
    Term = f(A, _B, A),
    numbervars(Term, N0, N).

test_numvars_offset(Term, N0, N) :-
    Term = pair(_X, _Y),
    numbervars(Term, N0, N).

test_terms_case(numbervars_simple, "numbervars/3 replaces variables with '$VAR'(N)",
    ":- use_module(library(terms)).\ntest_numvars_simple(Term, N0, N) :-\n    Term = f(A, B, A),\n    numbervars(Term, N0, N).",
    ["test_numvars_simple(T, 0, N)."]).

test_terms_case(numbervars_offset, "numbervars/3 with non-zero offset",
    ":- use_module(library(terms)).\ntest_numvars_offset(Term, N0, N) :-\n    Term = pair(X, Y),\n    numbervars(Term, N0, N).",
    ["test_numvars_offset(T, 5, N)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_terms:test_terms_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_terms, OutFile),
    generate_scryer_out(OutFile).

run_terms_tests(OutFile) :-
    format("~n--- Module Compatibility: library(terms) ---~n", []),
    run_compat_tests_from_file(test_terms:test_terms_case, OutFile).
run_terms_tests :-
    default_scryer_out_path(test_terms, OutFile),
    run_terms_tests(OutFile).
