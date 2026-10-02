:- module(test_random, [
    run_random_tests/0,
    run_random_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_random_case/4
]).

/** <module> Scryer Compatibility: Random Numbers (library(random))

Tests reproducible random integer generation with seeded RNG.
*/

:- use_module(library(format)).
:- use_module(library(random)).
:- use_module(compat_framework).

% Native Scryer predicates
test_seeded_random_int(R1, R2, R3) :-
    set_random(seed(9999)),
    random_integer(10, 100, R1),
    random_integer(10, 100, R2),
    random_integer(10, 100, R3).

test_seeded_binary(B1, B2, B3) :-
    set_random(seed(42)),
    random_integer(0, 2, B1),
    random_integer(0, 2, B2),
    random_integer(0, 2, B3).

test_random_case(random_int_seq, "random_integer/3 with fixed seed generates deterministic sequence",
    ":- use_module(library(random)).\ntest_seeded_random_int(R1, R2, R3) :-\n    set_random(seed(9999)),\n    random_integer(10, 100, R1),\n    random_integer(10, 100, R2),\n    random_integer(10, 100, R3).",
    ["test_seeded_random_int(A, B, C)."]).

test_random_case(random_binary_seq, "random_integer/3 binary range 0..1",
    ":- use_module(library(random)).\ntest_seeded_binary(B1, B2, B3) :-\n    set_random(seed(42)),\n    random_integer(0, 2, B1),\n    random_integer(0, 2, B2),\n    random_integer(0, 2, B3).",
    ["test_seeded_binary(X, Y, Z)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_random:test_random_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_random, OutFile),
    generate_scryer_out(OutFile).

run_random_tests(OutFile) :-
    format("~n--- Module Compatibility: library(random) ---~n", []),
    run_compat_tests_from_file(test_random:test_random_case, OutFile).
run_random_tests :-
    default_scryer_out_path(test_random, OutFile),
    run_random_tests(OutFile).
