:- module(compat_framework, [
    assert_scryer_crowlog_compat/2,
    assert_scryer_crowlog_compat/3,
    run_compat_test/2,
    chars_contains/2,
    chars_contains_all/2
]).

/** <module> Scryer Compatibility Testing Framework

Provides assertion predicates to execute queries in Crowlog and verify
identical behavior, answer bindings, and syntax errors to Scryer Prolog.
*/

:- use_module(library(charsio)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module('../../src/prolog_lexer').
:- use_module('../../src/prolog_reactive_parser').
:- use_module('../../crowlog/crowlog').
:- use_module('../../crowlog/crowlog_toplevel').

%% chars_contains(+Chars, +Sub)
chars_contains(Chars, Sub) :-
    append(_, Rest, Chars),
    append(Sub, _, Rest).

%% chars_contains_all(+Chars, +SubList)
chars_contains_all(_, []).
chars_contains_all(Chars, [Sub|Subs]) :-
    chars_contains(Chars, Sub),
    chars_contains_all(Chars, Subs).

%% assert_scryer_crowlog_compat(+QueryStr, +ExpectedSubstrings)
%  Runs a query in Crowlog and asserts it matches the standard Scryer behavior.
assert_scryer_crowlog_compat(QueryStr, ExpectedSubstrings) :-
    append(QueryStr, "\nhalt.\n", FullInput),
    crowlog_toplevel_string(FullInput, Output),
    (   chars_contains_all(Output, ExpectedSubstrings) ->
        true
    ;   format("Compatibility Mismatch! Query: ~s~nCrowlog Output:~n~s~nExpected Substrings:~n~q~n",
               [QueryStr, Output, ExpectedSubstrings]),
        flush_output,
        fail
    ).

%% assert_scryer_crowlog_compat(+QueryStr, +InitialKBText, +ExpectedSubstrings)
%  Consults InitialKBText into KB, executes QueryStr, and asserts expected behavior.
assert_scryer_crowlog_compat(QueryStr, InitialKBText, ExpectedSubstrings) :-
    initial_toplevel_state(State0),
    phrase(prolog_tokens(Tokens), InitialKBText),
    State0 = state(kb(_), ops(OpT0), opts(Opts)),
    phrase(prolog_parse_program(OpT0, [expand_mode(pure_dcg)], Clauses, OpT1), Tokens),
    State1 = state(kb(Clauses), ops(OpT1), opts(Opts)),
    append(QueryStr, "\nhalt.\n", FullInput),
    crowlog_toplevel_string(FullInput, State1, Output, _),
    (   chars_contains_all(Output, ExpectedSubstrings) ->
        true
    ;   format("Compatibility Mismatch! Query: ~s~nCrowlog Output:~n~s~nExpected Substrings:~n~q~n",
               [QueryStr, Output, ExpectedSubstrings]),
        flush_output,
        fail
    ).

%% run_compat_test(+Name, :Goal)
run_compat_test(Name, Goal) :-
    format("  Testing: ~s ... ", [Name]),
    flush_output,
    (   catch(Goal, E, (format("FAIL (exception: ~w)~n", [E]), flush_output, fail)) ->
        format("OK~n", []),
        flush_output
    ;   format("FAIL~n", []),
        flush_output,
        halt(1)
    ).
