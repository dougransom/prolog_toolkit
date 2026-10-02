:- module(test_dcgs, [
    run_dcg_tests/0,
    run_dcg_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_dcg_case/4
]).

/** <module> Scryer Compatibility: Definite Clause Grammars (library(dcgs))

Tests pure DCG grammar rule expansion, terminal/non-terminal parsing,
arguments, and { ExtraGoal } execution via phrase/2,3.
*/

:- use_module(library(format)).
:- use_module(library(dcgs)).
:- use_module(compat_framework).

% DCG grammar rules for native Scryer execution
noun --> [cat].
noun --> [dog].
sentence --> noun, [runs].
expr(N) --> [N], { integer(N) }.
expr(A + B) --> [A, +], expr(B).

test_dcg_case(dcgs, "DCG terminals, non-terminals, arguments, and curly braces",
    ":- use_module(library(dcgs)).\nnoun --> [cat]. noun --> [dog]. sentence --> noun, [runs].\nexpr(N) --> [N], { integer(N) }. expr(A + B) --> [A, +], expr(B).",
    [
        "phrase(sentence, [cat, runs]).",
        "phrase(sentence, [dog, runs]).",
        "phrase(sentence, [fish, runs]).",
        "phrase(expr(Tree), [1, +, 2])."
    ]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_dcgs:test_dcg_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_dcgs, OutFile),
    generate_scryer_out(OutFile).

run_dcg_tests(OutFile) :-
    format("~n--- Tier 3: Definite Clause Grammars (DCGs) ---~n", []),
    run_compat_tests_from_file(test_dcgs:test_dcg_case, OutFile).
run_dcg_tests :-
    default_scryer_out_path(test_dcgs, OutFile),
    run_dcg_tests(OutFile).
