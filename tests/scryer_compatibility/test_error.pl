:- module(test_error, [
    run_error_tests/0,
    run_error_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_error_case/4
]).

/** <module> Scryer Compatibility: Type Checking and Error Handling (library(error))

Tests must_be/2 and can_be/2 type assertions.
*/

:- use_module(library(error)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_must_be_valid :-
    must_be(integer, 42),
    must_be(chars, "valid_string"),
    must_be(atom, test_atom).

test_can_be_unbound(Var) :-
    can_be(integer, Var),
    can_be(chars, Var).

test_must_be_catch_error(ErrType) :-
    catch(must_be(integer, "not_an_int"), error(type_error(integer, _), _), ErrType = type_error).

test_error_case(must_be_valid, "must_be/2 validates ground types successfully",
    ":- use_module(library(error)).\ntest_must_be_valid :-\n    must_be(integer, 42),\n    must_be(chars, \"valid_string\"),\n    must_be(atom, test_atom).",
    ["test_must_be_valid."]).

test_error_case(can_be_unbound, "can_be/2 succeeds for uninstantiated variables",
    ":- use_module(library(error)).\ntest_can_be_unbound(Var) :-\n    can_be(integer, Var),\n    can_be(chars, Var).",
    ["test_can_be_unbound(X)."]).

test_error_case(must_be_catch, "must_be/2 raises type_error upon mismatch",
    ":- use_module(library(error)).\ntest_must_be_catch_error(ErrType) :-\n    catch(must_be(integer, \"not_an_int\"), error(type_error(integer, _), _), ErrType = type_error).",
    ["test_must_be_catch_error(E)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_error:test_error_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_error, OutFile),
    generate_scryer_out(OutFile).

run_error_tests(OutFile) :-
    format("~n--- Module Compatibility: library(error) ---~n", []),
    run_compat_tests_from_file(test_error:test_error_case, OutFile).
run_error_tests :-
    default_scryer_out_path(test_error, OutFile),
    run_error_tests(OutFile).
