:- module(unlifted_lexer, [
    unlifted_tokens//1,
    unlifted_tokens//2,
    unlifted_clause_tokens//1,
    unlifted_clause_tokens//2,
    unlifted_token//1,
    unlifted_token//2,
    unlifted_tokenize/2,
    unlifted_tokenize/3,
    unlifted_scan_token/5,
    unlifted_skip_layout/6
]).

/** <module> Pure Unlifted DCG Lexical Analyzer

Tokenizes plain character streams into unlifted tokens (tokens without source spans).
Operates purely on [char] without any coordinate or position tracking.
Derives DCG rules from lexer_rules:grammar_rule/2.
*/

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dcgs)).
:- use_module(library(dif)).
:- use_module(library(lists), [append/2, append/3, member/2]).
:- use_module(library(reif)).
:- use_module(token).
:- use_module(lexer_regex, [digits_to_int/3]).
:- use_module(lexer_rules, [
    grammar_rule/2,
    char_to_esc/2,
    is_graphic_char/1
]).

user:term_expansion(import_unlifted_rules, ExpandedRules) :-
    findall(Rule,
            ( grammar_rule(node, Rule) ; grammar_rule(helper, Rule) ),
            ExpandedRules).

import_unlifted_rules.

%% unlifted_tokens(-Tokens)//
% Parses all unlifted tokens from the character stream until EOF.
unlifted_tokens(Tokens) -->
    unlifted_tokens([], Tokens).

%% unlifted_tokens(+Options, -Tokens)//
% Parses all unlifted tokens with Options from the character stream until EOF.
unlifted_tokens(Options, Tokens, CharsIn, CharsOut) :-
    unlifted_tokens_stream(true, Options, Tokens, CharsIn, CharsOut).

unlifted_tokens_stream(_, Options, [], [], []) :-
    if_(memberd_t(comments(CommentsOut), Options),
        CommentsOut = [],
        true
    ).
unlifted_tokens_stream(LayoutBefore0, Options, Tokens, [C|Cs], CharsOut) :-
    unlifted_skip_layout([C|Cs], LayoutBefore0, Options, NonLayoutChars, LayoutBefore1, Comments),
    if_(NonLayoutChars = [],
        ( if_(memberd_t(comments(CommentsOut), Options), CommentsOut = Comments, true),
          Tokens = [],
          CharsOut = []
        ),
        ( unlifted_scan_token(LayoutBefore1, Options, Token, NonLayoutChars, RestChars),
          unlifted_tokens_stream(false, Options, RestTokens, RestChars, CharsOut),
          Tokens = [Token|RestTokens]
        )
    ).

%% unlifted_tokenize(+Chars, -Tokens)
% Convenience wrapper for phrase(unlifted_tokens(Tokens), Chars).
unlifted_tokenize(Chars, Tokens) :-
    phrase(unlifted_tokens([], Tokens), Chars).

%% unlifted_tokenize(+Options, +Chars, -Tokens)
% Convenience wrapper for phrase(unlifted_tokens(Options, Tokens), Chars).
unlifted_tokenize(Options, Chars, Tokens) :-
    phrase(unlifted_tokens(Options, Tokens), Chars).

%% unlifted_clause_tokens(-Tokens)//
% Scans unlifted tokens up to and including the next full stop end token.
unlifted_clause_tokens(Tokens) -->
    unlifted_clause_tokens([], Tokens).

%% unlifted_clause_tokens(+Options, -Tokens)//
% Scans unlifted tokens with Options up to and including the next full stop end token.
unlifted_clause_tokens(Options, Tokens, CharsIn, CharsOut) :-
    unlifted_clause_step(true, Options, Tokens, CharsIn, CharsOut).

