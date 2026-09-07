:- module(prolog_lexer, [
    % Canonical Prolog Lexer API (Default lifted with source spans)
    prolog_tokens//1,
    prolog_tokens//2,
    prolog_clause_tokens//1,
    prolog_clause_tokens//2,
    prolog_clause_tokens/4,
    prolog_token//1,
    prolog_token//2,
    prolog_tokenize/2,
    prolog_tokenize/3,
    prolog_scan_token/4,

    % Canonical Lifted Interface
    prolog_lifted_tokens//1,
    prolog_lifted_tokens//2,
    prolog_lifted_clause_tokens//1,
    prolog_lifted_clause_tokens//2,
    prolog_lifted_token//1,
    prolog_lifted_token//2,
    prolog_lifted_tokenize/2,
    prolog_lifted_tokenize/3,

    % Canonical Unlifted Interface
    prolog_unlifted_tokens//1,
    prolog_unlifted_tokens//2,
    prolog_unlifted_clause_tokens//1,
    prolog_unlifted_clause_tokens//2,
    prolog_unlifted_token//1,
    prolog_unlifted_token//2,
    prolog_unlifted_tokenize/2,
    prolog_unlifted_tokenize/3,

    % Backward-compatibility aliases (Lifted)
    tokens//1,
    tokens//2,
    clause_tokens//1,
    clause_tokens//2,
    clause_tokens/4,
    token//1,
    token//2,
    tokenize/2,
    tokenize/3,
    scan_token/4,

    % Backward-compatibility aliases (Explicit lifted/unlifted)
    lifted_tokens//1,
    lifted_tokens//2,
    lifted_clause_tokens//1,
    lifted_clause_tokens//2,
    lifted_token//1,
    lifted_token//2,
    lifted_tokenize/2,
    lifted_tokenize/3,
    unlifted_tokens//1,
    unlifted_tokens//2,
    unlifted_clause_tokens//1,
    unlifted_clause_tokens//2,
    unlifted_token//1,
    unlifted_token//2,
    unlifted_tokenize/2,
    unlifted_tokenize/3
]).

/** <module> Pure ISO & Scryer-Compliant Lexical Analyzer

Unifies and exposes both:
  1. Unlifted DCGs operating on plain chars without coordinates (prolog_unlifted_tokens//1,2).
  2. Lifted DCGs using parser_experiments stream_annotator and dcg_annotator (prolog_lifted_tokens//1,2).
*/

:- use_module(library(dcgs)).
:- use_module(prolog_unlifted_lexer).
:- use_module(prolog_lifted_lexer).

%% Default aliases mapping to lifted interface (with source spans)
tokens(Tokens) --> lifted_tokens(Tokens).
tokens(Options, Tokens) --> lifted_tokens(Options, Tokens).

tokenize(Chars, Tokens) :- lifted_tokenize(Chars, Tokens).
tokenize(Options, Chars, Tokens) :- lifted_tokenize(Options, Chars, Tokens).

clause_tokens(Tokens) --> lifted_clause_tokens(Tokens).
clause_tokens(Options, Tokens) --> lifted_clause_tokens(Options, Tokens).

clause_tokens(Options, Tokens, CharsIn, CharsOut) :-
    phrase(lifted_clause_tokens(Options, Tokens), CharsIn, CharsOut).

token(Token) --> lifted_token(Token).
token(Options, Token) --> lifted_token(Options, Token).

%% scan_token(+Options, -Token, +CharsIn, -CharsOut)
% Scans a single lifted token from CharsIn, returning remaining CharsOut.
scan_token(Options, Token, CharsIn, CharsOut) :-
    phrase(lifted_token(Options, Token), CharsIn, CharsOut).

%% Canonical prolog_* predicate definitions
prolog_tokens(Tokens) --> tokens(Tokens).
prolog_tokens(Options, Tokens) --> tokens(Options, Tokens).
prolog_clause_tokens(Tokens) --> clause_tokens(Tokens).
prolog_clause_tokens(Options, Tokens) --> clause_tokens(Options, Tokens).
prolog_clause_tokens(Options, Tokens, CharsIn, CharsOut) :-
    clause_tokens(Options, Tokens, CharsIn, CharsOut).
prolog_token(Token) --> token(Token).
prolog_token(Options, Token) --> token(Options, Token).
prolog_tokenize(Chars, Tokens) :- tokenize(Chars, Tokens).
prolog_tokenize(Options, Chars, Tokens) :- tokenize(Options, Chars, Tokens).
prolog_scan_token(Options, Token, CharsIn, CharsOut) :-
    scan_token(Options, Token, CharsIn, CharsOut).
