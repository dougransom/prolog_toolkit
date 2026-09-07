:- module(streaming_lexer, [
    lazy_tokens//1,
    lazy_tokens//2,
    lazy_tokenize/2,
    lazy_tokenize/3
]).

/** <module> Lazy Streaming Token Generator

Lazily tokenizes character streams on demand via library(freeze).
Uses the lifted lexer rules to produce tokens with source spans as demanded.
*/

:- use_module(library(dcgs)).
:- use_module(library(freeze)).
:- use_module(library(reif)).
:- use_module('../../parser_experiments/src/stream_annotator', [
    annotated_seq//3,
    default_annot_step/3
]).
:- use_module('../../parser_experiments/src/annotate_position', [
    init_position_state/2
]).
:- use_module(lifted_lexer, [
    annotated_skip_layout/6,
    annotated_scan_single_token/5
]).

%% lazy_tokens(-Tokens)//
% Produces a lazy token stream via DCG: phrase(lazy_tokens(Tokens), Chars).
lazy_tokens(Tokens) -->
    lazy_tokens([], Tokens).

%% lazy_tokens(+Options, -Tokens)//
% Produces a lazy token stream with Options via DCG: phrase(lazy_tokens(Options, Tokens), Chars).
lazy_tokens(Options, Tokens, Chars, []) :-
    lazy_tokenize(Options, Chars, Tokens).

%% lazy_tokenize(+Chars, -Tokens)
% Produces a lazy token stream where each token is computed on demand.
lazy_tokenize(Chars, Tokens) :-
    lazy_tokenize([], Chars, Tokens).

%% lazy_tokenize(+Options, +Chars, -Tokens)
% Produces a lazy token stream where each token is computed on demand.
lazy_tokenize(Options, Chars, Tokens) :-
    init_position_state("<input>", State0),
    phrase(annotated_seq(default_annot_step, State0, AnnotatedStream), Chars),
    freeze(Tokens, lazy_annotated_tokens_step(AnnotatedStream, true, Options, Tokens)).

lazy_annotated_tokens_step([], _, _, []).
lazy_annotated_tokens_step([Item|RestItems], LayoutBefore0, Options, Tokens) :-
    annotated_skip_layout([Item|RestItems], LayoutBefore0, Options, NonLayoutStream, LayoutBefore1, _),
    if_(NonLayoutStream = [],
        Tokens = [],
        ( annotated_scan_single_token(LayoutBefore1, Options, Token, NonLayoutStream, RestStream),
          Tokens = [Token|Tail],
          freeze(Tail, lazy_annotated_tokens_step(RestStream, false, Options, Tail))
        )
    ).
