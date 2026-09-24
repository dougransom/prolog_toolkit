:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(pio)).
:- use_module('../src/prolog_toolkit').
:- use_module('../src/prolog_operator_table').
:- use_module('../src/prolog_reactive_parser').

debug_builtins :-
    Path = "reference/scryer-prolog/src/lib/builtins.pl",
    format("Reading ~s...~n", [Path]), flush_output,
    phrase_from_file(seq(Chars), Path), !,
    length(Chars, CharsLen),
    format("Read ~d chars. Tokenizing...~n", [CharsLen]), flush_output,
    phrase(prolog_tokens(Toks), Chars), !,
    length(Toks, ToksLen),
    format("Tokenized ~d tokens. Parsing statements...~n", [ToksLen]), flush_output,
    prolog_default_operator_table(OpT0),
    parse_loop(Toks, OpT0, 1).

seq([]) --> [].
seq([C|Cs]) --> [C], seq(Cs).

parse_loop([], _, Count) :-
    format("All ~d statements parsed successfully!~n", [Count]), flush_output,
    halt(0).
parse_loop(Toks, OpT0, Count) :-
    (   Count #>= 150 ->
        take(5, Toks, Next5),
        format("Statement ~d: next: ~q~n", [Count, Next5]), flush_output
    ;   true
    ),
    (   catch(
            phrase(parse_clause(OpT0, [expand_mode(pure_dcg)], Stmt, OpT1), Toks, RestToks),
            Error,
            ( format("EXCEPTION at statement ~d:~n~q~nFirst 10 remaining tokens:~n", [Count, Error]), flush_output,
              take(10, Toks, Preview),
              format("~q~n", [Preview]), flush_output,
              halt(1)
            )
        ) ->
        (   ( Count mod 50 #= 0 ; Count #>= 200 ) ->
            length(RestToks, Rem),
            format("Statement ~d parsed (remaining tokens: ~d)~n", [Count, Rem]), flush_output
        ;   true
        ),
        Count1 #= Count + 1,
        parse_loop(RestToks, OpT1, Count1)
    ;   format("PARSE FAILURE (predicate returned false) at statement ~d!~nFirst 15 remaining tokens:~n", [Count]), flush_output,
        take(15, Toks, Preview),
        format("~q~n", [Preview]), flush_output,
        halt(1)
    ).

take(0, _, []) :- !.
take(_, [], []) :- !.
take(N, [X|Xs], [X|Ys]) :-
    N #> 0,
    N1 #= N - 1,
    take(N1, Xs, Ys).

:- initialization(debug_builtins).
