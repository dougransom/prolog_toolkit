:- module(test_assoc, [
    run_assoc_tests/0,
    run_assoc_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_assoc_case/4
]).

/** <module> Scryer Compatibility: Association Trees (library(assoc))

Tests empty_assoc/1, put_assoc/4, get_assoc/3, list_to_assoc/2,
and assoc_to_list/2.
*/

:- use_module(library(format)).
:- use_module(library(assoc)).
:- use_module(compat_framework).

% Predicates used in test queries
test_put_get(V1, V2) :-
    empty_assoc(A0),
    put_assoc(x, A0, 10, A1),
    put_assoc(y, A1, 20, A2),
    get_assoc(x, A2, V1),
    get_assoc(y, A2, V2).

test_conv(PairsOut) :-
    list_to_assoc([b-2, a-1, c-3], Assoc),
    assoc_to_list(Assoc, PairsOut).

% Test case definitions: test_assoc_case(ID, Description, KBText, Queries)
test_assoc_case(put_get, "empty_assoc/1, put_assoc/4, get_assoc/3",
    ":- use_module(library(assoc)).\ntest_put_get(V1, V2) :-\n    empty_assoc(A0),\n    put_assoc(x, A0, 10, A1),\n    put_assoc(y, A1, 20, A2),\n    get_assoc(x, A2, V1),\n    get_assoc(y, A2, V2).",
    ["test_put_get(V1, V2)."]).

test_assoc_case(conversions, "list_to_assoc/2, assoc_to_list/2",
    ":- use_module(library(assoc)).\ntest_conv(PairsOut) :-\n    list_to_assoc([b-2, a-1, c-3], Assoc),\n    assoc_to_list(Assoc, PairsOut).",
    ["test_conv(P)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_assoc:test_assoc_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_assoc, OutFile),
    generate_scryer_out(OutFile).

run_assoc_tests(OutFile) :-
    format("~n--- Module Compatibility: library(assoc) ---~n", []),
    run_compat_tests_from_file(test_assoc:test_assoc_case, OutFile).
run_assoc_tests :-
    default_scryer_out_path(test_assoc, OutFile),
    run_assoc_tests(OutFile).
