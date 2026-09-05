:- module(lexer, [
    % Lifted DCG Interface (with source spans via dcg_annotator)
    lifted_tokens//1,
    lifted_tokens//2,
    lifted_clause_tokens//1,
    lifted_clause_tokens//2,
    lifted_token//1,
    lifted_token//2,
    lifted_tokenize/2,
    lifted_tokenize/3,

    % Unlifted DCG Interface (pure chars, value tokens without spans)
    unlifted_tokens//1,
    unlifted_tokens//2,
    unlifted_clause_tokens//1,
    unlifted_clause_tokens//2,
    unlifted_token//1,
    unlifted_token//2,
    unlifted_tokenize/2,
    unlifted_tokenize/3,

    % Default Aliases (Lifted)
    tokens//1,
    tokens//2,
    clause_tokens//1,
    clause_tokens//2,
    token//1,
    token//2,
    tokenize/2,
    tokenize/3,
    scan_token/4,
    clause_tokens/4
]).

/** <module> Pure ISO & Scryer-Compliant Lexical Analyzer

Unifies and exposes both:
  1. Unlifted DCGs operating on plain chars without coordinates (unlifted_tokens//1,2).
  2. Lifted DCGs using parser_experiments stream_annotator and dcg_annotator (lifted_tokens//1,2).
*/

:- use_module(library(dcgs)).
:- use_module(unlifted_lexer).
:- use_module(lifted_lexer).

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
