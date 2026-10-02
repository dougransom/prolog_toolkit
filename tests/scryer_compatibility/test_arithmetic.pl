:- module(test_arithmetic, [
    run_arithmetic_tests/0,
    run_arithmetic_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_arithmetic_case/4
]).

/** <module> Scryer Compatibility: Extended Arithmetic (library(arithmetic))

Tests expmod/4, lcm/3, lsb/2, msb/2, popcount/2, and rational_numerator_denominator/3.
*/

:- use_module(library(arithmetic)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_expmod_and_lcm(ExpRes, LcmRes) :-
    expmod(2, 10, 1000, ExpRes),
    lcm(12, 18, LcmRes).

test_bits(Lsb, Msb, Pop) :-
    lsb(12, Lsb),
    msb(12, Msb),
    popcount(29, Pop).

test_rationals(Num, Den) :-
    rational_numerator_denominator(3 rdiv 4, Num, Den).

test_arithmetic_case(expmod_and_lcm, "expmod/4 and lcm/3 compute modular powers and least common multiples",
    ":- use_module(library(arithmetic)).\ntest_expmod_and_lcm(ExpRes, LcmRes) :-\n    expmod(2, 10, 1000, ExpRes),\n    lcm(12, 18, LcmRes).",
    ["test_expmod_and_lcm(E, L)."]).

test_arithmetic_case(bits_operations, "lsb/2, msb/2, and popcount/2 perform bitwise analysis on integers",
    ":- use_module(library(arithmetic)).\ntest_bits(Lsb, Msb, Pop) :-\n    lsb(12, Lsb),\n    msb(12, Msb),\n    popcount(29, Pop).",
    ["test_bits(L, M, P)."]).

test_arithmetic_case(rational_parts, "rational_numerator_denominator/3 extracts numerator and denominator",
    ":- use_module(library(arithmetic)).\ntest_rationals(Num, Den) :-\n    rational_numerator_denominator(3 rdiv 4, Num, Den).",
    ["test_rationals(N, D)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_arithmetic:test_arithmetic_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_arithmetic, OutFile),
    generate_scryer_out(OutFile).

run_arithmetic_tests(OutFile) :-
    format("~n--- Module Compatibility: library(arithmetic) ---~n", []),
    run_compat_tests_from_file(test_arithmetic:test_arithmetic_case, OutFile).
run_arithmetic_tests :-
    default_scryer_out_path(test_arithmetic, OutFile),
    run_arithmetic_tests(OutFile).
