:- module(test_lists, [
    run_lists_tests/0,
    run_lists_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_lists_case/4
]).

/** <module> Scryer Compatibility: List Operations (library(lists))

Tests member/2, append/3, select/3, reverse/2, maplist/2,3, and foldl/4.
*/

:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
add_one(X, Y) :- Y is X + 1.
sum(X, Acc, NewAcc) :- NewAcc is Acc + X.
test_ops(L, S, R) :-
    append([1, 2], [3, 4], L),
    select(2, L, S),
    reverse(S, R).
test_ho(Mapped, Sum) :-
    maplist(test_lists:add_one, [1, 2, 3], Mapped),
    foldl(test_lists:sum, [1, 2, 3, 4], 0, Sum).

test_lists_case(list_ops, "append, select, reverse, maplist, foldl",
    ":- use_module(library(lists)).\nadd_one(X, Y) :- Y is X + 1.\nsum(X, Acc, NewAcc) :- NewAcc is Acc + X.\ntest_ops(L, S, R) :-\n    append([1, 2], [3, 4], L),\n    select(2, L, S),\n    reverse(S, R).\ntest_ho(Mapped, Sum) :-\n    maplist(add_one, [1, 2, 3], Mapped),\n    foldl(sum, [1, 2, 3, 4], 0, Sum).",
    [
        "test_ops(L, S, R).",
        "test_ho(M, S)."
    ]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_lists:test_lists_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_lists, OutFile),
    generate_scryer_out(OutFile).

run_lists_tests(OutFile) :-
    format("~n--- Module Compatibility: library(lists) ---~n", []),
    run_compat_tests_from_file(test_lists:test_lists_case, OutFile).
run_lists_tests :-
    default_scryer_out_path(test_lists, OutFile),
    run_lists_tests(OutFile).
