:- module(test_pairs, [
    run_pairs_tests/0,
    run_pairs_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_pairs_case/4
]).

/** <module> Scryer Compatibility: Key-Value Pairs (library(pairs))

Tests pairs_keys/2, pairs_values/2, pairs_keys_values/3,
group_pairs_by_key/2, and map_list_to_pairs/3.
*/

:- use_module(library(format)).
:- use_module(library(pairs)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_kv(Keys, Vals) :- pairs_keys_values([a-1, b-2, c-3], Keys, Vals).
test_grp(G) :- group_pairs_by_key([a-1, a-3, b-2, b-4, c-5], G).
test_map(P) :- map_list_to_pairs(char_code, [a, b], P).

test_pairs_case(pairs_ops, "pairs_keys_values, group_pairs_by_key, map_list_to_pairs",
    ":- use_module(library(pairs)).\ntest_kv(Keys, Vals) :- pairs_keys_values([a-1, b-2, c-3], Keys, Vals).\ntest_grp(G) :- group_pairs_by_key([a-1, a-3, b-2, b-4, c-5], G).\ntest_map(P) :- map_list_to_pairs(char_code, [a, b], P).",
    [
        "test_kv(K, V).",
        "test_grp(G).",
        "test_map(P)."
    ]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_pairs:test_pairs_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_pairs, OutFile),
    generate_scryer_out(OutFile).

run_pairs_tests(OutFile) :-
    format("~n--- Module Compatibility: library(pairs) ---~n", []),
    run_compat_tests_from_file(test_pairs:test_pairs_case, OutFile).
run_pairs_tests :-
    default_scryer_out_path(test_pairs, OutFile),
    run_pairs_tests(OutFile).
