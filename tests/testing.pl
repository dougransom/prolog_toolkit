:- module(testing, [
    test/1,
    test/2,
    register_test/2,
    run_tests/0,
    run_test_suite/2,
    run_test_suite/3,
    run_module_tests/1,
    run_test_list/5
]).

:- use_module(library(format)).
:- use_module(library(si)).
:- use_module(library(lists)).

:- dynamic(test_case/2).

register_test(Name, Goal) :-
    assertz(test_case(Name, Goal)).

test(Name, Goal) :-
    register_test(Name, Goal).

test(Goal) :-
    register_test(Goal, Goal).

run_tests :-
    format("=== Running Prolog Toolkit Tests ===~n", []),
    findall(t(Name, Goal), test_case(Name, Goal), Tests),
    retractall(test_case(_, _)),
    run_test_list(Tests, 0, 0, Passed, Failed),
    format("=== Test Summary: ~d passed, ~d failed ===~n", [Passed, Failed]),
    (   Failed > 0 ->
        halt(1)
    ;   true
    ).

run_test_suite(SuiteName, Tests) :-
    run_test_suite(SuiteName, user, Tests).

run_test_suite(SuiteName, Module, Tests) :-
    format("=== Running ~s Tests ===~n", [SuiteName]),
    run_test_list(Tests, Module, 0, 0, Passed, Failed),
    format("=== ~s Summary: ~d passed, ~d failed ===~n", [SuiteName, Passed, Failed]),
    (   Failed > 0 ->
        halt(1)
    ;   true
    ).

run_module_tests(Module) :-
    atom_chars(Module, ModChars),
    findall(t(Name, Goal), Module:test_case(Name, Goal), Tests),
    run_test_suite(ModChars, Module, Tests).

run_test_list(Tests, P0, F0, P, F) :-
    run_test_list(Tests, user, P0, F0, P, F).

run_test_list([], _Mod, P, F, P, F).
run_test_list([t(Name, Goal)|Rest], Mod, P0, F0, P, F) :-
    (   catch(call(Mod:Goal), Error, (format("FAIL (~s): exception: ~w~n", [Name, Error]), fail)) ->
        format("OK: ~s~n", [Name]),
        P1 is P0 + 1,
        F1 = F0
    ;   format("FAIL: ~s~n", [Name]),
        P1 = P0,
        F1 is F0 + 1
    ),
    run_test_list(Rest, Mod, P1, F1, P, F).

user:term_expansion(test(Name, Goal), (:- initialization(testing:register_test(Name, Module:Goal)))) :-
    prolog_load_context(module, Module).
user:term_expansion(test(Goal), (:- initialization(testing:register_test(Goal, Module:Goal)))) :-
    prolog_load_context(module, Module).