unlifted_clause_step(_, _, [], [], []).
unlifted_clause_step(LayoutBefore0, Options, Tokens, [C|Cs], CharsOut) :-
    unlifted_skip_layout([C|Cs], LayoutBefore0, Options, NonLayoutChars, LayoutBefore1, _),
    if_(NonLayoutChars = [],
        ( Tokens = [], CharsOut = [] ),
        ( unlifted_scan_token(LayoutBefore1, Options, Token, NonLayoutChars, RestChars),
          if_(Token = end,
              ( Tokens = [Token], CharsOut = RestChars ),
              ( unlifted_clause_step(false, Options, RestTokens, RestChars, CharsOut),
                Tokens = [Token|RestTokens]
              )
          )
        )
    ).

%% unlifted_token(-Token)//
% Scans a single unlifted token from the character stream.
unlifted_token(Token) -->
    unlifted_token([], Token).

%% unlifted_token(+Options, -Token)//
% Scans a single unlifted token with Options from the character stream.
unlifted_token(Options, Token, CharsIn, CharsOut) :-
    unlifted_skip_layout(CharsIn, true, Options, NonLayoutChars, LayoutBefore, _),
    dif(NonLayoutChars, []),
    unlifted_scan_token(LayoutBefore, Options, Token, NonLayoutChars, CharsOut).

% -------------------------------------------------------------------------
% Layout & Comment Stripping (Pure Chars)
% -------------------------------------------------------------------------

unlifted_skip_layout([], LayoutBefore, _, [], LayoutBefore, []).
unlifted_skip_layout(['%'|Cs], _LayoutBefore0, Options, CharsOut, LayoutBeforeOut, [CommentToken|RestComments]) :-
    phrase(scan_comment(CommentToken), ['%'|Cs], Rest),
    unlifted_skip_layout(Rest, true, Options, CharsOut, LayoutBeforeOut, RestComments).
unlifted_skip_layout(['/','*'|Cs], _LayoutBefore0, Options, CharsOut, LayoutBeforeOut, [CommentToken|RestComments]) :-
    if_(memberd_t(comments_nesting(true), Options),
        phrase(scan_nested_comment(CommentToken), ['/','*'|Cs], Rest),
        phrase(scan_comment(CommentToken), ['/','*'|Cs], Rest)
    ),
    unlifted_skip_layout(Rest, true, Options, CharsOut, LayoutBeforeOut, RestComments).
unlifted_skip_layout([C|Cs], LayoutBefore0, Options, CharsOut, LayoutBeforeOut, CommentsOut) :-
    dif(C, '%'),
    dif([C|Cs], ['/','*'|_]),
    if_(memberd_t(C, [' ', '\t', '\r', '\n', '\v', '\f']),
        unlifted_skip_layout(Cs, true, Options, CharsOut, LayoutBeforeOut, CommentsOut),
        ( CharsOut = [C|Cs],
          LayoutBeforeOut = LayoutBefore0,
          CommentsOut = []
        )
    ).

% -------------------------------------------------------------------------
% Single Unlifted Token Scanner
% -------------------------------------------------------------------------

is_full_stop_lookahead_chars([], true).
is_full_stop_lookahead_chars([C|_], true) :-
    member(C, [' ', '\t', '\r', '\n', '\v', '\f', '%']), !.
is_full_stop_lookahead_chars(['/','*'|_], true) :- !.
is_full_stop_lookahead_chars(_, false).

unlifted_scan_token(LayoutBefore, _Options, Token, CharsIn, CharsOut) :-
    (   CharsIn = ['.'|AfterDot],
        is_full_stop_lookahead_chars(AfterDot, true) ->
        Token = end,
        CharsOut = AfterDot
    ;   CharsIn = ['('|_] ->
        (   LayoutBefore == true ->
            phrase(scan_paren(open), CharsIn, CharsOut),
            Token = open
        ;   phrase(scan_paren(open_ct), CharsIn, CharsOut),
            Token = open_ct
        )
    ;   phrase(scan_token(Token), CharsIn, CharsOut)
    ).
