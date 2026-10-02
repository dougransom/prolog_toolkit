:- module(test_ordsets, [
    run_ordsets_tests/0,
    run_ordsets_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_ordsets_case/4
]).

/** <module> Scryer Compatibility: Ordered Sets (library(ordsets))

Tests list_to_ord_set/2, ord_union/3, ord_intersection/3,
ord_subtract/3, and ord_subset/2.
*/

:- use_module(library(format)).
:- use_module(library(ordsets)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_ord_ops(SetA, SetB, Union, Inter, Sub) :-
    list_to_ord_set([3, 1, 2, 2, 1], SetA),
    list_to_ord_set([4, 2, 5], SetB),
    ord_union(SetA, SetB, Union),
    ord_intersection(SetA, SetB, Inter),
    ord_subtract(SetA, SetB, Sub).

test_ordsets_case(ordset_ops, "list_to_ord_set, ord_union, ord_intersection, ord_subtract",
    ":- use_module(library(ordsets)).\ntest_ord_ops(SetA, SetB, Union, Inter, Sub) :-\n    list_to_ord_set([3, 1, 2, 2, 1], SetA),\n    list_to_ord_set([4, 2, 5], SetB),\n    ord_union(SetA, SetB, Union),\n    ord_intersection(SetA, SetB, Inter),\n    ord_subtract(SetA, SetB, Sub).",
    ["test_ord_ops(A, B, U, I, S)."]).

test_ordsets_case(ordset_checks, "is_ordset, ord_subset, ord_disjoint",
    ":- use_module(library(ordsets)).",
    ["is_ordset([1, 2, 3]).",
     "ord_subset([1, 2], [1, 2, 3]).",
     "ord_disjoint([1, 2], [3, 4])."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_ordsets:test_ordsets_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_ordsets, OutFile),
    generate_scryer_out(OutFile).

run_ordsets_tests(OutFile) :-
    format("~n--- Module Compatibility: library(ordsets) ---~n", []),
    run_compat_tests_from_file(test_ordsets:test_ordsets_case, OutFile).
run_ordsets_tests :-
    default_scryer_out_path(test_ordsets, OutFile),
    run_ordsets_tests(OutFile).
